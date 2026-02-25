# Flux

A smarter winget wrapper for Windows. Install packages by name — no need to know exact IDs.

```powershell
flux install vscode
flux install chrome
flux uninstall discord
flux search python
flux list
```

---

## Requirements

- Windows 10/11 with [winget](https://aka.ms/winget) installed
- PowerShell 5.1 or later (built into Windows)
- Must run as Administrator for install/uninstall

---

## Quick Install (Techs & New Machines)

Open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1 | iex
```

That's it. Open a new PowerShell window and `flux` is ready to use.

---

## RMM Deployment (Gorelo / Action1)

Use this as your RMM script. It installs Flux system-wide to `C:\ProgramData\Flux`
and configures it to auto-load for all users.

```powershell
# Deploy Flux via RMM
$installScript = "https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1"
Invoke-RestMethod -Uri $installScript | Invoke-Expression
```

Or download and run locally on the endpoint:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1" `
    -OutFile "$env:TEMP\Install-Flux.ps1" -UseBasicParsing
& "$env:TEMP\Install-Flux.ps1"
```

### RMM Onboarding Script Example

```powershell
# Install Flux then use it to deploy your standard software stack
irm https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1 | iex

Import-Module "C:\ProgramData\Flux\flux.psd1"

flux install chrome    -Silent
flux install 7zip      -Silent
flux install vscode    -Silent
flux install git       -Silent
flux install notepad++ -Silent
```

---

## Updating Flux

On any machine where Flux is installed, run as Administrator:

```powershell
irm https://raw.githubusercontent.com/huskylogic/flux/main/Update-Flux.ps1 | iex
```

Note: `flux-aliases.csv` is never overwritten during updates so your custom aliases are preserved.

---

## Usage

```powershell
flux install   [package]     # Install by alias or fuzzy name
flux uninstall [package]     # Uninstall by alias or fuzzy name
flux search    [package]     # Search winget and display results
flux list      [filter]      # List installed packages
```

### Flags

| Flag | Description |
|------|-------------|
| `-Yes` / `-y` | Skip confirmation (fuzzy matches only) |
| `-Exact` / `-e` | Use exact package ID, skip fuzzy matching |
| `-Silent` / `-s` | Suppress winget output (good for RMM) |
| `-ShowScores` / `-scores` | Show fuzzy match debug scores |
| `-Limit` / `-l [n]` | Max results for search |

---

## Adding Custom Aliases

Edit `C:\ProgramData\Flux\flux-aliases.csv` and add a row:

```csv
Alias,PackageId
myapp,Publisher.AppName
```

Lines starting with `#` are treated as comments. No reload needed — changes take effect immediately.

---

## Project Structure

```
flux/
├── flux.psd1                    # Module manifest
├── flux.psm1                    # Entry point and dispatcher
├── flux-aliases.csv             # Alias -> PackageId mappings
├── Install-Flux.ps1             # System-wide installer
├── Update-Flux.ps1              # Updater
├── Write-FluxOutput.ps1         # Shared output helpers
├── Invoke-Winget.ps1            # winget interface and parser
├── Get-BestMatch.ps1            # Fuzzy matching engine
├── Install-FluxPackage.ps1      # flux install
├── Search-FluxPackage.ps1       # flux search
├── Uninstall-FluxPackage.ps1    # flux uninstall
└── Get-FluxPackage.ps1          # flux list
```

---

## Setting Up Your GitHub Repo

1. Create a new repo at github.com named `flux`
2. Upload all the files from this project
3. Replace `huskylogic` in `Install-Flux.ps1` and `Update-Flux.ps1` with your GitHub username
4. To create a release: tag a commit with `git tag v1.0.0 && git push --tags`
   - GitHub Actions will automatically build and attach a zip to the release

---

## License

MIT
