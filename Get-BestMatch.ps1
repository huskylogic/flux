# Get-BestMatch.ps1
# Fuzzy matching engine for Flux.
# Scores packages against a query using multiple strategies and returns the best candidate.

function Get-LevenshteinDistance {
    param([string]$A, [string]$B)

    $la = $A.Length
    $lb = $B.Length
    if ($la -eq 0) { return $lb }
    if ($lb -eq 0) { return $la }

    $dp = New-Object 'int[,]' ($la + 1), ($lb + 1)

    for ($i = 0; $i -le $la; $i++) { $dp[$i, 0] = $i }
    for ($j = 0; $j -le $lb; $j++) { $dp[0, $j] = $j }

    for ($i = 1; $i -le $la; $i++) {
        for ($j = 1; $j -le $lb; $j++) {
            $cost = if ($A[$i - 1] -eq $B[$j - 1]) { 0 } else { 1 }
            $dp[$i, $j] = [Math]::Min(
                [Math]::Min($dp[$i - 1, $j] + 1, $dp[$i, $j - 1] + 1),
                $dp[$i - 1, $j - 1] + $cost
            )
        }
    }

    return $dp[$la, $lb]
}


function Get-PackageScore {
    param(
        [string]$Query,
        [PSCustomObject]$Package
    )

    $q    = $Query.ToLower()
    $id   = $Package.Id.ToLower()
    $name = $Package.Name.ToLower()

    $score = 0

    # Exact ID match
    if ($id -eq $q) { return 100 }

    # Exact name match
    if ($name -eq $q) { $score = [Math]::Max($score, 95) }

    # ID ends with .Query segment (e.g. "vscode" -> "Microsoft.VisualStudioCode" won't hit,
    # but "git" -> "Git.Git" will hit via the segment check below)
    if ($id -like "*.$q") { $score = [Math]::Max($score, 90) }

    # Name starts with query
    if ($name -like "$q*") { $score = [Math]::Max($score, 85) }

    # Query is an exact dot-separated segment of the ID (e.g. "git" in "Git.Git")
    $idParts = $id -split '\.'
    if ($idParts -icontains $q) { $score = [Math]::Max($score, 82) }

    # Name contains query as a whole word
    if ($name -match "\b$([regex]::Escape($q))\b") { $score = [Math]::Max($score, 78) }

    # ID contains query as substring
    if ($id -like "*$q*") { $score = [Math]::Max($score, 70) }

    # Name contains query as substring
    if ($name -like "*$q*") { $score = [Math]::Max($score, 65) }

    # Levenshtein similarity against individual name tokens (catches typos)
    if ($score -lt 50) {
        $tokens = ($name -split '[\s\.\-_]+') | Where-Object { $_.Length -gt 1 }
        $bestSim = ($tokens | ForEach-Object {
            $dist   = Get-LevenshteinDistance $q $_
            $maxLen = [Math]::Max($q.Length, $_.Length)
            if ($maxLen -gt 0) { [int](100 * (1 - $dist / $maxLen)) } else { 0 }
        } | Measure-Object -Maximum).Maximum
        if ($bestSim) { $score = [Math]::Max($score, [Math]::Min($bestSim, 55)) }
    }

    # Penalise pre-release packages unless the query explicitly asks for them
    $preReleaseTerms = @("insider", "insiders", "preview", "beta", "canary", "nightly", "dev")
    $queryMentionsPreRelease = $preReleaseTerms | Where-Object { $q -like "*$_*" }
    if (-not $queryMentionsPreRelease) {
        $isPreRelease = $preReleaseTerms | Where-Object { $id -like "*$_*" -or $name -like "*$_*" }
        if ($isPreRelease) { $score = [Math]::Max(0, $score - 30) }
    }

    return $score
}


function Get-BestMatch {
    param(
        [string]$Query,
        [PSCustomObject[]]$Packages
    )

    if (-not $Packages -or $Packages.Count -eq 0) { return $null }

    $scored = $Packages | ForEach-Object {
        [PSCustomObject]@{
            Package = $_
            Score   = Get-PackageScore -Query $Query -Package $_
        }
    } | Sort-Object Score -Descending

    $best = $scored | Select-Object -First 1

    # Only surface a result when confidence is reasonable
    if ($best.Score -ge 40) { return $best.Package }

    return $null
}
