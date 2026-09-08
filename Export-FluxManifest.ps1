# Export-FluxManifest.ps1
# Bootstraps a flux-packages.csv manifest from a "golden" reference machine
# instead of hand-writing one. Pulls from reconcile's already-cleaned
# Managed list (hotfixes, sub-components, and unmatched Store/MSIX packages
# are already filtered out there) rather than raw `winget list`.
#
# This is a starting point, not a finished manifest -- review and trim the
# result before deploying it to a client's fleet. It captures everything
# winget recognizes on this machine, which usually includes things you
# don't actually want templated onto every endpoint (one-off personal
# tools, trial software, etc).

function Export-FluxManifest {
    <#
    .SYNOPSIS
        Generates a flux-packages.csv manifest from the software winget
        recognizes as installed on this machine.
    .EXAMPLE
        flux export
    .EXAMPLE
        flux export -Path C:\ProgramData\Flux\clientA-packages.csv
    .EXAMPLE
        flux export -Force
    #>
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $PSScriptRoot "flux-packages.csv"),
        [switch]$Force
    )

    if ((Test-Path $Path) -and -not $Force) {
        Write-FluxError "$Path already exists. Use -Force to overwrite, or -Path to export somewhere else."
        return
    }

    Write-FluxHeader "Exporting winget-managed software..."
    Write-Host ""

    $reconcileJson = Get-FluxReconciliation -Json | Out-String
    if (-not $reconcileJson.Trim()) {
        Write-FluxError "Could not get reconciliation data to export from."
        return
    }

    $reconcileData = $reconcileJson | ConvertFrom-Json
    $managed = @($reconcileData | Where-Object { $_.Status -eq "Managed" -and $_.WingetId })

    # winget's own "Id" column isn't always a real, portable catalog ID.
    # When it can't cleanly match installed software to its catalog, it
    # falls back to showing the local ARP registry path or Appx package
    # family name instead -- these are tied to this specific machine and
    # aren't installable anywhere else, so a manifest built from them would
    # just fail on every other endpoint it's deployed to.
    $portable    = @($managed | Where-Object { $_.WingetId -notmatch '^(ARP|MSIX)\\' })
    $skippedCount = $managed.Count - $portable.Count

    if ($portable.Count -eq 0) {
        Write-FluxError "No exportable software found -- everything matched only had a local, non-portable winget Id."
        return
    }

    $rows = $portable |
        Select-Object @{Name = "Package"; Expression = { $_.WingetId } }, @{Name = "PinnedVersion"; Expression = { "" } } |
        Sort-Object Package -Unique

    $rows | Export-Csv -Path $Path -NoTypeInformation -Force

    Write-FluxSuccess "Exported $($rows.Count) package(s) to $Path"
    if ($skippedCount -gt 0) {
        Write-Host "  Skipped $skippedCount item(s) winget could only identify by a local ID" -ForegroundColor DarkGray
        Write-Host "  (not portable to other machines) -- run flux reconcile -All to see them." -ForegroundColor DarkGray
    }
    Write-Host "  This includes everything winget recognizes on this machine --" -ForegroundColor DarkGray
    Write-Host "  review and trim it before deploying to a client's fleet." -ForegroundColor DarkGray
    Write-Host ""
}
