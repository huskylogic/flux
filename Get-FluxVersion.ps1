# Get-FluxVersion.ps1

function Get-FluxVersion {
    $versionFile = Join-Path $PSScriptRoot "flux.version"
    if (Test-Path $versionFile) {
        $version = (Get-Content $versionFile -Raw).Trim()
    } else {
        $version = "unknown"
    }
    return $version
}

function Show-FluxVersion {
    $version = Get-FluxVersion
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "flux" -ForegroundColor Cyan -NoNewline
    Write-Host " version " -NoNewline
    Write-Host $version -ForegroundColor Green
    Write-Host "  github.com/huskylogic/flux" -ForegroundColor DarkGray
    Write-Host ""
}
