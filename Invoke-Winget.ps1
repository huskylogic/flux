# Invoke-Winget.ps1
# Handles all subprocess calls to winget and parses output.

function Invoke-WingetCommand {
    param(
        [string[]]$Arguments,
        [switch]$Live
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Make sure you're on Windows 10/11 with App Installer installed."
    }

    if ($Live) {
        $process = Start-Process -FilePath "winget" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
        return $process.ExitCode
    }
    else {
        $result = & winget @Arguments 2>&1
        return $result
    }
}


function ConvertFrom-WingetTable {
    param([string[]]$Lines)

    # Clean non-printable characters from all lines
    $cleaned = $Lines | ForEach-Object { $_ -replace '[^\x20-\x7E]', '' }

    # Find the header line by looking for known column names
    $headerIndex = -1
    for ($i = 0; $i -lt $cleaned.Count; $i++) {
        if ($cleaned[$i] -match 'Name\s+Id\s+Version') {
            $headerIndex = $i
            break
        }
    }

    if ($headerIndex -lt 0) { return @() }

    $headerLine = $cleaned[$headerIndex]

    # Find column start positions by locating the header words
    $colNames  = @("Name", "Id", "Version", "Match", "Source", "Available")
    $colStarts = @{}
    $colOrder  = @()

    foreach ($col in $colNames) {
        $idx = $headerLine.IndexOf($col)
        if ($idx -ge 0) {
            $colStarts[$col] = $idx
            $colOrder += $col
        }
    }

    $colOrder = $colOrder | Sort-Object { $colStarts[$_] }

    if ($colOrder.Count -eq 0) { return @() }

    # Skip separator line
    $dataStart = $headerIndex + 1
    if ($dataStart -lt $cleaned.Count -and $cleaned[$dataStart] -match '^[\s\-]+$') {
        $dataStart++
    }

    $records = @()
    for ($i = $dataStart; $i -lt $cleaned.Count; $i++) {
        $line = $cleaned[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^\s*%') { continue }

        $record = @{}

        for ($j = 0; $j -lt $colOrder.Count; $j++) {
            $col   = $colOrder[$j]
            $start = $colStarts[$col]

            if ($start -ge $line.Length) {
                $record[$col] = ""
                continue
            }

            if ($j -lt $colOrder.Count - 1) {
                $nextStart = $colStarts[$colOrder[$j + 1]]
                $len       = [Math]::Min($nextStart - $start, $line.Length - $start)
                $record[$col] = $line.Substring($start, $len).Trim()
            }
            else {
                $record[$col] = $line.Substring($start).Trim()
            }
        }

        if ($record["Id"] -or $record["Name"]) {
            $records += [PSCustomObject]@{
                Name    = $record["Name"]
                Id      = $record["Id"]
                Version = $record["Version"]
                Source  = if ($record["Source"]) { $record["Source"] } else { "winget" }
            }
        }
    }

    return $records
}


function Search-WingetPackages {
    param([string]$Query)
    $raw = Invoke-WingetCommand -Arguments @("search", $Query, "--accept-source-agreements")
    return ConvertFrom-WingetTable -Lines $raw
}


function Get-WingetInstalled {
    $raw = Invoke-WingetCommand -Arguments @("list", "--accept-source-agreements")
    return ConvertFrom-WingetTable -Lines $raw
}


function Install-WingetPackage {
    param(
        [string]$PackageId,
        [switch]$Silent
    )
    $args = @("install", "--id", $PackageId, "--exact", "--accept-package-agreements", "--accept-source-agreements")
    if ($Silent) { $args += "--silent" }
    $code = Invoke-WingetCommand -Live -Arguments $args
    return $code -eq 0
}


function Uninstall-WingetPackage {
    param([string]$PackageId)
    # Try normal uninstall first, then fall back to --all-versions if multiple versions found
    $code = Invoke-WingetCommand -Live -Arguments @("uninstall", "--id", $PackageId, "--exact")
    if ($code -ne 0) {
        Write-Host ""
        Write-Host "  Retrying with --all-versions..." -ForegroundColor DarkGray
        $code = Invoke-WingetCommand -Live -Arguments @("uninstall", "--id", $PackageId, "--exact", "--all-versions")
    }
    return $code -eq 0
}
