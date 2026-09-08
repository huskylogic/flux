# Get-BestMatch.ps1
# Fuzzy-matches a search query against winget search results to pick the
# single most likely intended package for `flux install` when no alias
# exists and -Exact wasn't specified.

function Get-NormalizedQuery {
    param([string]$Text)
    if (-not $Text) { return "" }
    $t = $Text.ToLower()
    $t = $t -replace '[^a-z0-9\s]', ' '
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}


function Get-LevenshteinDistance {
    param([string]$A, [string]$B)

    $lenA = $A.Length
    $lenB = $B.Length
    if ($lenA -eq 0) { return $lenB }
    if ($lenB -eq 0) { return $lenA }

    # Jagged array (array of arrays) rather than a true multi-dimensional
    # array -- PowerShell's parser chokes on comma-indexed access like
    # $d[$i - 1, $j] once an arithmetic expression is involved. Simple
    # chained indexing ($d[$i][$j]) avoids that entirely.
    $d = New-Object 'object[]' ($lenA + 1)
    for ($i = 0; $i -le $lenA; $i++) {
        $d[$i] = New-Object 'int[]' ($lenB + 1)
    }
    for ($i = 0; $i -le $lenA; $i++) { $d[$i][0] = $i }
    for ($j = 0; $j -le $lenB; $j++) { $d[0][$j] = $j }

    for ($i = 1; $i -le $lenA; $i++) {
        for ($j = 1; $j -le $lenB; $j++) {
            $cost = if ($A[$i - 1] -eq $B[$j - 1]) { 0 } else { 1 }
            $deletion     = $d[$i - 1][$j] + 1
            $insertion    = $d[$i][$j - 1] + 1
            $substitution = $d[$i - 1][$j - 1] + $cost
            $d[$i][$j] = [Math]::Min([Math]::Min($deletion, $insertion), $substitution)
        }
    }

    return $d[$lenA][$lenB]
}


function Get-PackageScore {
    <#
    .SYNOPSIS
        Scores how well a winget search result matches the user's query,
        on a 0-100 scale. Used both to rank fuzzy-install candidates and to
        display scores via `flux install <query> -ShowScores`.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter(Mandatory)]
        $Package
    )

    $q  = Get-NormalizedQuery $Query
    $n  = Get-NormalizedQuery $Package.Name
    $id = Get-NormalizedQuery $Package.Id

    if (-not $q) { return 0 }

    # Exact match on name or Id wins outright
    if ($n -and $n -eq $q) { return 100 }
    if ($id -and $id -eq $q) { return 100 }

    # Id segment match -- e.g. query "chrome" vs Id "Google.Chrome"
    if ($Package.Id) {
        $idParts = $Package.Id -split '\.'
        foreach ($part in $idParts) {
            if ((Get-NormalizedQuery $part) -eq $q) { return 95 }
        }
    }

    $score = 0

    if ($n) {
        if ($n.StartsWith($q)) {
            $score = [Math]::Max($score, 90 - [Math]::Min(20, $n.Length - $q.Length))
        }
        elseif ($n.Contains($q)) {
            $score = [Math]::Max($score, 75 - [Math]::Min(20, $n.Length - $q.Length))
        }

        # Word overlap -- catches reordering / extra words ("Desktop", "for Windows")
        $qWords = $q -split ' ' | Where-Object { $_.Length -gt 1 }
        $nWords = $n -split ' ' | Where-Object { $_.Length -gt 1 }
        if ($qWords.Count -gt 0 -and $nWords.Count -gt 0) {
            $common  = $qWords | Where-Object { $nWords -contains $_ }
            $overlap = $common.Count / [Math]::Max($qWords.Count, $nWords.Count)
            $score   = [Math]::Max($score, [Math]::Round($overlap * 70))
        }

        # Edit-distance similarity as a lower-weighted fallback signal --
        # catches typos ("crome" vs "chrome") that word-overlap misses
        $maxLen = [Math]::Max($q.Length, $n.Length)
        if ($maxLen -gt 0) {
            $dist       = Get-LevenshteinDistance -A $q -B $n
            $similarity = (1 - ($dist / $maxLen)) * 60
            $score      = [Math]::Max($score, [Math]::Round($similarity))
        }

        # Also check the query against each individual word in the name.
        # A whole-string comparison against "google chrome" swamps a typo
        # like "crome" with the unrelated "google " prefix; comparing
        # word-by-word catches it against "chrome" directly.
        $bestWordSim = 0
        foreach ($word in ($n -split ' ')) {
            if (-not $word) { continue }
            $wordMaxLen = [Math]::Max($q.Length, $word.Length)
            if ($wordMaxLen -eq 0) { continue }
            $wordDist = Get-LevenshteinDistance -A $q -B $word
            $wordSim  = (1 - ($wordDist / $wordMaxLen)) * 65
            $bestWordSim = [Math]::Max($bestWordSim, $wordSim)
        }
        $score = [Math]::Max($score, [Math]::Round($bestWordSim))
    }

    return [Math]::Max(0, [Math]::Min(100, [int]$score))
}


function Get-BestMatch {
    <#
    .SYNOPSIS
        Picks the single best-matching package from a set of winget search
        results for a given query. Returns $null if nothing scores high
        enough to be a confident match, so the caller falls back to
        suggesting `flux search` rather than installing the wrong thing.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter(Mandatory)]
        [array]$Packages
    )

    if (-not $Packages -or $Packages.Count -eq 0) { return $null }

    $scored = $Packages | ForEach-Object {
        [PSCustomObject]@{
            Package = $_
            Score   = Get-PackageScore -Query $Query -Package $_
        }
    }

    $best = $scored | Sort-Object Score -Descending | Select-Object -First 1

    # Below this confidence, don't auto-pick -- let the user see search results instead
    $minConfidence = 40
    if (-not $best -or $best.Score -lt $minConfidence) { return $null }

    return $best.Package
}
