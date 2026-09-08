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

    if ($managed.Count -eq 0) {
        Write-FluxError "No managed software found to export."
        return
    }

    $rows = $managed |
        Select-Object @{Name = "Package"; Expression = { $_.WingetId } }, @{Name = "PinnedVersion"; Expression = { "" } } |
        Sort-Object Package -Unique

    $rows | Export-Csv -Path $Path -NoTypeInformation -Force

    Write-FluxSuccess "Exported $($rows.Count) package(s) to $Path"
    Write-Host "  This includes everything winget recognizes on this machine --" -ForegroundColor DarkGray
    Write-Host "  review and trim it before deploying to a client's fleet." -ForegroundColor DarkGray
    Write-Host ""
}
