<#
.SYNOPSIS
    Builds the OlkInc-D365FO-EDS models with the Microsoft X++ build NuGet packages and creates
    deployable packages that install without a build.

.DESCRIPTION
    1. Restores the packages in build/packages.config (skipped when they are already in -NuGetPath).
    2. Copies Metadata to a work folder and stamps -Version into the model descriptors.
    3. Compiles OlkInc-D365FO-EDS, then OlkInc-D365FO-EDS-Test (when the ApplicationSuite package is present).
    4. Creates two deployable packages in -OutputPath:
         OlkInc-D365FO-EDS-<version>.zip       the model only, for every environment including production
         OlkInc-D365FO-EDS-Test-<version>.zip  the model and the test model, for development and test environments

    Runs on a GitHub-hosted Windows runner (see .github/workflows/build.yml) or any Windows machine
    with Visual Studio 2022 or Build Tools 2022 (MSBuild and .NET Framework 4.7.2 targeting pack).

.EXAMPLE
    ./build/Build-EDS.ps1 -Version 1.0.0.1 -FeedUrl https://pkgs.dev.azure.com/org/_packaging/d365/nuget/v3/index.json -FeedToken $pat
#>
[CmdletBinding()]
param(
    [string] $Version = '1.0.0.0',
    [string] $NuGetPath = (Join-Path $PSScriptRoot '..\out\nuget'),
    [string] $WorkPath = (Join-Path $PSScriptRoot '..\out\work'),
    [string] $OutputPath = (Join-Path $PSScriptRoot '..\out\release'),
    [string] $FeedUrl = $env:D365_NUGET_FEED_URL,
    [string] $FeedUser = $(if ($env:D365_NUGET_FEED_USER) { $env:D365_NUGET_FEED_USER } else { 'build' }),
    [string] $FeedToken = $env:D365_NUGET_FEED_TOKEN
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
$packagesConfig = Join-Path $PSScriptRoot 'packages.config'
[xml] $pc = Get-Content -Raw $packagesConfig
$packages = @($pc.packages.package | ForEach-Object { [pscustomobject]@{ Id = $_.id; Version = $_.version; Path = Join-Path $NuGetPath "$($_.id).$($_.version)" } })
$unset = @($packages | Where-Object { $_.Version -notmatch '^\d' })
if ($unset) { throw "Set the versions in build/packages.config first (still unset: $(($unset.Id) -join ', '))." }

$missing = @($packages | Where-Object { -not (Test-Path $_.Path) })
if ($missing) {
    if (-not $FeedUrl) { throw "Packages missing from $NuGetPath and no feed given. Set D365_NUGET_FEED_URL (see docs/build-and-release.md)." }
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
    if ($LASTEXITCODE) { throw "nuget restore failed ($LASTEXITCODE)." }
    Remove-Item $nugetConfig -Force
}

$compiler = $packages | Where-Object Id -eq 'Microsoft.Dynamics.AX.Platform.CompilerPackage'
if (-not $compiler) { throw 'build/packages.config must contain Microsoft.Dynamics.AX.Platform.CompilerPackage.' }
$compilerPath = $compiler.Path
$referencePackages = @($packages | Where-Object { $_.Id -ne $compiler.Id })
$hasAppSuite = [bool]($packages | Where-Object Id -like '*.ApplicationSuite.DevALM.BuildXpp')

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
if ($hasAppSuite) { $models += $testModel } else { Write-Warning "No ApplicationSuite package in build/packages.config: $testModel is not built." }

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
    $target = Join-Path $OutputPath "$name-$Version.zip"
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
