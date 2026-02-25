# flux.psm1

#region Load all functions

$fluxRoot = $PSScriptRoot

$loadOrder = @(
    "Write-FluxOutput.ps1"
    "Invoke-Winget.ps1"
    "Get-BestMatch.ps1"
    "Install-FluxPackage.ps1"
    "Search-FluxPackage.ps1"
    "Uninstall-FluxPackage.ps1"
    "Get-FluxPackage.ps1"
)

foreach ($file in $loadOrder) {
    $path = Join-Path $fluxRoot $file
    if (Test-Path $path) {
        . $path
    } else {
        Write-Warning "flux: Could not find $file at $path"
    }
}

#endregion

#region flux dispatcher

$fluxAliasMap = @{
    "install"   = "Install-FluxPackage"
    "search"    = "Search-FluxPackage"
    "uninstall" = "Uninstall-FluxPackage"
    "list"      = "Get-FluxPackage"
}

function flux {
    param(
        [Parameter(Position = 0)]
        [string]$Command,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        $Rest
    )

    if (-not $Command) {
        Write-Host ""
        Write-Host "  " -NoNewline
        Write-Host "flux" -ForegroundColor Cyan -NoNewline
        Write-Host " -- a smarter winget wrapper"
        Write-Host ""
        Write-Host "  Usage:" -ForegroundColor DarkGray
        Write-Host "    flux install   [package]    " -NoNewline -ForegroundColor White
        Write-Host "Install a package" -ForegroundColor DarkGray
        Write-Host "    flux search    [package]    " -NoNewline -ForegroundColor White
        Write-Host "Search for packages" -ForegroundColor DarkGray
        Write-Host "    flux uninstall [package]    " -NoNewline -ForegroundColor White
        Write-Host "Uninstall a package" -ForegroundColor DarkGray
        Write-Host "    flux list      [filter]     " -NoNewline -ForegroundColor White
        Write-Host "List installed packages" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Options:" -ForegroundColor DarkGray
        Write-Host "    -Yes / -y                  " -NoNewline -ForegroundColor White
        Write-Host "Skip confirmation prompts" -ForegroundColor DarkGray
        Write-Host "    -Exact / -e                " -NoNewline -ForegroundColor White
        Write-Host "Use exact package ID (install only)" -ForegroundColor DarkGray
        Write-Host "    -Limit / -l [n]            " -NoNewline -ForegroundColor White
        Write-Host "Max results to show (search only)" -ForegroundColor DarkGray
        Write-Host "    -ShowScores / -scores      " -NoNewline -ForegroundColor White
        Write-Host "Show fuzzy match scores (install only)" -ForegroundColor DarkGray
        Write-Host "    -Silent / -s               " -NoNewline -ForegroundColor White
        Write-Host "Suppress winget output (install only)" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    $cmdLower = $Command.ToLower()

    if ($fluxAliasMap.ContainsKey($cmdLower)) {
        $fn = $fluxAliasMap[$cmdLower]
        & $fn @Rest
    }
    else {
        Write-FluxError "Unknown command '$Command'."
        Write-Host "  Run " -NoNewline
        Write-Host "flux" -ForegroundColor Cyan -NoNewline
        Write-Host " with no arguments to see usage."
    }
}

#endregion

Export-ModuleMember -Function flux, Install-FluxPackage, Search-FluxPackage, Uninstall-FluxPackage, Get-FluxPackage
