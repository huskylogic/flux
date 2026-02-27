# ⚡ Flux

> *"Roads? Where we're going, we don't need roads."*
> — Dr. Emmett Brown

Named after the **Flux Capacitor** — the thing that makes time travel possible. Flux is the thing that makes Windows software installation possible. Without it, nothing works. With it, you're doing 88mph.

Flux is a smarter winget wrapper for Windows. Install packages by name — no need to memorize exact IDs, no more copy-pasting from websites, no more wasted time.

```powershell
flux install vscode
flux install chrome
flux uninstall discord
flux search python
flux list
flux aliases browser
```

---

## ⚡ Requirements

- Windows 10/11 with [winget](https://aka.ms/winget) installed
- PowerShell 5.1 or later (built into Windows)
- Must run as Administrator for install/uninstall
- 1.21 gigawatts of power *(optional)*

---

## 🚗 Quick Install

*"If you're gonna build a time machine into a car, why not do it with some style?"*

Open PowerShell **as Administrator** and hit 88mph:

```powershell
irm https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1 | iex
```

Open a new PowerShell window and `flux` is ready. You're already in the future.

---

## 🔧 Updating Flux

*"Your future is whatever you make it — so make it a good one."*

On any machine where Flux is installed, run as Administrator:

```powershell
irm https://raw.githubusercontent.com/huskylogic/flux/main/Update-Flux.ps1 | iex
```

Then reload in your current session:

```powershell
Remove-Module flux -ErrorAction SilentlyContinue
Import-Module "C:\ProgramData\Flux\flux.psd1"
```

> `flux-aliases.csv` is never overwritten during updates. Your custom aliases are safe — like a photo in your wallet that hasn't faded yet.

---

## 🖥️ RMM Deployment (Gorelo / Action1)

*"Think, McFly. Think."*

Stop clicking through installers one at a time. Deploy Flux once, then script everything.

```powershell
irm https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1 | iex
```

### Onboarding Script Example

```powershell
# Great Scott! A full software stack in seconds.
irm https://raw.githubusercontent.com/huskylogic/flux/main/Install-Flux.ps1 | iex

Import-Module "C:\ProgramData\Flux\flux.psd1"

flux install chrome      -Silent
flux install 7zip        -Silent
flux install vscode      -Silent
flux install git         -Silent
flux install notepad++   -Silent
```

---

## ⚙️ Usage

```powershell
flux install   [package(s)]  # Install one or more packages
flux uninstall [package]     # Uninstall by alias or fuzzy name
flux search    [package]     # Search winget and display results
flux list      [filter]      # List installed packages
flux aliases   [filter]      # Browse available aliases
flux upgrade   [package]     # Upgrade one or all installed packages
flux update                  # Update the Flux tool itself from GitHub
```

### Commands

| Command | Description |
|---------|-------------|
| `flux install [package(s)]` | Checks aliases first, falls back to fuzzy search. Supports comma-separated list |
| `flux uninstall [package]` | Checks aliases first, falls back to fuzzy match against installed list |
| `flux search [package]` | Search winget and display matching results |
| `flux list [filter]` | List all installed packages, optionally filtered |
| `flux aliases [filter]` | Browse all available aliases, optionally filtered |
| `flux upgrade [package]` | Upgrade one package, or all installed packages if none specified |
| `flux update` | Update the Flux tool itself from GitHub. Preserves your custom aliases |

### Flags

| Flag | Description |
|------|-------------|
| `-Yes` / `-y` | Skip confirmation prompts (fuzzy matches only) |
| `-Exact` / `-e` | Use exact package ID, skip fuzzy matching (install only) |
| `-Silent` / `-s` | Suppress winget output — great for RMM |
| `-ShowScores` / `-scores` | Show fuzzy match debug scores (install only) |
| `-Limit` / `-l [n]` | Max results to show (search only) |

### Examples

```powershell
# Alias match — no prompts, straight to install. 88mph.
flux install vscode
flux install chrome
flux install 7zip

# Not sure what's available? Check the almanac.
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

# Silent install for RMM scripts
flux install chrome, vscode, 7zip, notepad++ -Silent

# Update Flux itself
flux update
```

---

## 📋 The Almanac — Adding Custom Aliases

*"I could use a nice vacation... too bad the Grays Sports Almanac is taken."*

Flux ships with 458 built-in aliases. Can't find what you need? Add your own to `C:\ProgramData\Flux\flux-aliases.csv`:

```csv
Alias,PackageId
myapp,Publisher.AppName
```

Lines starting with `#` are section comments. No reload needed — changes take effect immediately.

Don't know the package ID? Let Flux find it:

```powershell
flux search myapp
```

Copy the ID from the results and add it to the CSV. Future you will thank you.

---

## 🔬 How It Works

**The Flux Capacitor (Alias Lookup)** — when you run `flux install vscode`, Flux first checks `flux-aliases.csv` for an exact match. If found, it installs immediately. No searching, no prompting, no waiting. This is the part that makes it all work.

**Fuzzy Matching (The Time Circuits)** — if no alias exists, Flux searches winget and scores every result using exact matching, word boundary matching, substring matching, and Levenshtein distance. Pre-release versions (Insiders, Preview, Beta, Canary) are penalized unless your query mentions them explicitly.

**Uninstall** — same logic. Alias lookup first, then fuzzy match against your installed packages.

---

## 📁 Project Structure

```
flux/
├── flux.psd1                    # Module manifest
├── flux.psm1                    # Entry point and dispatcher
├── flux-aliases.csv             # 458 built-in aliases (the almanac)
├── Install-Flux.ps1             # System-wide installer
├── Update-Flux.ps1              # Updater (preserves your aliases)
├── Write-FluxOutput.ps1         # Shared output helpers
├── Invoke-Winget.ps1            # winget interface and output parser
├── Get-BestMatch.ps1            # Fuzzy matching engine
├── Install-FluxPackage.ps1      # flux install
├── Search-FluxPackage.ps1       # flux search
├── Uninstall-FluxPackage.ps1    # flux uninstall
├── Get-FluxPackage.ps1          # flux list
├── Get-FluxAliases.ps1          # flux aliases
└── Update-FluxSelf.ps1          # flux update
```

---

## 🚀 Setting Up Your GitHub Repo

1. Create a new **public** repo at github.com named `flux`
2. Upload all files including the `.github/workflows/release.yml` folder structure
3. Tag a release: `git tag v1.0.0 && git push --tags`
   - GitHub Actions will automatically build and attach a zip to the release

---

## 💡 Why "Flux"?

Named after the **Flux Capacitor** from *Back to the Future* — the fictional device that makes time travel possible. The idea being that just like the Flux Capacitor is what makes the DeLorean work, Flux is what makes Windows software deployment actually work the way it should.

Built by **Husky Logic** — Expert IT Solutions, Explained Simply.

---

## License

MIT

*"Your future hasn't been written yet. No one's has. Your future is whatever you make it. So make it a good one."*
