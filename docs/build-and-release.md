[← Return to README](../README.md)

# Build and release

Every push to `main` and every pull request is compiled by the GitHub Actions workflow [`.github/workflows/build.yml`](../.github/workflows/build.yml). Pushing a version tag such as `v1.1.0` also publishes a GitHub release whose files install on an environment without building anything there.

## What a release contains

| File | Contains | Install on |
| --- | --- | --- |
| `OlkInc-D365FO-EDS-<version>.zip` | The model | Any environment, including production |
| `OlkInc-D365FO-EDS-Test-<version>.zip` | The model and the test model | Development and test environments only |

Both files are standard *software deployable packages*: the same format Azure DevOps builds and LCS accept. They hold the compiled assemblies, labels and metadata, so the target environment only installs them and synchronizes the database.

The version is `<major>.<minor>.<build>.<run number>`: tag `v1.1.0` on the 37th workflow run gives `1.1.0.37`, which is stamped into both model descriptors. Builds from `main` and pull requests use the version in the descriptor with the run number, and keep the packages for 14 days as a workflow artifact (open the run, **Artifacts**).

## How the build works

GitHub-hosted Windows runners have Visual Studio 2022 and MSBuild, but not the X++ compiler or the Microsoft models. Those come from the Microsoft X++ build NuGet packages:

| Package | Provides |
| --- | --- |
| `Microsoft.Dynamics.AX.Platform.CompilerPackage` | The X++ compiler, the MSBuild tasks and the deployable package tools |
| `Microsoft.Dynamics.AX.Platform.DevALM.BuildXpp` | Compiled platform models (ApplicationPlatform and others) |
| `Microsoft.Dynamics.AX.Application1.DevALM.BuildXpp`, `...Application2...` | Compiled application models (ApplicationFoundation and others). Older versions have one `Application` package instead |
| `Microsoft.Dynamics.AX.ApplicationSuite.DevALM.BuildXpp` | ApplicationSuite, needed only by the test model |

Microsoft publishes them only in LCS, so they have to be put on a NuGet feed the workflow can read. [`build/Build-EDS.ps1`](../build/Build-EDS.ps1) restores them (the workflow caches them after the first run), compiles both models with the projects in `build/projects`, and creates the two packages. The packages are listed with their versions in [`build/packages.config`](../build/packages.config).

## One-time setup

### 1. Choose the version to build against

Look up the service update of the **oldest** environment you will install on (LCS environment page, or **Help > About** in the client, for example 10.0.43 with platform update 67). Packages built on an older version install on newer environments; packages built on a newer version may not install on older ones.

### 2. Download the NuGet packages from LCS

In LCS open **Shared asset library > NuGet package** and download the packages from the table above for that version (each file name ends with the version, `<package>.<version>.nupkg`).

### 3. Put them on a NuGet feed

Use an **Azure Artifacts** feed: it is free up to 2 GiB, private, and it is the feed Microsoft documents for these packages.

1. In Azure DevOps (create a free organization at [dev.azure.com](https://dev.azure.com) if needed) open any project, **Artifacts > Create feed**, for example `d365`, visibility *Members of your organization*.
2. **Connect to feed > NuGet.exe** shows the feed URL, for example `https://pkgs.dev.azure.com/<org>/<project>/_packaging/d365/nuget/v3/index.json`.
3. Create a personal access token (**User settings > Personal access tokens**) with scope **Packaging: Read & write** for uploading.
4. Upload each file:

   ```powershell
   nuget sources add -Name d365 -Source <feed URL> -Username any -Password <PAT>
   nuget push Microsoft.Dynamics.AX.Platform.CompilerPackage.<version>.nupkg -Source d365 -ApiKey az -Timeout 3600
   ```

5. Create a second token with **Packaging: Read** only; that one goes into GitHub.

GitHub Packages is not a good fit: the packages total several GB, and the GitHub Packages storage included with a private repository is 500 MB (Free) or 2 GB (Pro).

### 4. Set the versions

Edit [`build/packages.config`](../build/packages.config): replace each `SET-ME` with the version you uploaded and remove the packages you do not have (for example use one `Microsoft.Dynamics.AX.Application.DevALM.BuildXpp` on versions that are not split). Remove the ApplicationSuite line to skip the test model; the build then produces only `OlkInc-D365FO-EDS-<version>.zip`. Commit the change to `main`.

### 5. Add the GitHub secrets

In the repository open **Settings > Secrets and variables > Actions > New repository secret**:

| Secret | Value |
| --- | --- |
| `D365_NUGET_FEED_URL` | The feed URL from step 3 |
| `D365_NUGET_FEED_TOKEN` | The read-only token from step 3 |
| `D365_NUGET_FEED_USER` | Optional; any text for Azure Artifacts |

### 6. Check the Actions settings

In **Settings > Actions > General**, Actions must be allowed, including actions created by GitHub and `microsoft/setup-msbuild`. The workflow asks for `contents: write` itself so that it can create releases.

Actions minutes on a private repository are limited (2,000 a month on GitHub Free), and Windows runners use them at twice the rate. The first build restores the packages and takes longest; later builds use the cache.

## Publishing a release

1. Merge the changes to `main`.
2. Tag the commit and push the tag:

   ```powershell
   git tag v1.1.0
   git push origin v1.1.0
   ```

   Creating a release with a new tag in the GitHub **Releases** page works too; the workflow adds the files to it.
3. When the run finishes, the release is under **Releases** with both zip files.

## Installing a release

Download the zip from the release. Do not extract it before uploading to LCS.

- **Sandbox and production (LCS-managed):** LCS **Asset library > Software deployable package > +**, upload the zip, then on the environment page **Maintain > Apply updates** and pick it. Production is updated from a package that was applied to a sandbox first.
- **Cloud-hosted or local development VM:** extract the zip and install it from the command line with `AXUpdateInstaller.exe` (see Microsoft's *Install deployable packages from the command line*), or with `Invoke-D365SDPInstall` from d365fo.tools. Do not install it on a VM where the model's source is also in PackagesLocalDirectory.
- **Unified (Power Platform) environments:** deploy the package with the Power Platform CLI or Visual Studio as described in Microsoft's documentation for unified environments.

The installation synchronizes the database. Then check the configuration key and roles as described in [Security](security.md).

## Building on your own machine

On a Windows machine with Visual Studio 2022 or Build Tools 2022:

```powershell
$env:D365_NUGET_FEED_URL = '<feed URL>'
$env:D365_NUGET_FEED_TOKEN = '<read token>'
./build/Build-EDS.ps1 -Version 1.1.0.0
```

The packages go to `out/release`. `out` is ignored by git.

## Alternative: a self-hosted runner

If you do not want a NuGet feed, a [self-hosted runner](https://docs.github.com/actions/hosting-your-own-runners) on a development VM can build against the VM's own PackagesLocalDirectory instead. The VM then has to be running for every build, and the workflow and script would need changing to use it; the hosted setup above is the default.
