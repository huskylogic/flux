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


function Get-FriendlyPublisherName {
    <#
    .SYNOPSIS
        Extracts a human-readable publisher name from an Appx package's raw
        X.500 distinguished-name string (e.g. 'CN="Slack Technologies, Inc.",
        O=Slack Technologies...' or, for many packages, just 'CN=<a GUID>'
        with no organization name at all).
    #>
    param([string]$RawPublisher)

    if (-not $RawPublisher) { return "" }

    if ($RawPublisher -match 'O="([^"]+)"') { return $matches[1] }
    if ($RawPublisher -match 'O=([^,]+)')   { return $matches[1].Trim() }
    if ($RawPublisher -match 'CN="([^"]+)"') { return $matches[1] }
    if ($RawPublisher -match 'CN=([^,]+)') {
        $cn = $matches[1].Trim()
        # Many packages sign with a bare GUID and no real org name -- not useful to show
        if ($cn -match '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$') { return "" }
        return $cn
    }
    return ""
}


# Known in-box / OS-bundled package prefixes and patterns to exclude from
# the Store/MSIX visibility list. Windows ships a long, ever-changing tail
# of internal shell/OS-infrastructure packages (ShellExperienceHost,
# CloudExperienceHost, and oddly-named ones that differ by build), so rather
# than list each one individually -- a losing game across different Windows
# versions on 59 endpoints -- this matches on the prefixes that reliably
# mean "OS internals, not a real app". None of the software this list
# exists to catch (Slack, Claude, Teams, Outlook, Terminal, WSL, etc.)
# matches these patterns.
$script:FluxAppxDenylistPatterns = @(
    "Microsoft.Windows.*"      # Windows.<Component> shell/OOBE internals
    "MicrosoftWindows.*"       # MicrosoftWindows.Client.*, numbered/codenamed internals
    "Windows.*"                # Windows.CBSPreview, Windows.PrintDialog, etc.
    "windows.*"                # lowercase variants (windows.immersivecontrolpanel)
)

# A shorter list of individual system-UI components that don't share one of
# the prefixes above, plus a couple of known duplicates of software already
# counted on the classic (registry) side.
$script:FluxAppxDenylist = @(
    "Microsoft.AAD.BrokerPlugin"
    "Microsoft.AccountsControl"
    "Microsoft.Advertising.Xaml"
    "Microsoft.ApplicationCompatibilityEnhancements"
    "Microsoft.AsyncTextService"
    "Microsoft.AV1VideoExtension"
    "Microsoft.AVCEncoderVideoExtension"
    "Microsoft.BingNews"
    "Microsoft.BingSearch"
    "Microsoft.BingWeather"
    "Microsoft.BioEnrollment"
    "Microsoft.CredDialogHost"
    "Microsoft.DesktopAppInstaller"
    "Microsoft.ECApp"
    "Microsoft.Edge.GameAssist"
    "Microsoft.GamingApp"
    "Microsoft.GetHelp"
    "Microsoft.HEIFImageExtension"
    "Microsoft.HEVCVideoExtension"
    "Microsoft.LockApp"
    "Microsoft.M365Companions"
    "Microsoft.MicrosoftEdge.Stable"        # duplicate of classic-managed Edge
    "Microsoft.MicrosoftEdgeDevToolsClient"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MixedReality.Portal"
    "Microsoft.MPEG2VideoExtension"
    "Microsoft.Office.ActionsServer"
    "Microsoft.OfficePushNotificationUtility"
    "Microsoft.OneDriveSync"
    "Microsoft.People"
    "Microsoft.RawImageExtension"
    "Microsoft.ScreenSketch"
    "Microsoft.SecHealthUI"
    "Microsoft.StartExperiencesApp"
    "Microsoft.StorePurchaseApp"
    "Microsoft.Todos"
    "Microsoft.VP9VideoExtensions"
    "Microsoft.Win32WebViewHost"
    "Microsoft.WebMediaExtensions"
    "Microsoft.WebpImageExtension"
    "Microsoft.WidgetsPlatformRuntime"
    "Microsoft.Whiteboard"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCalculator"
    "Microsoft.WindowsCamera"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsNotepad"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WindowsStore"
    "Microsoft.Winget.Source"
    "Microsoft.Xbox*"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.6365217CE6EB4"   # Windows Defender app
    "microsoft.windowscommunicationsapps"  # Mail and Calendar
    "MdOdrMcpFilterPackage"
    "MicrosoftCorporationII.QuickAssist"
    "MicrosoftCorporationII.WinAppRuntime*"
)


function Get-InstalledAppxApps {
    <#
    .SYNOPSIS
        Enumerates Store/MSIX-packaged apps. These never appear in the classic
        Uninstall registry keys at all -- winget-distributed desktop apps like
        Slack, Teams, and Claude are increasingly packaged this way even
        though they aren't "Store apps" in the traditional sense.

        These are reported for visibility only, not matched against winget
        and judged Managed/Unmanaged: MSIX packages don't expose a reliable
        human-readable display name (Slack shows up internally as
        "com.tinyspeck.slackdesktop"), so fuzzy-matching that against
        winget's "Slack" is unreliable enough that a bad match would produce
        false "Unmanaged" flags on software that's actually fine. Since
        winget already tracks these packages natively, that risk isn't worth
        taking just to force them into a category.
    #>
    [CmdletBinding()]
    param()

    $packages = $null
    try {
        $packages = Get-AppxPackage -AllUsers -ErrorAction Stop
    }
    catch {
        # -AllUsers requires elevation; fall back to the current user's packages only
        try { $packages = Get-AppxPackage -ErrorAction Stop } catch { $packages = @() }
    }

    $real = $packages | Where-Object {
        $pkg = $_
        if ($pkg.IsFramework -or $pkg.IsResourcePackage) { return $false }
        if ($pkg.Name -match '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$') { return $false }
        if ($script:FluxAppxDenylistPatterns | Where-Object { $pkg.Name -like $_ }) { return $false }
        if ($script:FluxAppxDenylist | Where-Object { $pkg.Name -like $_ }) { return $false }
        return $true
    }

    $results = foreach ($pkg in $real) {
        [PSCustomObject]@{
            DisplayName = $pkg.Name
            Version     = $pkg.Version
            Publisher   = Get-FriendlyPublisherName $pkg.Publisher
            Scope       = "-"
        }
    }

    # Side-by-side versions are normal for MSIX (e.g. two Slack versions during
    # an update rollout) -- collapse to the newest so it isn't double-counted.
    return $results | Group-Object DisplayName | ForEach-Object {
        $_.Group | Sort-Object { try { [version]$_.Version } catch { $_.Version } } -Descending | Select-Object -First 1
    }
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
    $appxApps     = Get-InstalledAppxApps
    $wingetApps   = Get-WingetInstalled

    if (-not $registryApps -or $registryApps.Count -eq 0) {
        Write-FluxError "Could not enumerate installed software from the registry."
        return
    }

    $classicReport = foreach ($app in $registryApps) {
        $matchedWinget = $null
        foreach ($w in $wingetApps) {
            if (Test-SoftwareNameMatch -RegistryName $app.DisplayName -WingetName $w.Name) {
                $matchedWinget = $w
                break
            }
        }
        [PSCustomObject]@{
            DisplayName = $app.DisplayName
            Version     = $app.Version
            Publisher   = $app.Publisher
            Scope       = $app.Scope
            Status      = if ($matchedWinget) { "Managed" } else { "Unmanaged" }
            WingetId    = if ($matchedWinget) { $matchedWinget.Id } else { "" }
        }
    }

    $storeReport = foreach ($app in $appxApps) {
        [PSCustomObject]@{
            DisplayName = $app.DisplayName
            Version     = $app.Version
            Publisher   = $app.Publisher
            Scope       = $app.Scope
            Status      = "Store/MSIX"
            WingetId    = ""
        }
    }

    $report = @($classicReport) + @($storeReport)

    if ($Filter) {
        $report = $report | Where-Object {
            $_.DisplayName -like "*$Filter*" -or $_.Publisher -like "*$Filter*"
        }
    }

    $unmanaged = @($report | Where-Object { $_.Status -eq "Unmanaged" })
    $managed   = @($report | Where-Object { $_.Status -eq "Managed" })
    $store     = @($report | Where-Object { $_.Status -eq "Store/MSIX" })

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

    $display = $display | Sort-Object @{Expression = {
        switch ($_.Status) { "Unmanaged" { 0 }; "Store/MSIX" { 1 }; default { 2 } }
    }}, DisplayName

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
        $statusColor = switch ($row.Status) {
            "Unmanaged"   { "Yellow" }
            "Store/MSIX"  { "Cyan" }
            default       { "DarkGray" }
        }

        Write-Host ("  {0,-$nameWidth}" -f $name)      -NoNewline -ForegroundColor White
        Write-Host ("{0,-$pubWidth}"    -f $pub)       -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-$scopeWidth}"  -f $row.Scope) -NoNewline -ForegroundColor DarkGray
        Write-Host $row.Status -ForegroundColor $statusColor
    }

    $totalTracked = $registryApps.Count + $appxApps.Count

    Write-Host ""
    Write-Host "  $totalTracked installed ($($managed.Count) managed, " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($unmanaged.Count) unmanaged" -NoNewline -ForegroundColor $(if ($unmanaged.Count -gt 0) { "Yellow" } else { "DarkGray" })
    Write-Host ", $($store.Count) Store/MSIX)" -ForegroundColor DarkGray
    Write-Host "  Note: winget list may show a higher total -- it also includes" -ForegroundColor DarkGray
    Write-Host "  runtime/framework components and OS-bundled apps not counted here." -ForegroundColor DarkGray
    Write-Host ""

    if (-not $All -and $unmanaged.Count -gt 0) {
        Write-Host "  Run " -NoNewline -ForegroundColor DarkGray
        Write-Host "flux reconcile -All" -ForegroundColor Cyan -NoNewline
        Write-Host " to see the full picture, including managed and Store/MSIX software." -ForegroundColor DarkGray
        Write-Host ""
    }
}
