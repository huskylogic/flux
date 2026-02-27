# Install-FluxPackage.ps1

function Install-FluxPackage {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        $PackageArgs,

        [Alias("y")]
        [switch]$Yes,

        [Alias("e")]
        [switch]$Exact,

        [Alias("scores")]
        [switch]$ShowScores,

        [switch]$Loud
    )

    # Parse package list - supports comma-separated and space-separated
    $queries = @()
    foreach ($arg in $PackageArgs) {
        $arg -split "," | ForEach-Object {
            $clean = $_.Trim()
            if ($clean -ne "") { $queries += $clean }
        }
    }

    if ($queries.Count -eq 0) {
        Write-FluxError "No package specified."
        return
    }

    foreach ($Query in $queries) {
        Write-Host ""
        Write-Host "  " -NoNewline
        Write-Host "---" -ForegroundColor DarkGray -NoNewline
        Write-Host " $Query " -ForegroundColor Cyan -NoNewline
        Write-Host "---" -ForegroundColor DarkGray

        # Resolve alias
        $resolvedId = Get-FluxAlias -Query $Query

        if ($resolvedId) {
            Write-Host "  " -NoNewline
            Write-Host "[alias]" -ForegroundColor Magenta -NoNewline
            Write-Host " '$Query' -> $resolvedId"
            Write-Host ""
            $success = Install-WingetPackage -PackageId $resolvedId -Silent:(-not $Loud)
            Write-Host ""
            if ($success) { Write-FluxSuccess "$resolvedId installed successfully." }
            else          { Write-FluxError   "Installation of $resolvedId failed." }
            continue
        }

        # No alias - fuzzy search
        Write-FluxHeader "Searching for '$Query'..."
        $results = Search-WingetPackages -Query $Query

        if (-not $results -or $results.Count -eq 0) {
            Write-FluxError "No packages found for '$Query'."
            continue
        }

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
            continue
        }

        if ($Exact) {
            $match = $results | Where-Object { $_.Id -ieq $Query } | Select-Object -First 1
            if (-not $match) {
                Write-FluxError "No exact match found for '$Query'."
                continue
            }
        }
        else {
            $match = Get-BestMatch -Query $Query -Packages $results
        }

        if (-not $match) {
            Write-FluxError "Could not determine a best match for '$Query'."
            Write-Host "  Try " -NoNewline
            Write-Host "flux search $Query" -ForegroundColor Cyan -NoNewline
            Write-Host " to browse results, or add an alias to flux-aliases.csv."
            continue
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
                continue
            }
        }

        Write-FluxHeader "Installing $($match.Id)..."
        Write-Host ""
        $success = Install-WingetPackage -PackageId $match.Id -Silent:(-not $Loud)
        Write-Host ""
        if ($success) { Write-FluxSuccess "$($match.Name) installed successfully." }
        else          { Write-FluxError   "Installation of $($match.Name) failed." }
    }
}
