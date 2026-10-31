<#
.SYNOPSIS
    Finds the generally available finance and operations version to build for, from Microsoft's release schedule.

.DESCRIPTION
    Reads the release table in Microsoft's "Service update availability" page (the Markdown source in the
    MicrosoftDocs/dynamics-365-unified-operations-public repository), lists the versions that are generally
    available today and not past end of service, newest first, and returns the one at -Offset:
    0 is the newest GA version, 1 the one before it, 2 the one before that.

    Writes fno=<version> to $env:GITHUB_OUTPUT when it is set.
#>
[CmdletBinding()]
param(
    [ValidateRange(0, 10)] [int] $Offset = 0,
    [datetime] $Today = [datetime]::UtcNow.Date,
    [string] $ScheduleUrl = 'https://raw.githubusercontent.com/MicrosoftDocs/dynamics-365-unified-operations-public/main/articles/fin-ops-core/dev-itpro/get-started/public-preview-releases.md'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$markdown = (Invoke-WebRequest $ScheduleUrl -UseBasicParsing).Content
$culture = [Globalization.CultureInfo]::InvariantCulture
function ConvertTo-Date([string] $text) {
    $d = [datetime]::MinValue
    if ([datetime]::TryParseExact($text.Trim(), 'MMMM d, yyyy', $culture, [Globalization.DateTimeStyles]::None, [ref] $d)) { return $d }
    return $null
}

# | CY26Q4: 10.0.49\* | Preview availability | Preview latest update | General availability | Autoupdate 1 | Autoupdate 2 | End of service |
$releases = foreach ($line in $markdown -split "`n") {
    if ($line -notmatch '^\|\s*CY\d+Q\d+:\s*(?<v>10\.0\.\d+)') { continue }
    $version = $Matches.v
    $cells = $line.Trim().Trim('|') -split '\|'
    if ($cells.Count -lt 7) { continue }
    [pscustomobject]@{
        Version      = $version
        Number       = [int] $version.Split('.')[2]
        Ga           = ConvertTo-Date $cells[3]
        EndOfService = ConvertTo-Date $cells[6]
    }
}
$releases = @($releases | Where-Object { $_.Ga } | Sort-Object Number -Descending -Unique)
if (-not $releases) { throw "No release table found in $ScheduleUrl; the page layout may have changed." }

$ga = @($releases | Where-Object { $_.Ga -le $Today -and (-not $_.EndOfService -or $_.EndOfService -gt $Today) })
Write-Host "Generally available today: $(($ga.Version) -join ', ')"
if ($ga.Count -le $Offset) { throw "Only $($ga.Count) generally available version(s) found; offset $Offset is out of range." }

$fno = $ga[$Offset].Version
Write-Host "Building for F&O $fno (newest GA - $Offset)"
if ($env:GITHUB_OUTPUT) { "fno=$fno" | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8 }
$fno
