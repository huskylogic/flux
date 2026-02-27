# Update-FluxPackages.ps1

function Update-FluxPackages {
    param(
        [Parameter(Position = 0)]
        [string]$Query,

        [Alias("y")]
        [switch]$Yes,

        [Alias("loud")]
        [switch]$Loud
    )

    # Upgrade a single package
    if ($Query) {
        $resolvedId = Get-FluxAlias -Query $Query

        if (-not $resolvedId) {
            # Try fuzzy match against installed packages
            $installed = Get-WingetInstalled
            $match     = Get-BestMatch -Query $Query -Packages $installed
            if ($match) { $resolvedId = $match.Id }
        }

        if (-not $resolvedId) {
            Write-FluxError "Could not find installed package matching '$Query'."
            Write-Host "  Try " -NoNewline
            Write-Host "flux list" -ForegroundColor Cyan -NoNewline
            Write-Host " to see installed packages."
            return
        }

        Write-Host ""
        Write-Host "  " -NoNewline
        Write-Host "[upgrade]" -ForegroundColor Cyan -NoNewline
        Write-Host " Upgrading $resolvedId..."
        Write-Host ""

        $args = @("upgrade", "--id", $resolvedId, "--exact", "--accept-package-agreements", "--accept-source-agreements")
        if (-not $Loud) { $args += "--silent" }
        $code = Invoke-WingetCommand -Live -Arguments $args

        Write-Host ""
        if ($code -eq 0) { Write-FluxSuccess "$resolvedId upgraded successfully." }
        else             { Write-FluxError   "Upgrade failed or no update available for $resolvedId." }
        return
    }

    # Upgrade all installed packages
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "[upgrade]" -ForegroundColor Cyan -NoNewline
    Write-Host " Checking for updates..."
    Write-Host ""

    # First show what's available
    $available = & winget upgrade --accept-source-agreements 2>&1
    $updates   = ConvertFrom-WingetTable -Lines $available

    if (-not $updates -or $updates.Count -eq 0) {
        Write-Host "  " -NoNewline
        Write-Host "[ok]" -ForegroundColor Green -NoNewline
        Write-Host " Everything is up to date."
        Write-Host ""
        return
    }

    Write-Host ("  {0,-35} {1,-20} {2}" -f "PACKAGE", "CURRENT", "AVAILABLE") -ForegroundColor DarkGray
    Write-Host ("  {0,-35} {1,-20} {2}" -f "-------", "-------", "---------") -ForegroundColor DarkGray

    foreach ($u in $updates) {
        Write-Host ("  {0,-35} " -f $u.Name) -NoNewline -ForegroundColor White
        Write-Host ("{0,-20} " -f $u.Version) -NoNewline -ForegroundColor DarkGray
        Write-Host $u.Source -ForegroundColor Green
    }

    Write-Host ""
    Write-Host ("  {0} update(s) available." -f $updates.Count) -ForegroundColor DarkGray
    Write-Host ""

    if (-not $Yes) {
        $confirm = Read-Host "  Upgrade all? [Y/n]"
        if ($confirm -and $confirm -notmatch '^[Yy]') {
            Write-Host "  Aborted." -ForegroundColor DarkGray
            Write-Host ""
            return
        }
    }

    Write-Host ""
    Write-FluxHeader "Upgrading all packages..."
    Write-Host ""

    $args = @("upgrade", "--all", "--accept-package-agreements", "--accept-source-agreements")
    if (-not $Loud) { $args += "--silent" }
    $code = Invoke-WingetCommand -Live -Arguments $args

    Write-Host ""
    if ($code -eq 0) { Write-FluxSuccess "All packages upgraded successfully." }
    else             { Write-FluxError   "Some upgrades may have failed. Run 'flux upgrade -Loud' to see details." }
}
