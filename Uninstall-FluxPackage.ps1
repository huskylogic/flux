# Uninstall-FluxPackage.ps1

function Uninstall-FluxPackage {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Query,

        [Alias("y")]
        [switch]$Yes
    )

    Write-FluxHeader "Looking for installed package '$Query'..."

    # Check alias CSV to resolve common names to package IDs
    $aliasFile = Join-Path $PSScriptRoot "flux-aliases.csv"
    $resolvedId = $null
    if (Test-Path $aliasFile) {
        $aliases = Import-Csv $aliasFile | Where-Object { $_.Alias -notmatch "^#" -and $_.Alias -ne "" }
        $aliasMatch = $aliases | Where-Object { $_.Alias -ieq $Query } | Select-Object -First 1
        if ($aliasMatch) {
            $resolvedId = $aliasMatch.PackageId
        }
    }

    $installed = Get-WingetInstalled

    if (-not $installed -or $installed.Count -eq 0) {
        Write-FluxError "Could not retrieve installed packages."
        return
    }

    # If alias resolved, find by exact ID first
    $match = $null
    if ($resolvedId) {
        $match = $installed | Where-Object { $_.Id -ieq $resolvedId } | Select-Object -First 1
    }

    # Fall back to fuzzy match against installed list
    if (-not $match) {
        $match = Get-BestMatch -Query $Query -Packages $installed
    }

    if (-not $match) {
        Write-FluxError "No installed package matched '$Query'."
        Write-Host "  Try " -NoNewline
        Write-Host "flux list" -ForegroundColor Cyan -NoNewline
        Write-Host " to see all installed packages."
        return
    }

    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "[uninstall]" -ForegroundColor Yellow -NoNewline
    Write-Host "  $($match.Name)  " -NoNewline
    Write-Host "($($match.Id))" -ForegroundColor DarkGray
    Write-Host ""

    Write-FluxHeader "Uninstalling $($match.Id)..."
    Write-Host ""

    $success = Uninstall-WingetPackage -PackageId $match.Id

    Write-Host ""
    if ($success) {
        Write-FluxSuccess "$($match.Name) uninstalled successfully."
    }
    else {
        Write-FluxError "Uninstall failed."
    }
}
