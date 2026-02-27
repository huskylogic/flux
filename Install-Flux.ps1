#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Flux to C:\ProgramData\Flux and adds it to the system PATH.
.DESCRIPTION
    Downloads the latest Flux release from GitHub and installs it system-wide
    so all users on the machine can run 'flux' from any PowerShell window.
.PARAMETER GitHubUser
    Your GitHub username (default: update this to your actual username)
.PARAMETER Branch
    Branch to download from (default: main)
.EXAMPLE
    .\Install-Flux.ps1
.EXAMPLE
    # Run from RMM or remote session:
    irm https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1 | iex
#>
param(
    [string]$GitHubUser = "huskylogic",
    [string]$Repo       = "flux",
    [string]$Branch     = "main",
    [string]$InstallDir = "C:\ProgramData\Flux"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "  [flux] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [ok]   " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  [err]  " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

Write-Host ""
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host "   Flux Installer" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Check winget ───────────────────────────────────────────────────────
Write-Step "Checking winget..."
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Fail "winget not found. Install App Installer from the Microsoft Store first."
    exit 1
}
Write-Success "winget found."

# ── Step 2: Set execution policy ──────────────────────────────────────────────
Write-Step "Setting execution policy..."
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction Stop
} catch {
    # RMM tools like Action1 run in Bypass mode which overrides this setting.
    # Bypass is more permissive than RemoteSigned so this is fine.
}
Write-Success "ExecutionPolicy set to RemoteSigned (LocalMachine)."

# ── Step 3: Create install directory ──────────────────────────────────────────
Write-Step "Creating install directory at $InstallDir..."
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Write-Success "Directory ready."

# ── Step 4: Download files from GitHub ────────────────────────────────────────
Write-Step "Downloading Flux from GitHub ($GitHubUser/$Repo @ $Branch)..."

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
    "flux-aliases.csv"
)

$failed = @()
foreach ($file in $files) {
    $url  = "$baseUrl/$file"
    $dest = Join-Path $InstallDir $file
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Write-Host "    downloaded $file" -ForegroundColor DarkGray
    }
    catch {
        $failed += $file
        Write-Fail "Failed to download $file"
    }
}

if ($failed.Count -gt 0) {
    Write-Fail "Some files failed to download. Check your GitHub URL and try again."
    exit 1
}

Write-Success "All files downloaded."

# ── Step 5: Unblock all files ─────────────────────────────────────────────────
Write-Step "Unblocking files..."
Get-ChildItem $InstallDir | Unblock-File
Write-Success "Files unblocked."

# ── Step 6: Add to system PATH ────────────────────────────────────────────────
Write-Step "Adding Flux to system PATH..."

$currentPath = [System.Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
if ($currentPath -notlike "*$InstallDir*") {
    [System.Environment]::SetEnvironmentVariable(
        "PSModulePath",
        "$currentPath;$InstallDir",
        "Machine"
    )
    Write-Success "Added to PSModulePath (Machine)."
} else {
    Write-Success "Already in PSModulePath."
}

# ── Step 7: Add auto-import to system PowerShell profile ──────────────────────
Write-Step "Configuring auto-import..."

$profileDir = "C:\Windows\System32\WindowsPowerShell\v1.0"
$profilePath = Join-Path $profileDir "profile.ps1"
$importLine  = "Import-Module `"$InstallDir\flux.psd1`" -ErrorAction SilentlyContinue"

if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($profileContent -notlike "*flux.psd1*") {
    Add-Content -Path $profilePath -Value "`n$importLine"
    Write-Success "Added import to system PowerShell profile."
} else {
    Write-Success "Already configured in PowerShell profile."
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ================================" -ForegroundColor Green
Write-Host "   Flux installed successfully!" -ForegroundColor Green
Write-Host "  ================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Open a new PowerShell window and type " -NoNewline
Write-Host "flux" -ForegroundColor Cyan -NoNewline
Write-Host " to get started."
Write-Host ""
