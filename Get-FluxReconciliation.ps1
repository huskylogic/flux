# Get-FluxReconciliation.ps1
# Closes the visibility blind spot: winget only knows what winget knows.
# This enumerates installed software directly from the registry (the
# ground truth Windows itself uses for Add/Remove Programs) and diffs it
# against what `winget list` reports, so software that's silently invisible
# to Flux gets surfaced instead of missed.
#
# Note: this reads the registry directly rather than reusing Get-BestMatch's
# fuzzy engine, since name-matching here only needs to answer "is this the
# same app, roughly" -- not rank a list of search candidates.

function Get-NormalizedSoftwareName {
    param([string]$Name)

    if (-not $Name) { return "" }

    $n = $Name.ToLower()
    $n = $n -replace '[\(\[].*?[\)\]]', ' '                          # (64-bit), [x64], etc.
    $n = $n -replace '[™®©]', ''
    $n = $n -replace '\b(x64|x86|64-bit|32-bit|64bit|32bit)\b', ' '
    $n = $n -replace '[^a-z0-9\s]', ' '                               # strip punctuation
    $n = $n -replace '\s+', ' '
    return $n.Trim()
}


function Test-SoftwareNameMatch {
    param(
        [string]$RegistryName,
        [string]$WingetName
    )

    $a = Get-NormalizedSoftwareName $RegistryName
    $b = Get-NormalizedSoftwareName $WingetName

    if (-not $a -or -not $b) { return $false }
    if ($a -eq $b) { return $true }

    # Substring containment -- guard against short strings causing false positives
    if ($a.Length -ge 4 -and $b.Length -ge 4) {
        if ($b.Contains($a) -or $a.Contains($b)) { return $true }
    }

    # Word-overlap fallback (catches reordering / extra words like "Desktop", "Client")
    $aWords = $a -split ' ' | Where-Object { $_.Length -gt 1 }
    $bWords = $b -split ' ' | Where-Object { $_.Length -gt 1 }
    if ($aWords.Count -eq 0 -or $bWords.Count -eq 0) { return $false }

    $common  = $aWords | Where-Object { $bWords -contains $_ }
    $overlap = $common.Count / [Math]::Min($aWords.Count, $bWords.Count)
    return $overlap -ge 0.6
}


function Get-InstalledSoftwareFromRegistry {
    [CmdletBinding()]
    param()

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    $roots = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"; Scope = "Machine (64-bit)" }
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"; Scope = "Machine (32-bit)" }
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"; Scope = "Current User" }
    )

    # Pick up other logged-on users' hives too -- this is also the same blind
    # spot that hits Flux running as SYSTEM (Phase 5): per-user installs for
    # anyone other than the interactively logged-in user are easy to miss.
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        try { New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction Stop | Out-Null } catch {}
    }
    if (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue) {
        $userHives = Get-ChildItem "HKU:\" -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^S-1-5-21-\d+-\d+-\d+-\d+$' }
        foreach ($hive in $userHives) {
            $roots += @{
                Path  = "HKU:\$($hive.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
                Scope = "User ($($hive.PSChildName))"
            }
        }
    }

    foreach ($root in $roots) {
        $entries = Get-ItemProperty -Path $root.Path -ErrorAction SilentlyContinue
        foreach ($entry in $entries) {
            if (-not $entry.DisplayName)   { continue }
            if ($entry.SystemComponent -eq 1) { continue }
            if ($entry.ParentKeyName)      { continue }  # sub-component of another product
            if ($entry.ReleaseType -in @("Hotfix", "Update", "ServicePack", "Security Update")) { continue }
            if ($entry.DisplayName -match '^(KB\d{6,}|Security Update|Update for|Hotfix|Service Pack)') { continue }

            $results.Add([PSCustomObject]@{
                DisplayName = $entry.DisplayName.Trim()
                Version     = if ($entry.DisplayVersion) { $entry.DisplayVersion } else { "" }
                Publisher   = if ($entry.Publisher) { $entry.Publisher } else { "" }
                Scope       = $root.Scope
            })
        }
    }

    return $results | Sort-Object DisplayName, Scope -Unique
}


function Get-FluxReconciliation {
    <#
    .SYNOPSIS
        Compares software actually installed on this machine against what
        winget/Flux can see, and flags the delta -- the real risk exposure
        across the fleet that a winget-only view silently misses.
    .EXAMPLE
        flux reconcile
    .EXAMPLE
        flux reconcile -All
    .EXAMPLE
        flux reconcile -ExportCsv C:\ProgramData\Flux\reconcile-report.csv
    .EXAMPLE
        flux reconcile -Json
    #>
    [CmdletBinding()]
    param(
        [switch]$All,           # show managed + unmanaged, not just the blind spot
        [string]$Filter = "",
        [string]$ExportCsv,
        [switch]$Json
    )

    if (-not $Json) {
        Write-FluxHeader "Reconciling installed software against winget visibility..."
        Write-Host ""
    }

    $registryApps = Get-InstalledSoftwareFromRegistry
    $wingetApps   = Get-WingetInstalled

    if (-not $registryApps -or $registryApps.Count -eq 0) {
        Write-FluxError "Could not enumerate installed software from the registry."
        return
    }

    $report = foreach ($app in $registryApps) {
        $matched = $false
        foreach ($w in $wingetApps) {
            if (Test-SoftwareNameMatch -RegistryName $app.DisplayName -WingetName $w.Name) {
                $matched = $true
                break
            }
        }
        [PSCustomObject]@{
            DisplayName = $app.DisplayName
            Version     = $app.Version
            Publisher   = $app.Publisher
            Scope       = $app.Scope
            Status      = if ($matched) { "Managed" } else { "Unmanaged" }
        }
    }

    if ($Filter) {
        $report = $report | Where-Object {
            $_.DisplayName -like "*$Filter*" -or $_.Publisher -like "*$Filter*"
        }
    }

    $unmanaged = @($report | Where-Object { $_.Status -eq "Unmanaged" })
    $managed   = @($report | Where-Object { $_.Status -eq "Managed" })

    if ($ExportCsv) {
        try {
            $report | Sort-Object Status, DisplayName | Export-Csv -Path $ExportCsv -NoTypeInformation -Force
            if (-not $Json) {
                Write-Host "  Exported full report to $ExportCsv" -ForegroundColor DarkGray
                Write-Host ""
            }
        }
        catch {
            Write-FluxError "Could not write export to '$ExportCsv': $_"
        }
    }

    if ($Json) {
        $report | Sort-Object Status, DisplayName | ConvertTo-Json -Depth 3
        return
    }

    $display = if ($All) { $report } else { $unmanaged }

    if (@($display).Count -eq 0) {
        if ($All) {
            Write-FluxError "No installed software found."
        }
        else {
            Write-FluxSuccess "No blind spot found -- everything installed appears visible to winget."
        }
        return
    }

    $display = $display | Sort-Object Status, DisplayName

    $nameWidth  = [Math]::Min([Math]::Max(($display | ForEach-Object { $_.DisplayName.Length } | Measure-Object -Maximum).Maximum, 4) + 2, 42)
    $pubWidth   = 22
    $scopeWidth = 20

    $header = "{0,-$nameWidth} {1,-$pubWidth} {2,-$scopeWidth} {3}" -f "NAME", "PUBLISHER", "SCOPE", "STATUS"
    $sep    = "{0,-$nameWidth} {1,-$pubWidth} {2,-$scopeWidth} {3}" -f ("-" * ($nameWidth - 1)), ("-" * ($pubWidth - 1)), ("-" * ($scopeWidth - 1)), "------"

    Write-Host "  $header" -ForegroundColor Cyan
    Write-Host "  $sep"    -ForegroundColor DarkGray

    foreach ($row in $display) {
        $name = if ($row.DisplayName.Length -gt $nameWidth - 2) { $row.DisplayName.Substring(0, $nameWidth - 5) + "..." } else { $row.DisplayName }
        $pub  = if ($row.Publisher.Length -gt $pubWidth - 2)   { $row.Publisher.Substring(0, $pubWidth - 5) + "..." }   else { $row.Publisher }
        $statusColor = if ($row.Status -eq "Unmanaged") { "Yellow" } else { "DarkGray" }

        Write-Host ("  {0,-$nameWidth}" -f $name)      -NoNewline -ForegroundColor White
        Write-Host ("{0,-$pubWidth}"    -f $pub)       -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-$scopeWidth}"  -f $row.Scope) -NoNewline -ForegroundColor DarkGray
        Write-Host $row.Status -ForegroundColor $statusColor
    }

    Write-Host ""
    Write-Host "  $($registryApps.Count) installed, $($managed.Count) visible to winget, " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($unmanaged.Count) unmanaged" -ForegroundColor $(if ($unmanaged.Count -gt 0) { "Yellow" } else { "DarkGray" })
    Write-Host ""

    if (-not $All -and $unmanaged.Count -gt 0) {
        Write-Host "  Run " -NoNewline -ForegroundColor DarkGray
        Write-Host "flux reconcile -All" -ForegroundColor Cyan -NoNewline
        Write-Host " to see the full picture, including managed software." -ForegroundColor DarkGray
        Write-Host ""
    }
}
