<#
.SYNOPSIS
    Builds the OlkInc-D365FO-EDS models with the Microsoft X++ build NuGet packages and creates
    deployable packages that install without a build.

.DESCRIPTION
    1. Gets the Microsoft X++ build packages (skipped when they are already in -NuGetPath), either
         - from the fscps.tools community storage for -FnoVersion (for example 10.0.49) when it has that version, else
         - from your own NuGet feed (-FeedUrl), with the versions in build/packages.config.
    2. Copies Metadata to a work folder and stamps -Version into the model descriptors.
    3. Compiles OlkInc-D365FO-EDS, then OlkInc-D365FO-EDS-Test (when the ApplicationSuite package is present).
    4. Creates two deployable packages in -OutputPath:
         OlkInc-D365FO-EDS-<version>.zip       the model only, for every environment including production
         OlkInc-D365FO-EDS-Test-<version>.zip  the model and the test model, for development and test environments

    Runs on a GitHub-hosted Windows runner (see .github/workflows/build.yml) or any Windows machine
    with Visual Studio 2022 or Build Tools 2022 (MSBuild and .NET Framework 4.7.2 targeting pack).

.EXAMPLE
    ./build/Build-EDS.ps1 -Version 1.0.0.1 -FnoVersion 10.0.49
    Downloads the packages for 10.0.49 from the fscps.tools community storage.

.EXAMPLE
    ./build/Build-EDS.ps1 -Version 1.0.0.1 -FeedUrl https://pkgs.dev.azure.com/org/_packaging/d365/nuget/v3/index.json -FeedToken $pat
    Restores the packages listed in build/packages.config from your own feed.
#>
[CmdletBinding()]
param(
    [string] $Version = '1.0.0.0',
    [string] $NuGetPath = (Join-Path $PSScriptRoot '..\out\nuget'),
    [string] $WorkPath = (Join-Path $PSScriptRoot '..\out\work'),
    [string] $OutputPath = (Join-Path $PSScriptRoot '..\out\release'),
    [string] $FeedUrl = $env:D365_NUGET_FEED_URL,
    [string] $FeedUser = $(if ($env:D365_NUGET_FEED_USER) { $env:D365_NUGET_FEED_USER } else { 'build' }),
    [string] $FeedToken = $env:D365_NUGET_FEED_TOKEN,
    # F&O version to build for (for example 10.0.49). Its packages come from the fscps.tools community
    # storage when it has them, otherwise from -FeedUrl.
    [string] $FnoVersion = $env:D365_FNO_VERSION,
    [ValidateSet('GA', 'Latest')] [string] $VersionStrategy = $(if ($env:D365_VERSION_STRATEGY) { $env:D365_VERSION_STRATEGY } else { 'GA' }),
    [string] $FscpsToolsVersion = $(if ($env:FSCPS_TOOLS_VERSION) { $env:FSCPS_TOOLS_VERSION } else { '1.1.346' }),
    [switch] $SkipTestModel,
    # Appended to the package file names, for example -FO10.0.49.
    [string] $PackageSuffix = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$mainModel = 'OlkInc-D365FO-EDS'
$testModel = 'OlkInc-D365FO-EDS-Test'

if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw "Version '$Version' must have four numeric parts, for example 1.2.0.15." }
foreach ($p in @($NuGetPath, $WorkPath, $OutputPath)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
$NuGetPath = (Resolve-Path $NuGetPath).Path
$WorkPath = (Resolve-Path $WorkPath).Path
$OutputPath = (Resolve-Path $OutputPath).Path

# ---------------------------------------------------------------- 1. NuGet packages
function Restore-FromFeed {
    $packagesConfig = Join-Path $PSScriptRoot 'packages.config'
    [xml] $pc = Get-Content -Raw $packagesConfig
    $list = @($pc.packages.package | ForEach-Object { [pscustomobject]@{ Id = $_.id; Version = $_.version; Path = Join-Path $NuGetPath "$($_.id).$($_.version)" } })
    $unset = @($list | Where-Object { $_.Version -notmatch '^\d' })
    if ($unset) { throw "Set the versions in build/packages.config first (still unset: $(($unset.Id) -join ', '))." }
    $missing = @($list | Where-Object { -not (Test-Path $_.Path) })
    if ($missing) {
        $nuget = (Get-Command nuget.exe -ErrorAction SilentlyContinue).Source
        if (-not $nuget) {
            $nuget = Join-Path $WorkPath 'nuget.exe'
            Invoke-WebRequest 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nuget
        }
        $nugetConfig = Join-Path $WorkPath 'nuget.config'
        Set-Content $nugetConfig '<?xml version="1.0" encoding="utf-8"?><configuration><packageSources><clear /></packageSources></configuration>'
        & $nuget sources add -Name d365 -Source $FeedUrl -ConfigFile $nugetConfig -NonInteractive | Out-Null
        if ($FeedToken) {
            & $nuget sources update -Name d365 -Username $FeedUser -Password $FeedToken -StorePasswordInClearText -ConfigFile $nugetConfig -NonInteractive | Out-Null
        }
        Write-Host "Restoring $($missing.Count) package(s) from the feed. The application packages are large; this takes a while."
        & $nuget restore $packagesConfig -PackagesDirectory $NuGetPath -ConfigFile $nugetConfig -NonInteractive
        $exit = $LASTEXITCODE
        Remove-Item $nugetConfig -Force
        if ($exit) { throw "nuget restore failed ($exit)." }
    }
    return $list
}

function Import-Fscps {
    if (Get-Module fscps.tools) { return }
    if (-not (Get-Module -ListAvailable fscps.tools | Where-Object { $_.Version -eq [version] $FscpsToolsVersion })) {
        Set-PSRepository PSGallery -InstallationPolicy Trusted
        Install-Module fscps.tools -RequiredVersion $FscpsToolsVersion -Scope CurrentUser -AllowClobber -Force
    }
    Import-Module fscps.tools -RequiredVersion $FscpsToolsVersion -Force
}

# fscps.tools (https://github.com/fscpscollaborative/fscps.tools) keeps the LCS packages for every
# F&O version in a public Azure storage account run by its maintainers. Not a Microsoft service.
function Restore-FromFscps {
    $manifest = Join-Path $NuGetPath "fscps-$FnoVersion-$VersionStrategy.json"
    if (Test-Path $manifest) {
        $list = @(Get-Content -Raw $manifest | ConvertFrom-Json)
        if (-not @($list | Where-Object { -not (Test-Path $_.Path) })) { Write-Host "Using cached packages for $FnoVersion ($VersionStrategy)."; return $list }
    }
    Import-Fscps
    $types = @('PlatformCompilerPackage', 'PlatformDevALM', 'ApplicationDevALM')
    if (-not $SkipTestModel) { $types += 'ApplicationSuiteDevALM' }
    $downloads = Join-Path $WorkPath 'nupkg'
    New-Item -ItemType Directory -Force -Path $downloads | Out-Null
    $list = foreach ($type in $types) {
        Write-Host "Downloading $type for $FnoVersion ($VersionStrategy). The application packages are large; this takes a while."
        # Get-FSCPSNuget also passes on the download's own output (the file); keep only its result hashtable.
        $r = @(Get-FSCPSNuget -KnownVersion $FnoVersion -KnownType $VersionStrategy -Type $type -Path $downloads) |
            Where-Object { $_ -is [hashtable] -and $_.ContainsKey('Package') } | Select-Object -Last 1
        if (-not $r -or -not (Test-Path (Join-Path $r.Path $r.Package))) { throw "fscps.tools could not download $type for $FnoVersion." }
        if ($r.Package -notmatch '^(?<id>Microsoft\.Dynamics\.AX\..+?)\.(?<v>\d+\.\d+\.\d+\.\d+)\.nupkg$') { throw "Unexpected package name $($r.Package)." }
        $target = Join-Path $NuGetPath "$($Matches.id).$($Matches.v)"
        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        Expand-Archive (Join-Path $r.Path $r.Package) $target
        Remove-Item (Join-Path $r.Path $r.Package) -Force
        [pscustomobject]@{ Id = $Matches.id; Version = $Matches.v; Path = $target }
    }
    $list | ConvertTo-Json | Set-Content $manifest
    return @($list)
}

# -FnoVersion uses the community storage when it has that version; otherwise the feed is used when one is configured.
$fscpsHasVersion = $false
if ($FnoVersion) {
    if ($FnoVersion -notmatch '^10\.0\.\d+$') { throw "F&O version '$FnoVersion' must look like 10.0.49." }
    $cached = Test-Path (Join-Path $NuGetPath "fscps-$FnoVersion-$VersionStrategy.json")
    if (-not $cached) { Import-Fscps }
    $fscpsHasVersion = $cached -or [bool](Get-FSCPSVersionInfo -Version $FnoVersion)
}
if ($fscpsHasVersion) { $packages = @(Restore-FromFscps) }
elseif ($FeedUrl) { $packages = @(Restore-FromFeed) }
elseif ($FnoVersion) { throw "No packages for F&O ${FnoVersion}: the fscps.tools community storage does not list it and no NuGet feed is configured." }
else { throw 'No package source: give -FnoVersion (fscps.tools community storage) or set D365_NUGET_FEED_URL (your own feed). See docs/build-and-release.md.' }
$packages | ForEach-Object { Write-Host "Package $($_.Id) $($_.Version)" }

$compiler = $packages | Where-Object Id -eq 'Microsoft.Dynamics.AX.Platform.CompilerPackage'
if (-not $compiler) { throw 'The packages must include Microsoft.Dynamics.AX.Platform.CompilerPackage.' }
$compilerPath = $compiler.Path
$referencePackages = @($packages | Where-Object { $_.Id -ne $compiler.Id })
$hasAppSuite = (-not $SkipTestModel) -and [bool]($packages | Where-Object Id -like '*.ApplicationSuite.DevALM.BuildXpp')

# ---------------------------------------------------------------- 2. Metadata copy with the version stamped
$metadata = Join-Path $WorkPath 'Metadata'
$bin = Join-Path $WorkPath 'bin'
foreach ($p in @($metadata, $bin)) { if (Test-Path $p) { Remove-Item $p -Recurse -Force } }
Copy-Item (Join-Path $repoRoot 'Metadata') $metadata -Recurse
New-Item -ItemType Directory -Force -Path $bin | Out-Null

$v = $Version.Split('.')
Get-ChildItem $metadata -Recurse -Filter *.xml | Where-Object { $_.Directory.Name -eq 'Descriptor' } | ForEach-Object {
    [xml] $d = Get-Content -Raw $_.FullName
    $d.AxModelInfo.VersionMajor = $v[0]; $d.AxModelInfo.VersionMinor = $v[1]
    $d.AxModelInfo.VersionBuild = $v[2]; $d.AxModelInfo.VersionRevision = $v[3]
    $d.Save($_.FullName)
}

# ---------------------------------------------------------------- 3. Compile
$msbuild = (Get-Command msbuild.exe -ErrorAction SilentlyContinue).Source
if (-not $msbuild) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
}
if (-not $msbuild) { throw 'MSBuild was not found. Install Visual Studio 2022 or Build Tools 2022.' }

$referenceFolders = @($referencePackages | ForEach-Object { Join-Path $_.Path 'ref\net40' }) + @($metadata, $bin)
$models = @($mainModel)
if ($hasAppSuite) { $models += $testModel } else { Write-Warning "No ApplicationSuite package (or -SkipTestModel): $testModel is not built." }

foreach ($model in $models) {
    Write-Host "::group::Compile $model"
    $proj = Join-Path $PSScriptRoot "projects\$model\$model.rnrproj"
    & $msbuild $proj /nologo /m /verbosity:minimal /p:Configuration=Debug `
        "/p:BuildTasksDirectory=$compilerPath\DevAlm" `
        "/p:MetadataDirectory=$metadata" `
        "/p:FrameworkDirectory=$compilerPath" `
        "/p:ReferenceFolder=$($referenceFolders -join ';')" `
        "/p:ReferencePath=$compilerPath" `
        "/p:OutputDirectory=$bin"
    $exit = $LASTEXITCODE
    Write-Host '::endgroup::'
    if ($exit) { throw "Compiling $model failed ($exit)." }
    if (-not (Test-Path (Join-Path $bin "$model\bin\Dynamics.AX.$model.dll"))) { throw "Compiling $model produced no Dynamics.AX.$model.dll in $bin." }
}

# ---------------------------------------------------------------- 4. Deployable packages
function Find-CompilerFile([string] $name) {
    $default = Join-Path $compilerPath "ref\net40\$name"
    if (Test-Path $default) { return $default }
    $found = Get-ChildItem $compilerPath -Recurse -Filter $name | Select-Object -First 1
    if (-not $found) { throw "$name not found in $compilerPath." }
    return $found.FullName
}
$createPackage = Find-CompilerFile 'CreatePackage.psm1'
$xppTools = Split-Path $createPackage
$basePackage = Find-CompilerFile 'BaseMetadataDeployablePackage.zip'
Import-Module $createPackage -Force
Add-Type -Path (Find-CompilerFile 'Microsoft.Dynamics.AXCreateDeployablePackageBase.dll')
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-EdsDeployablePackage([string] $name, [string[]] $modules) {
    $stage = Join-Path $WorkPath "stage-$name"
    $combined = Join-Path $WorkPath "$name-runtime.zip"
    $target = Join-Path $OutputPath "$name-$Version$PackageSuffix.zip"
    foreach ($p in @($stage, $combined, $target)) { if (Test-Path $p) { Remove-Item $p -Recurse -Force } }
    New-Item -ItemType Directory -Path $stage | Out-Null
    foreach ($m in $modules) {
        New-XppRuntimePackage -packageName $m -packageDrop $stage -metadataDir $bin -bin $xppTools -enforceVersionCheck $true | Out-Null
    }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $combined)
    [Microsoft.Dynamics.AXCreateDeployablePackageBase.BuildDeployablePackages]::MergePackage($basePackage, $combined, $target, $true, [string]::Empty) | Out-Null
    if (-not (Test-Path $target)) { throw "Deployable package $target was not created." }
    Write-Host "Created $target"
}

New-EdsDeployablePackage $mainModel @($mainModel)
if ($hasAppSuite) { New-EdsDeployablePackage $testModel @($mainModel, $testModel) }
