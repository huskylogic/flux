# Get-FluxAliases.ps1

function Get-FluxAliases {
    param(
        [Parameter(Position = 0)]
        [string]$Filter
    )

    $aliasFile = Join-Path $PSScriptRoot "flux-aliases.csv"

    if (-not (Test-Path $aliasFile)) {
        Write-FluxError "flux-aliases.csv not found at $aliasFile"
        return
    }

    $aliases = Import-Csv $aliasFile | Where-Object { $_.Alias -notmatch "^#" -and $_.Alias -ne "" }

    if ($Filter) {
        $aliases = $aliases | Where-Object {
            $_.Alias -like "*$Filter*" -or $_.PackageId -like "*$Filter*"
        }
    }

    if (-not $aliases -or @($aliases).Count -eq 0) {
        Write-Host ""
        Write-Host "  No aliases found matching '$Filter'." -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    Write-Host ""
    if ($Filter) {
        Write-Host "  Aliases matching '$Filter':" -ForegroundColor Cyan
    } else {
        Write-Host "  All available aliases:" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host ("  {0,-25} {1}" -f "ALIAS", "PACKAGE ID") -ForegroundColor DarkGray
    Write-Host ("  {0,-25} {1}" -f "-----", "----------") -ForegroundColor DarkGray

    foreach ($a in $aliases) {
        Write-Host ("  {0,-25} " -f $a.Alias) -NoNewline -ForegroundColor White
        Write-Host $a.PackageId -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host ("  {0} alias(es) found." -f @($aliases).Count) -ForegroundColor DarkGray
    Write-Host "  To install:  " -NoNewline -ForegroundColor DarkGray
    Write-Host "flux install [alias]" -ForegroundColor Cyan
    Write-Host ""
}
