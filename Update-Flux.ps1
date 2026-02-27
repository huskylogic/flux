#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Updates Flux to the latest version from GitHub.
.EXAMPLE
    .\Update-Flux.ps1
#>
param(
    [string]$GitHubUser = "huskylogic",
    [string]$Repo       = "flux",
    [string]$Branch     = "main",
    [string]$InstallDir = "C:\ProgramData\Flux"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  [flux] Updating Flux from GitHub..." -ForegroundColor Cyan
Write-Host ""

$baseUrl = "https://raw.githubusercontent.com/$GitHubUser/$Repo/$Branch"

$files = @(
    "flux.psd1"
    "flux.psm1"
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

# Note: flux-aliases.csv is NOT updated automatically to preserve local customizations

foreach ($file in $files) {
    $url  = "$baseUrl/$file"
    $dest = Join-Path $InstallDir $file
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Write-Host "    updated $file" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "    failed: $file" -ForegroundColor Red
    }
}

Get-ChildItem $InstallDir | Unblock-File

Write-Host ""
Write-Host "  [ok] Flux updated. Reload with:" -ForegroundColor Green
Write-Host "       Remove-Module flux; Import-Module flux" -ForegroundColor DarkGray
Write-Host ""
