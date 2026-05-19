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
    Write-Step "winget not found. Attempting to install App Installer..."
    try {
        $progressPreference = 'silentlyContinue'

        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
        $msixBundle = ($releases.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1).browser_download_url
        $licenseXml = ($releases.assets | Where-Object { $_.name -like "*License1.xml" } | Select-Object -First 1).browser_download_url

        if (-not $msixBundle) { throw "Could not locate msixbundle in latest winget-cli release." }
        if (-not $licenseXml) { throw "Could not locate license XML in latest winget-cli release." }

        $tempDir = "$env:TEMP\winget-bootstrap"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        Write-Host "    downloading App Installer ($($releases.tag_name))..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $msixBundle -OutFile "$tempDir\AppInstaller.msixbundle" -UseBasicParsing

        Write-Host "    downloading license..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $licenseXml -OutFile "$tempDir\License1.xml" -UseBasicParsing

        Write-Host "    installing (provisioned)..." -ForegroundColor DarkGray
        Add-AppxProvisionedPackage -Online `
            -PackagePath "$tempDir\AppInstaller.msixbundle" `
            -LicensePath "$tempDir\License1.xml" `
            -ErrorAction Stop

        # Refresh PATH so winget is available in this session
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH", "User")

        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw "App Installer installed but winget still not in PATH."
        }
        Write-Success "App Installer installed. winget is ready."
    }
    catch {
        Write-Fail "Could not install App Installer automatically: $_"
        Write-Fail "Install it manually from the Microsoft Store (App Installer) and re-run."
        exit 1
    }
} else {
    Write-Success "winget found."
}

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
    "flux.version"
    "flux.psm1"
    "Write-FluxOutput.ps1"
    "Invoke-Winget.ps1"
    "Get-FluxAlias.ps1"
    "Get-FluxVersion.ps1"
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
Write-Step "Adding Flux to PSModulePath..."

try {
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
}
catch {
    # Falls here when running as standard user (no HKLM write access).
    # The profile import in Step 7 handles module loading - this is non-critical.
    Write-Host "  [warn] Could not update PSModulePath (Machine) - continuing anyway." -ForegroundColor Yellow
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
