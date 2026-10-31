[← Return to README](../README.md)

# Build and release

Three GitHub Actions pipelines compile the models, one per generally available (GA) version of Dynamics 365 finance and operations. On every push to `main`, each publishes a GitHub release whose files install on an environment without building anything there.

## Pipelines and F&O versions

| Pipeline | Builds against | Runs on |
| --- | --- | --- |
| [Build for newest GA](../.github/workflows/build-ga.yml) | The newest GA version | Pull requests, pushes to `main`, by hand |
| [Build for GA - 1](../.github/workflows/build-ga-1.yml) | The GA version before it | Pushes to `main`, by hand |
| [Build for GA - 2](../.github/workflows/build-ga-2.yml) | The GA version before that | Pushes to `main`, by hand |

All three call the shared workflow [`build.yml`](../.github/workflows/build.yml). It finds its version with [`build/Resolve-FnoVersions.ps1`](../build/Resolve-FnoVersions.ps1), which reads the release table in Microsoft's [Service update availability](https://learn.microsoft.com/dynamics365/fin-ops-core/dev-itpro/get-started/public-preview-releases) page and lists the versions that are generally available today and not past end of service. On 31 October 2026 those are 10.0.49, 10.0.48 and 10.0.47. The pipelines move on by themselves when Microsoft releases a new version. Pull requests run only the newest GA pipeline, to save Actions minutes.

Each version is built against the packages of its first GA build, so a package installs on that version with any quality update and on newer versions.

## What a release contains

Each push to `main` gives three releases, one per F&O version, all with the same model version. The release for 10.0.49 and model version 1.0.0.42 is tagged `v1.0.0.42-fo10.0.49` and contains:

| File | Contains | Install on |
| --- | --- | --- |
| `OlkInc-D365FO-EDS-1.0.0.42-FO10.0.49.zip` | The model | Any environment on 10.0.49 or later, including production |
| `OlkInc-D365FO-EDS-Test-1.0.0.42-FO10.0.49.zip` | The model and the test model | Development and test environments only |

**Pick the release built for the oldest F&O version among the environments you install on.** The release for the newest GA version is marked as the repository's *Latest* release.

All files are standard *software deployable packages*: the same format Azure DevOps builds and LCS accept. They hold the compiled assemblies, labels and metadata, so the target environment only installs them and synchronizes the database.

The model version is `<major>.<minor>.<build>` from the model descriptor plus the number of commits on the branch, for example `1.0.0.42`, and is stamped into both model descriptors. To start a new major or minor version, change `VersionMajor` or `VersionMinor` in `Metadata/OlkInc-D365FO-EDS/Descriptor/OlkInc-D365FO-EDS.xml`. Pull request builds publish nothing, but keep their packages for 14 days as workflow artifacts (open the run, **Artifacts**).

If one pipeline fails, the other releases are still published.

## How the build works

GitHub-hosted Windows runners have Visual Studio 2022 and MSBuild, but not the X++ compiler or the Microsoft models. Those come from the Microsoft X++ build NuGet packages:

| Package | Provides |
| --- | --- |
| `Microsoft.Dynamics.AX.Platform.CompilerPackage` | The X++ compiler, the MSBuild tasks and the deployable package tools |
| `Microsoft.Dynamics.AX.Platform.DevALM.BuildXpp` | Compiled platform models (ApplicationPlatform and others) |
| `Microsoft.Dynamics.AX.Application.DevALM.BuildXpp` (or `Application1` and `Application2`) | Compiled application models (ApplicationFoundation and others) |
| `Microsoft.Dynamics.AX.ApplicationSuite.DevALM.BuildXpp` | ApplicationSuite, needed only by the test model |

Microsoft publishes them only in LCS. For each version the build takes them from:

1. **The fscps.tools community storage** when it has the version. [fscps.tools](https://github.com/fscpscollaborative/fscps.tools), the PowerShell module behind the FSC-PS GitHub Actions templates, keeps the LCS packages of the released F&O versions in a public Azure storage account run by its maintainers. [`build/Build-EDS.ps1`](../build/Build-EDS.ps1) installs a pinned version of the module and calls `Get-FSCPSNuget` for the version. The GA versions normally come from here, with no setup.
2. **Your own NuGet feed** otherwise, when the `D365_NUGET_FEED_URL` secret exists, with the versions in [`build/packages.config`](../build/packages.config). Normally not needed: use it only if the community storage stops serving the packages.

The packages are cached per version after the first run (the GitHub cache holds 10 GB per repository, so older versions may be evicted and downloaded again).

### Things to know about the community storage

- It is not a Microsoft service. The compiler and models come from a third party's copy of the LCS files, and the storage key is published in the module, so the maintainers can rotate or remove it at any time. If downloads start failing, raise `FSCPS_TOOLS_VERSION` in `build/Build-EDS.ps1` (a newer module usually has the new key) or switch to your own feed.
- The build runs the module with access to nothing but the runner: the checkout does not keep the repository token.
- You need a Dynamics 365 Finance and Operations licence to use the packages, as with any copy from LCS.

## One-time setup

Nothing to configure: check the Actions settings as described in [step 6](#6-check-the-actions-settings) below.

### Your own feed (only if the community storage is unavailable)

#### 1. Choose the version

The version the failing pipeline builds for; its log names it, for example 10.0.49.

#### 2. Download the NuGet packages from LCS

In LCS open **Shared asset library > NuGet package** and download the packages from the table above for that version (each file name ends with the version, `<package>.<version>.nupkg`).

#### 3. Put them on a NuGet feed

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

#### 4. Set the versions

Edit [`build/packages.config`](../build/packages.config): replace each `SET-ME` with the version you uploaded and remove the packages you do not have (for example use one `Microsoft.Dynamics.AX.Application.DevALM.BuildXpp` on versions that are not split). Commit the change to `main`.

#### 5. Add the GitHub secrets

In the repository open **Settings > Secrets and variables > Actions > New repository secret**:

| Secret | Value |
| --- | --- |
| `D365_NUGET_FEED_URL` | The feed URL from step 3 |
| `D365_NUGET_FEED_TOKEN` | The read-only token from step 3 |
| `D365_NUGET_FEED_USER` | Optional; any text for Azure Artifacts |

### 6. Check the Actions settings

In **Settings > Actions > General**, Actions must be allowed, including actions created by GitHub and `microsoft/setup-msbuild`. The release jobs ask for `contents: write` so that they can create releases; the build jobs only read. If the organization limits workflow tokens to read-only (**Organization settings > Actions > General > Workflow permissions**), releases fail until that is lifted.

Actions minutes on a private repository are limited (2,000 a month on GitHub Free), and Windows runners use them at twice the rate. Each push to `main` runs three Windows builds; pull requests run one. The first build of a version downloads its packages and takes longest; later builds use the cache.

## Publishing a release

Merge to `main`. The three pipelines run and each publishes its release under **Releases**. To rebuild without a new commit, open **Actions**, pick a pipeline and click **Run workflow** on `main`.

## Installing a release

From the release for the oldest F&O version you install on, download `OlkInc-D365FO-EDS-...zip` (or the `-Test` one for development and test). Do not extract it before uploading to LCS.

- **Sandbox and production (LCS-managed):** LCS **Asset library > Software deployable package > +**, upload the zip, then on the environment page **Maintain > Apply updates** and pick it. Production is updated from a package that was applied to a sandbox first.
- **Cloud-hosted or local development VM:** extract the zip and install it from the command line with `AXUpdateInstaller.exe` (see Microsoft's *Install deployable packages from the command line*), or with `Invoke-D365SDPInstall` from d365fo.tools. Do not install it on a VM where the model's source is also in PackagesLocalDirectory.
- **Unified (Power Platform) environments:** deploy the package with the Power Platform CLI or Visual Studio as described in Microsoft's documentation for unified environments.

The installation synchronizes the database. Then check the configuration key and roles as described in [Security](security.md).

## Building on your own machine

On a Windows machine with Visual Studio 2022 or Build Tools 2022:

```powershell
./build/Build-EDS.ps1 -Version 1.1.0.0 -FnoVersion 10.0.49 -PackageSuffix -FO10.0.49
```

or, with your own feed:

```powershell
$env:D365_NUGET_FEED_URL = '<feed URL>'
$env:D365_NUGET_FEED_TOKEN = '<read token>'
./build/Build-EDS.ps1 -Version 1.1.0.0
```

The packages go to `out/release`. `out` is ignored by git.

## Alternative: a self-hosted runner

If you do not want to depend on the community storage, a [self-hosted runner](https://docs.github.com/actions/hosting-your-own-runners) on a development VM can build against the VM's own PackagesLocalDirectory instead. The VM then has to be running for every build, and the workflow and script would need changing to use it; the hosted setup above is the default.
