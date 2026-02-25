# Install-FluxPackage.ps1

function Install-FluxPackage {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Query,

        [Alias("y")]
        [switch]$Yes,

        [Alias("e")]
        [switch]$Exact,

        [Alias("scores")]
        [switch]$ShowScores,

        [Alias("s")]
        [switch]$Silent
    )

    # Check alias CSV first
    $aliasFile = Join-Path $PSScriptRoot "flux-aliases.csv"
    $resolvedId = $null
    if (Test-Path $aliasFile) {
        $aliases = Import-Csv $aliasFile | Where-Object { $_.Alias -notmatch "^#" -and $_.Alias -ne "" }
        $aliasMatch = $aliases | Where-Object { $_.Alias -ieq $Query } | Select-Object -First 1
        if ($aliasMatch) {
            $resolvedId = $aliasMatch.PackageId
        }
    }

    # Alias found - install immediately, no prompts
    if ($resolvedId) {
        Write-Host ""
        Write-Host "  " -NoNewline
        Write-Host "[alias]" -ForegroundColor Magenta -NoNewline
        Write-Host " '$Query' -> $resolvedId"
        Write-Host ""
        $success = Install-WingetPackage -PackageId $resolvedId -Silent:$Silent
        Write-Host ""
        if ($success) { Write-FluxSuccess "$resolvedId installed successfully." }
        else          { Write-FluxError "Installation failed." }
        return
    }

    # No alias - fall back to winget search + fuzzy match
    Write-FluxHeader "Searching for '$Query'..."

    $results = Search-WingetPackages -Query $Query

    if (-not $results -or $results.Count -eq 0) {
        Write-FluxError "No packages found for '$Query'."
        return
    }

    # ShowScores mode - show all scores and exit
    if ($ShowScores) {
        Write-Host ""
        Write-Host "  Scores for '$Query':" -ForegroundColor Cyan
        Write-Host "  -----------------------------------------------"
        $results | ForEach-Object {
            $score = Get-PackageScore -Query $Query -Package $_
            $bar   = "#" * [Math]::Round($score / 5)
            $color = if ($score -ge 80) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "DarkGray" }
            Write-Host ("  {0,3}  {1,-45} {2}" -f $score, $_.Id, $bar) -ForegroundColor $color
        }
        Write-Host ""
        Write-Host "  Tip: Add an alias to flux-aliases.csv to lock in the right package." -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    if ($Exact) {
        $match = $results | Where-Object { $_.Id -ieq $Query } | Select-Object -First 1
        if (-not $match) {
            Write-FluxError "No exact match found for '$Query'."
            return
        }
    }
    else {
        $match = Get-BestMatch -Query $Query -Packages $results
    }

    if (-not $match) {
        Write-FluxError "Could not determine a best match for '$Query'."
        Write-Host "  Try " -NoNewline
        Write-Host "flux search $Query" -ForegroundColor Cyan -NoNewline
        Write-Host " to browse results manually."
        Write-Host "  Or add an alias to flux-aliases.csv for reliable installs." -ForegroundColor DarkGray
        return
    }

    Write-Host ""
    Write-Host "  Best match:  " -NoNewline
    Write-Host $match.Name -ForegroundColor White -NoNewline
    Write-Host "  ($($match.Id))" -ForegroundColor DarkGray -NoNewline
    Write-Host "  $($match.Version)" -ForegroundColor Green
    Write-Host ""

    if (-not $Yes) {
        $confirm = Read-Host "  Install this package? [Y/n]"
        if ($confirm -and $confirm -notmatch '^[Yy]') {
            Write-Host "  Aborted." -ForegroundColor DarkGray
            return
        }
    }

    Write-FluxHeader "Installing $($match.Id)..."
    Write-Host ""

    $success = Install-WingetPackage -PackageId $match.Id -Silent:$Silent

    Write-Host ""
    if ($success) {
        Write-FluxSuccess "$($match.Name) installed successfully."
    }
    else {
        Write-FluxError "Installation failed."
    }
}