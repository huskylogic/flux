# Public/Search-FluxPackage.ps1

function Search-FluxPackage {
    <#
    .SYNOPSIS
        Search for packages and display results in a clean table.
    .EXAMPLE
        flux search firefox
    .EXAMPLE
        flux search python -Limit 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Query,

        [Alias("l")]
        [int]$Limit = 10
    )

    Write-FluxHeader "Searching for '$Query'..."
    Write-Host ""

    $results = Search-WingetPackages -Query $Query

    if (-not $results -or $results.Count -eq 0) {
        Write-FluxError "No results found for '$Query'."
        return
    }

    $results = $results | Select-Object -First $Limit

    # Column widths
    $nameWidth    = [Math]::Max(($results | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum, 4) + 2
    $idWidth      = [Math]::Max(($results | ForEach-Object { $_.Id.Length }   | Measure-Object -Maximum).Maximum, 2) + 2
    $versionWidth = 10

    # Clamp widths
    $nameWidth    = [Math]::Min($nameWidth, 40)
    $idWidth      = [Math]::Min($idWidth, 45)

    # Header
    $header = "{0,-$nameWidth} {1,-$idWidth} {2,-$versionWidth} {3}" -f "Name", "ID", "Version", "Source"
    $sep    = ("{0,-$nameWidth} {1,-$idWidth} {2,-$versionWidth} {3}" -f ("-" * ($nameWidth - 1)), ("-" * ($idWidth - 1)), ("-" * ($versionWidth - 1)), "------")

    Write-Host "  $header" -ForegroundColor Cyan
    Write-Host "  $sep"    -ForegroundColor DarkGray

    foreach ($pkg in $results) {
        $name    = if ($pkg.Name.Length -gt $nameWidth - 2)    { $pkg.Name.Substring(0, $nameWidth - 5) + "..." }    else { $pkg.Name }
        $id      = if ($pkg.Id.Length -gt $idWidth - 2)        { $pkg.Id.Substring(0, $idWidth - 5) + "..." }        else { $pkg.Id }
        $version = if ($pkg.Version) { $pkg.Version } else { "" }
        $source  = if ($pkg.Source)  { $pkg.Source  } else { "winget" }

        Write-Host ("  {0,-$nameWidth}" -f $name) -NoNewline -ForegroundColor White
        Write-Host ("{0,-$idWidth}"     -f $id)   -NoNewline -ForegroundColor Yellow
        Write-Host ("{0,-$versionWidth}" -f $version) -NoNewline -ForegroundColor Green
        Write-Host $source -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  $($results.Count) result(s).  Use " -NoNewline -ForegroundColor DarkGray
    Write-Host "flux install <name>" -NoNewline -ForegroundColor Cyan
    Write-Host " to install." -ForegroundColor DarkGray
    Write-Host ""
}
