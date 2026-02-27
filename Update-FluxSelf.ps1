# Update-FluxSelf.ps1

function Update-FluxSelf {

    $installDir = $PSScriptRoot
    $baseUrl    = "https://raw.githubusercontent.com/huskylogic/flux/main"

    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "[flux update]" -ForegroundColor Cyan -NoNewline
    Write-Host " Pulling from $baseUrl"
    Write-Host ""

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

    $failed  = @()
    $updated = @()

    foreach ($file in $files) {
        $url  = "$baseUrl/$file"
        $dest = Join-Path $installDir $file
        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
            $updated += $file
            Write-Host ("    {0,-40} " -f $file) -NoNewline
            Write-Host "ok" -ForegroundColor Green
        }
        catch {
            $failed += $file
            Write-Host ("    {0,-40} " -f $file) -NoNewline
            Write-Host "failed  " -NoNewline -ForegroundColor Red
            Write-Host "($url)" -ForegroundColor DarkGray
        }
    }

    Get-ChildItem $installDir -Filter "*.ps1" | Unblock-File
    Get-ChildItem $installDir -Filter "*.psd1" | Unblock-File
    Get-ChildItem $installDir -Filter "*.psm1" | Unblock-File

    Write-Host ""

    if ($failed.Count -gt 0) {
        Write-Host "  " -NoNewline
        Write-Host "[warning]" -ForegroundColor Yellow -NoNewline
        Write-Host " $($failed.Count) file(s) failed to update."
    }
    else {
        Write-Host "  " -NoNewline
        Write-Host "[ok]" -ForegroundColor Green -NoNewline
        Write-Host " $($updated.Count) files updated successfully."
        Write-Host ""
        Write-Host "  " -NoNewline
        Write-Host "[note]" -ForegroundColor DarkGray -NoNewline
        Write-Host " flux-aliases.csv was not updated to preserve your custom aliases."
    }

    Write-Host ""
    Write-Host "  Reload Flux to apply the update:" -ForegroundColor DarkGray
    Write-Host "  Remove-Module flux; Import-Module `"$installDir\flux.psd1`"" -ForegroundColor White
    Write-Host ""
}
