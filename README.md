# Flux

A smarter winget wrapper for Windows. Install packages by name — no need to know exact IDs.

```powershell
flux install vscode
flux install chrome
flux uninstall discord
flux search python
flux list
flux aliases browser
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

## Updating Flux

On any machine where Flux is already installed, run as Administrator:

```powershell
irm https://raw.githubusercontent.com/huskylogic/flux/main/Update-Flux.ps1 | iex
```

Then reload the module in your current session:

```powershell
Remove-Module flux -ErrorAction SilentlyContinue
Import-Module "C:\ProgramData\Flux\flux.psd1"
```

> Note: `flux-aliases.csv` is never overwritten during updates so your custom aliases are always preserved.

---

## RMM Deployment

Use this as your RMM script. Installs Flux system-wide to `C:\ProgramData\Flux`
and configures it to auto-load for all users.

```powershell
irm https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1 | iex
```

### RMM Onboarding Script Example

```powershell
# Install Flux then deploy your standard software stack
irm https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1 | iex

Import-Module "C:\ProgramData\Flux\flux.psd1"

flux install chrome      -Silent
flux install 7zip        -Silent
flux install vscode      -Silent
flux install git         -Silent
flux install notepad++   -Silent
```

---

## Usage

```powershell
flux install   [package]     # Install by alias or fuzzy name
flux uninstall [package]     # Uninstall by alias or fuzzy name
flux search    [package]     # Search winget and display results
flux list      [filter]      # List installed packages
flux aliases   [filter]      # Browse available aliases
```

### Commands

| Command | Description |
|---------|-------------|
| `flux install [package]` | Install a package. Checks aliases first, falls back to fuzzy search |
| `flux uninstall [package]` | Uninstall a package. Checks aliases first, falls back to fuzzy match against installed list |
| `flux search [package]` | Search winget and display matching results |
| `flux list [filter]` | List all installed packages, optionally filtered |
| `flux aliases [filter]` | Browse all available aliases, optionally filtered by name or package ID |

### Flags

| Flag | Description |
|------|-------------|
| `-Yes` / `-y` | Skip confirmation prompts (fuzzy matches only) |
| `-Exact` / `-e` | Use exact package ID, skip fuzzy matching (install only) |
| `-Silent` / `-s` | Suppress winget output (install only, good for RMM) |
| `-ShowScores` / `-scores` | Show fuzzy match debug scores (install only) |
| `-Limit` / `-l [n]` | Max results to show (search only) |

### Examples

```powershell
# Install by alias - no prompts, goes straight to install
flux install vscode
flux install chrome
flux install 7zip

# Not sure what's available? Browse aliases
flux aliases
flux aliases browser
flux aliases remote
flux aliases office

# Search winget directly
flux search python

# See what's installed
flux list
flux list adobe

# Uninstall
flux uninstall discord

# RMM-friendly silent install
flux install vscode -Silent
```

---

## Adding Custom Aliases

Edit `C:\ProgramData\Flux\flux-aliases.csv` and add a row:

```csv
Alias,PackageId
myapp,Publisher.AppName
```

Lines starting with `#` are treated as section comments. No reload needed — changes take effect immediately.

To find a package ID you don't know:

```powershell
flux search myapp
```

Then copy the ID from the results and add it to the CSV.

---

## Project Structure

```
flux/
├── flux.psd1                    # Module manifest
├── flux.psm1                    # Entry point and dispatcher
├── flux-aliases.csv             # Alias -> PackageId mappings (458 built-in)
├── Install-Flux.ps1             # System-wide installer
├── Update-Flux.ps1              # Updater (preserves aliases)
├── Write-FluxOutput.ps1         # Shared output helpers
├── Invoke-Winget.ps1            # winget interface and output parser
├── Get-BestMatch.ps1            # Fuzzy matching engine
├── Install-FluxPackage.ps1      # flux install
├── Search-FluxPackage.ps1       # flux search
├── Uninstall-FluxPackage.ps1    # flux uninstall
├── Get-FluxPackage.ps1          # flux list
└── Get-FluxAliases.ps1          # flux aliases
```

---

## How It Works

**Alias lookup** — when you run `flux install vscode`, Flux first checks `flux-aliases.csv` for an exact match. If found it installs immediately with no searching or prompting.

**Fuzzy matching** — if no alias exists, Flux searches winget and scores each result using a combination of exact matching, word boundary matching, substring matching, and Levenshtein distance. Pre-release versions (Insiders, Preview, Beta, Canary) are penalized unless your query mentions them explicitly.

**Uninstall** — works the same way. Alias lookup first, then fuzzy match against your installed packages list.

---

## Setting Up Your GitHub Repo

1. Create a new **public** repo at github.com named `flux`
2. Upload all files from this project including the `.github/workflows/release.yml` folder structure
3. To create a release: `git tag v1.0.0 && git push --tags`
   - GitHub Actions will automatically build and attach a zip to the release

---

## License

MIT
