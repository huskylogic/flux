# Public/Get-FluxPackage.ps1

function Get-FluxPackage {
    <#
    .SYNOPSIS
        List all packages installed via winget.
    .EXAMPLE
        flux list
    .EXAMPLE
        flux list python
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Filter = ""
    )

    Write-FluxHeader "Fetching installed packages..."
    Write-Host ""

    $installed = Get-WingetInstalled

    if (-not $installed -or $installed.Count -eq 0) {
        Write-FluxError "Could not retrieve installed packages."
        return
    }

    if ($Filter) {
        $installed = $installed | Where-Object {
            $_.Name -like "*$Filter*" -or $_.Id -like "*$Filter*"
        }
    }

    if ($installed.Count -eq 0) {
        Write-FluxError "No installed packages matched '$Filter'."
        return
    }

    # Column widths
    $nameWidth    = [Math]::Min([Math]::Max(($installed | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum, 4) + 2, 40)
    $idWidth      = [Math]::Min([Math]::Max(($installed | ForEach-Object { $_.Id.Length }   | Measure-Object -Maximum).Maximum, 2) + 2, 45)
    $versionWidth = 12

    # Header
    $header = "{0,-$nameWidth} {1,-$idWidth} {2}" -f "Name", "ID", "Version"
    $sep    = "{0,-$nameWidth} {1,-$idWidth} {2}" -f ("-" * ($nameWidth - 1)), ("-" * ($idWidth - 1)), ("-" * ($versionWidth - 1))

    Write-Host "  $header" -ForegroundColor Cyan
    Write-Host "  $sep"    -ForegroundColor DarkGray

    foreach ($pkg in $installed) {
        $name    = if ($pkg.Name.Length -gt $nameWidth - 2) { $pkg.Name.Substring(0, $nameWidth - 5) + "..." } else { $pkg.Name }
        $id      = if ($pkg.Id.Length -gt $idWidth - 2)     { $pkg.Id.Substring(0, $idWidth - 5) + "..." }     else { $pkg.Id }
        $version = if ($pkg.Version) { $pkg.Version } else { "" }

        Write-Host ("  {0,-$nameWidth}" -f $name) -NoNewline -ForegroundColor White
        Write-Host ("{0,-$idWidth}"     -f $id)   -NoNewline -ForegroundColor Yellow
        Write-Host $version -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  $($installed.Count) package(s) installed." -ForegroundColor DarkGray
    Write-Host ""
}
