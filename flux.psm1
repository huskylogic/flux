# flux.psm1

#region Load all functions

$fluxRoot = $PSScriptRoot

$loadOrder = @(
    "Write-FluxOutput.ps1"
    "Invoke-Winget.ps1"
    "Get-FluxAlias.ps1"
    "Get-BestMatch.ps1"
    "Install-FluxPackage.ps1"
    "Search-FluxPackage.ps1"
    "Uninstall-FluxPackage.ps1"
    "Get-FluxPackage.ps1"
    "Get-FluxAliases.ps1"
    "Update-FluxSelf.ps1"
    "Update-FluxPackages.ps1"
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
    "aliases"   = "Get-FluxAliases"
    "update"    = "Update-FluxSelf"
    "upgrade"   = "Update-FluxPackages"
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
        Write-Host "    flux install   [package(s)]  " -NoNewline -ForegroundColor White
        Write-Host "Install one or more packages" -ForegroundColor DarkGray
        Write-Host "    flux uninstall [package]     " -NoNewline -ForegroundColor White
        Write-Host "Uninstall a package" -ForegroundColor DarkGray
        Write-Host "    flux upgrade   [package]     " -NoNewline -ForegroundColor White
        Write-Host "Upgrade one package, or all if none specified" -ForegroundColor DarkGray
        Write-Host "    flux search    [package]     " -NoNewline -ForegroundColor White
        Write-Host "Search winget for packages" -ForegroundColor DarkGray
        Write-Host "    flux list      [filter]      " -NoNewline -ForegroundColor White
        Write-Host "List installed packages" -ForegroundColor DarkGray
        Write-Host "    flux aliases   [filter]      " -NoNewline -ForegroundColor White
        Write-Host "Browse available aliases" -ForegroundColor DarkGray
        Write-Host "    flux update                  " -NoNewline -ForegroundColor White
        Write-Host "Update the Flux tool itself from GitHub" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Options:" -ForegroundColor DarkGray
        Write-Host "    -Loud                        " -NoNewline -ForegroundColor White
        Write-Host "Show winget output (silent by default)" -ForegroundColor DarkGray
        Write-Host "    -Yes / -y                    " -NoNewline -ForegroundColor White
        Write-Host "Skip confirmation prompts" -ForegroundColor DarkGray
        Write-Host "    -Exact / -e                  " -NoNewline -ForegroundColor White
        Write-Host "Use exact package ID (install only)" -ForegroundColor DarkGray
        Write-Host "    -Limit / -l [n]              " -NoNewline -ForegroundColor White
        Write-Host "Max results to show (search only)" -ForegroundColor DarkGray
        Write-Host "    -ShowScores / -scores        " -NoNewline -ForegroundColor White
        Write-Host "Show fuzzy match scores (install only)" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Examples:" -ForegroundColor DarkGray
        Write-Host "    flux install chrome, vscode, 7zip, notepad++" -ForegroundColor White
        Write-Host "    flux upgrade" -ForegroundColor White
        Write-Host "    flux upgrade chrome" -ForegroundColor White
        Write-Host "    flux aliases browser" -ForegroundColor White
        Write-Host "    flux update" -ForegroundColor White
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

Export-ModuleMember -Function flux, Install-FluxPackage, Search-FluxPackage, Uninstall-FluxPackage, Get-FluxPackage, Get-FluxAliases, Get-FluxAlias, Update-FluxSelf, Update-FluxPackages
