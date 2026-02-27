# Get-FluxAliases.ps1

function Get-FluxAliases {
    param(
        [Parameter(Position = 0)]
        [string]$Filter
    )

    # Load built-in aliases by calling Get-FluxAlias internals
    # We replicate the table here for display purposes
    $aliasFile = Join-Path $PSScriptRoot "flux-aliases.csv"
    $allAliases = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Load CSV aliases first (marked as custom)
    if (Test-Path $aliasFile) {
        $csvAliases = Import-Csv $aliasFile | Where-Object { $_.Alias -notmatch "^#" -and $_.Alias -ne "" }
        foreach ($a in $csvAliases) {
            $allAliases.Add([PSCustomObject]@{ Alias = $a.Alias; PackageId = $a.PackageId; Source = "csv" })
        }
    }

    # Load built-in aliases (skip any already defined in CSV)
    $csvKeys = $allAliases | ForEach-Object { $_.Alias.ToLower() }
    $tempId  = Get-FluxAlias -Query "____not_a_real_package____"  # warm up function scope

    # Re-invoke to get the hashtable - we parse Get-FluxAlias's output indirectly
    # by reading the source file directly for display
    $selfPath = Join-Path $PSScriptRoot "Get-FluxAlias.ps1"
    $builtInAliases = @{}
    if (Test-Path $selfPath) {
        $content = Get-Content $selfPath -Raw
        $matches  = [regex]::Matches($content, '"([^"]+)"\s*=\s*"([^"]+)"')
        foreach ($m in $matches) {
            $alias = $m.Groups[1].Value
            $pkgId = $m.Groups[2].Value
            if ($alias -notin $csvKeys) {
                $allAliases.Add([PSCustomObject]@{ Alias = $alias; PackageId = $pkgId; Source = "built-in" })
            }
        }
    }

    $display = $allAliases | Sort-Object Alias

    if ($Filter) {
        $display = $display | Where-Object {
            $_.Alias -like "*$Filter*" -or $_.PackageId -like "*$Filter*"
        }
    }

    if (-not $display -or @($display).Count -eq 0) {
        Write-Host ""
        Write-Host "  No aliases found$(if ($Filter) { " matching '$Filter'" })." -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    Write-Host ""
    if ($Filter) {
        Write-Host "  Aliases matching '$Filter':" -ForegroundColor Cyan
    } else {
        Write-Host "  All available aliases:" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host ("  {0,-25} {1,-45} {2}" -f "ALIAS", "PACKAGE ID", "SOURCE") -ForegroundColor DarkGray
    Write-Host ("  {0,-25} {1,-45} {2}" -f "-----", "----------", "------") -ForegroundColor DarkGray

    foreach ($a in $display) {
        $color = if ($a.Source -eq "csv") { "Yellow" } else { "DarkGray" }
        Write-Host ("  {0,-25} " -f $a.Alias) -NoNewline -ForegroundColor White
        Write-Host ("{0,-45} " -f $a.PackageId) -NoNewline -ForegroundColor DarkGray
        Write-Host $a.Source -ForegroundColor $color
    }

    Write-Host ""
    Write-Host ("  {0} alias(es) found." -f @($display).Count) -ForegroundColor DarkGray
    Write-Host "  Custom aliases (csv) shown in " -NoNewline -ForegroundColor DarkGray
    Write-Host "yellow" -ForegroundColor Yellow -NoNewline
    Write-Host "." -ForegroundColor DarkGray
    Write-Host "  To install:  " -NoNewline -ForegroundColor DarkGray
    Write-Host "flux install [alias]" -ForegroundColor Cyan
    Write-Host ""
}
