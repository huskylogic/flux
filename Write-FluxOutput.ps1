# Write-FluxOutput.ps1
# Shared output helpers for consistent styling across all Flux commands.

function Write-FluxHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "flux" -ForegroundColor Cyan -NoNewline
    Write-Host " $Message"
}

function Write-FluxSuccess {
    param([string]$Message)
    Write-Host "  " -NoNewline
    Write-Host "[ok]" -ForegroundColor Green -NoNewline
    Write-Host " $Message"
    Write-Host ""
}

function Write-FluxError {
    param([string]$Message)
    Write-Host "  " -NoNewline
    Write-Host "[error]" -ForegroundColor Red -NoNewline
    Write-Host " $Message"
    Write-Host ""
}
