<#
.SYNOPSIS
    Creates the deployable packages from compiled X++ models. Called by Build-EDS.ps1.

.DESCRIPTION
    Runs in Windows PowerShell 5.1, because Microsoft's CreatePackage.psm1 and the X++ metadata assemblies are
    .NET Framework code. Creates in -OutputPath:
      <MainModel>-<Version><PackageSuffix>.zip   the main model only
      <TestModel>-<Version><PackageSuffix>.zip   the main model and the test model (when -TestModel is given)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $CompilerPath,
    [Parameter(Mandatory)] [string] $BinPath,
    [Parameter(Mandatory)] [string] $WorkPath,
    [Parameter(Mandatory)] [string] $OutputPath,
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $MainModel,
    [string] $TestModel,
    [string] $PackageSuffix = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$compilerPath = $CompilerPath
$bin = $BinPath

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
# CreatePackage.psm1 needs the metadata assemblies loaded first (as in Microsoft's and fscps.tools' packaging).
$assemblyDir = Split-Path (Find-CompilerFile 'Microsoft.Dynamics.AX.Metadata.dll')
foreach ($a in @('Microsoft.Dynamics.AX.Metadata.Core', 'Microsoft.Dynamics.AX.Metadata', 'Microsoft.Dynamics.AX.Metadata.Storage',
        'Microsoft.Dynamics.ApplicationPlatform.XppServices.Instrumentation', 'Microsoft.Dynamics.AX.Metadata.Management.Core',
        'Microsoft.Dynamics.AX.Metadata.Management.Delta', 'Microsoft.Dynamics.AX.Metadata.Management.Diff',
        'Microsoft.Dynamics.AX.Metadata.Management.Merge')) {
    $file = Join-Path $assemblyDir "$a.dll"
    if (Test-Path $file) { [Reflection.Assembly]::LoadFile($file) | Out-Null } else { Write-Warning "$a.dll not found in $assemblyDir." }
}
Add-Type -Path (Find-CompilerFile 'Microsoft.Dynamics.AXCreateDeployablePackageBase.dll')

function New-EdsDeployablePackage([string] $name, [string[]] $modules) {
    $stage = Join-Path $WorkPath "stage-$name"
    $combined = Join-Path $WorkPath "$name-runtime.zip"
    $target = Join-Path $OutputPath "$name-$Version$PackageSuffix.zip"
    foreach ($p in @($stage, $combined, $target)) { if (Test-Path $p) { Remove-Item $p -Recurse -Force } }
    New-Item -ItemType Directory -Path $stage | Out-Null
    foreach ($m in $modules) {
        New-XppRuntimePackage -packageName $m -packageDrop (Join-Path $bin $m) -outputDir $stage -metadataDir $bin `
            -packageVersion $Version -binDir $xppTools -enforceVersionCheck $true | Out-Null
    }
    [Microsoft.Dynamics.AXCreateDeployablePackageBase.BuildDeployablePackages]::CreateMetadataPackage($stage, $combined) | Out-Null
    [Microsoft.Dynamics.AXCreateDeployablePackageBase.BuildDeployablePackages]::MergePackage($basePackage, $combined, $target, $true, [string]::Empty) | Out-Null
    if (-not (Test-Path $target)) { throw "Deployable package $target was not created." }
    Write-Host "Created $target"
}

New-EdsDeployablePackage $MainModel @($MainModel)
if ($TestModel) { New-EdsDeployablePackage $TestModel @($MainModel, $TestModel) }
