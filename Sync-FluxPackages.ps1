# Sync-FluxPackages.ps1
# Phase 2 of the "free C4B" roadmap: ensures the software defined in
# flux-packages.csv is installed and current on this machine -- installs
# whatever's missing, upgrades whatever's outdated, and reports a
# structured per-package result. Folds in Phase 1's reconciliation data so
# the report covers the same ground C4B's sync/audit feature does:
# installed / upgraded / failed / unmanaged.
#
# flux sync never uninstalls anything. Software found on the machine that
# isn't on the list is reported (via the Unmanaged rows), never removed --
# an MSP shouldn't have a script silently ripping software off a client's
# machine because it wasn't in a CSV.

function Get-FluxSyncManifestPath {
    Join-Path $PSScriptRoot "flux-packages.csv"
}


function Get-FluxSyncManifest {
    param()

    $path = Get-FluxSyncManifestPath
    if (-not (Test-Path $path)) { return $null }

    try {
        return @(Import-Csv -Path $path)
    }
    catch {
        return $null
    }
}


function Sync-FluxPackages {
    <#
    .SYNOPSIS
        Ensures the desired software list (flux-packages.csv) is installed
        and current on this machine, and reports the full picture: what got
        installed, what got upgraded, what failed, and what's on the
        machine but unmanaged (via Phase 1's reconciliation).
    .EXAMPLE
        flux sync
    .EXAMPLE
        flux sync -Loud
    .EXAMPLE
        flux sync -ExportCsv C:\ProgramData\Flux\sync-report.csv
    .EXAMPLE
        flux sync -Json
    #>
    [CmdletBinding()]
    param(
        [switch]$Loud,
        [string]$ExportCsv,
        [switch]$Json
    )

    $manifestPath = Get-FluxSyncManifestPath
    $manifest     = Get-FluxSyncManifest

    if (-not $Json) {
        Write-FluxHeader "Syncing installed software against flux-packages.csv..."
        Write-Host ""
    }

    if (-not $manifest) {
        if (-not (Test-Path $manifestPath)) {
            Write-FluxError "No flux-packages.csv found at $manifestPath"
            Write-Host "  Create one with a 'Package' column listing aliases or winget IDs, e.g.:" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "    Package,PinnedVersion" -ForegroundColor DarkGray
            Write-Host "    chrome," -ForegroundColor DarkGray
            Write-Host "    7zip," -ForegroundColor DarkGray
            Write-Host ""
        }
        else {
            Write-FluxError "Could not read flux-packages.csv -- check it's valid CSV."
        }
        return
    }

    if ($manifest.Count -eq 0) {
        Write-FluxError "flux-packages.csv is empty -- nothing to sync."
        return
    }

    $installed  = Get-WingetInstalled
    $upgradable = Get-WingetUpgradable

    $syncResults = foreach ($row in $manifest) {
        $pkgQuery = $row.Package
        if (-not $pkgQuery) { continue }
        $pkgQuery = $pkgQuery.Trim()
        if (-not $pkgQuery) { continue }

        $hasPin = ($row.PSObject.Properties.Name -contains "PinnedVersion") -and $row.PinnedVersion
        # Pinning isn't enforced yet -- that's Phase 3. The column exists now
        # so the manifest schema doesn't need to change when that lands.

        $resolvedId = Get-FluxAlias -Query $pkgQuery
        if (-not $resolvedId) { $resolvedId = $pkgQuery }  # not an alias -- assume it's already a winget Id

        $installedMatch = $installed | Where-Object { $_.Id -ieq $resolvedId } | Select-Object -First 1

        if (-not $installedMatch) {
            if (-not $Json) {
                Write-Host "  " -NoNewline
                Write-Host "[install]" -ForegroundColor Cyan -NoNewline
                Write-Host " $resolvedId..."
            }
            $argList = @("install", "--id", $resolvedId, "--exact", "--accept-package-agreements", "--accept-source-agreements")
            if (-not $Loud) { $argList += "--silent" }
            $code = Invoke-WingetCommand -Live -Arguments $argList

            [PSCustomObject]@{
                Package = $pkgQuery
                Id      = $resolvedId
                Action  = "Install"
                Status  = if ($code -eq 0) { "Success" } else { "Failed" }
                Pinned  = [bool]$hasPin
            }
            continue
        }

        $upgradeMatch = $upgradable | Where-Object { $_.Id -ieq $resolvedId } | Select-Object -First 1

        if ($upgradeMatch) {
            if (-not $Json) {
                Write-Host "  " -NoNewline
                Write-Host "[upgrade]" -ForegroundColor Cyan -NoNewline
                Write-Host " $resolvedId..."
            }
            $argList = @("upgrade", "--id", $resolvedId, "--exact", "--accept-package-agreements", "--accept-source-agreements")
            if (-not $Loud) { $argList += "--silent" }
            $code = Invoke-WingetCommand -Live -Arguments $argList

            [PSCustomObject]@{
                Package = $pkgQuery
                Id      = $resolvedId
                Action  = "Upgrade"
                Status  = if ($code -eq 0) { "Success" } else { "Failed" }
                Pinned  = [bool]$hasPin
            }
            continue
        }

        [PSCustomObject]@{
            Package = $pkgQuery
            Id      = $resolvedId
            Action  = "AlreadyCurrent"
            Status  = "Success"
            Pinned  = [bool]$hasPin
        }
    }

    # Fold in Phase 1's reconciliation so this report covers unmanaged
    # software too, not just the packages we were told to manage.
    $unmanagedResults = @()
    try {
        $reconcileJson = Get-FluxReconciliation -Json | Out-String
        if ($reconcileJson.Trim()) {
            $reconcileData = $reconcileJson | ConvertFrom-Json
            $unmanagedResults = @($reconcileData | Where-Object { $_.Status -eq "Unmanaged" } | ForEach-Object {
                [PSCustomObject]@{
                    Package = $_.DisplayName
                    Id      = ""
                    Action  = "Unmanaged"
                    Status  = "N/A"
                    Pinned  = $false
                }
            })
        }
    }
    catch {
        # Reconciliation is a bonus in this report, not a hard dependency --
        # if it fails for any reason, sync's own results still stand.
    }

    $results = @($syncResults) + @($unmanagedResults)

    if ($ExportCsv) {
        try {
            $results | Export-Csv -Path $ExportCsv -NoTypeInformation -Force
            if (-not $Json) {
                Write-Host ""
                Write-Host "  Exported sync report to $ExportCsv" -ForegroundColor DarkGray
            }
        }
        catch {
            Write-FluxError "Could not write export to '$ExportCsv': $_"
        }
    }

    if ($Json) {
        $results | ConvertTo-Json -Depth 3
        return
    }

    $installedCount = @($syncResults | Where-Object { $_.Action -eq "Install" -and $_.Status -eq "Success" }).Count
    $upgradedCount  = @($syncResults | Where-Object { $_.Action -eq "Upgrade" -and $_.Status -eq "Success" }).Count
    $currentCount   = @($syncResults | Where-Object { $_.Action -eq "AlreadyCurrent" }).Count
    $failedCount    = @($syncResults | Where-Object { $_.Status -eq "Failed" }).Count
    $unmanagedCount = $unmanagedResults.Count

    Write-Host ""
    Write-Host "  $installedCount installed, $upgradedCount upgraded, $currentCount already current, " -NoNewline -ForegroundColor DarkGray
    Write-Host "$failedCount failed" -NoNewline -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "DarkGray" })
    Write-Host ", $unmanagedCount unmanaged" -ForegroundColor $(if ($unmanagedCount -gt 0) { "Yellow" } else { "DarkGray" })

    if ($failedCount -gt 0) {
        Write-Host ""
        Write-Host "  Failed:" -ForegroundColor Red
        $syncResults | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
            Write-Host "    $($_.Id) ($($_.Action))" -ForegroundColor Red
        }
    }

    if ($unmanagedCount -gt 0) {
        Write-Host ""
        Write-Host "  Run " -NoNewline -ForegroundColor DarkGray
        Write-Host "flux reconcile -All" -ForegroundColor Cyan -NoNewline
        Write-Host " for details on unmanaged software." -ForegroundColor DarkGray
    }

    Write-Host ""
}
