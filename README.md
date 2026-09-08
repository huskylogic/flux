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
flux reconcile
flux sync
flux export
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

> `flux-aliases.csv` and `flux-packages.csv` are never overwritten during updates. Your custom aliases and manifest are safe — like a photo in your wallet that hasn't faded yet.

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
flux reconcile               # Show software winget can't see
flux sync                    # Install/upgrade to match flux-packages.csv
flux export    [-Path]       # Bootstrap flux-packages.csv from this machine
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
| `flux reconcile` | Compare installed software against what winget can see. Flags the blind spot: software on the machine that winget doesn't know about, and therefore that Flux can't patch or report on. Also tracks Store/MSIX-packaged apps (Slack, Teams, Claude, etc.) separately, since those never show up in the classic install registry |
| `flux sync` | Reads `flux-packages.csv` and installs whatever's missing, upgrades whatever's outdated. Never uninstalls anything. Also folds in `reconcile`'s unmanaged findings, so one run tells you installed / upgraded / failed / unmanaged |
| `flux export [-Path]` | Bootstraps a `flux-packages.csv` from this machine's currently winget-managed software — a starting point for building a client's manifest, not a finished one |
| `flux update` | Update the Flux tool itself from GitHub. Preserves your custom aliases and your `flux-packages.csv` |

### Flags

| Flag | Description |
|------|-------------|
| `-Yes` / `-y` | Skip confirmation prompts (fuzzy matches only) |
| `-Exact` / `-e` | Use exact package ID, skip fuzzy matching (install only) |
| `-Silent` / `-s` | Suppress winget output — great for RMM |
| `-Loud` | Show winget's own output instead of suppressing it (install/upgrade/sync) |
| `-ShowScores` / `-scores` | Show fuzzy match debug scores (install only) |
| `-Limit` / `-l [n]` | Max results to show (search only) |
| `-All` | Show managed + unmanaged + Store/MSIX, not just the blind spot (reconcile only) |
| `-Filter [text]` | Filter results by name or publisher (reconcile only) |
| `-ExportCsv [path]` | Write the full report to CSV — feeds into RMM custom fields (reconcile, sync) |
| `-Json` | Output as JSON instead of a console table (reconcile, sync) |
| `-Path [path]` | Where to write the exported manifest (export only, defaults to `flux-packages.csv`) |
| `-Force` | Overwrite an existing file without prompting (export only) |

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

# Find software winget can't see
flux reconcile
flux reconcile -All
flux reconcile -ExportCsv C:\ProgramData\Flux\reconcile-report.csv

# Bootstrap a manifest from a golden machine, then deploy it and sync
flux export -Path C:\Temp\clientA-packages.csv
flux sync
flux sync -ExportCsv C:\ProgramData\Flux\sync-report.csv

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

## 🛰️ Reconciliation — Finding the Blind Spot

*"Nobody calls me chicken."* — well, nobody calls Flux blind either, not anymore.

`flux list` only shows what winget knows about. But software gets installed outside winget all the time — a manual download, an internal tool, something IT pushed before Flux existed. That's real risk you can't see and can't patch.

```powershell
flux reconcile
```

This scans the machine directly (registry, all logged-on users, not just the current session) and compares it against winget's view. By default it only shows the blind spot — software that's genuinely unmanaged. Add `-All` to see the full picture, including software Flux already has covered and Store/MSIX-packaged apps (Slack, Teams, Claude, and similar — these install differently and get tracked separately rather than guessed at).

---

## 🧬 Sync & Manifests — Defining What Should Be There

*"Where we're going, we don't need roads"* — or manual installs, once this is set up.

`flux reconcile` tells you what's on a machine. `flux sync` tells a machine what it *should* have, and makes it so — installing anything missing, upgrading anything outdated. It never uninstalls anything; unlisted software just gets reported, not removed.

Sync reads from `flux-packages.csv`, sitting alongside `flux-aliases.csv` in the install directory. It's never touched by `flux update`, same as your aliases file.

```csv
Package,PinnedVersion
chrome,
7zip,
notepad++,
vscode,
```

Each `Package` value can be an alias or a raw winget ID — same resolution `flux install` uses. `PinnedVersion` is reserved for a future release; it's ignored for now, but the column's there so the file format won't need to change later.

Don't want to write one by hand? Set up a machine the way you want a client's fleet to look, then:

```powershell
flux export -Path C:\Temp\clientA-packages.csv
```

This bootstraps a manifest from whatever winget already recognizes as installed there. **Review and trim it** before deploying — it'll include everything winget sees, not just what you actually want templated onto every endpoint. Once it's trimmed down, push it out via your RMM as that client's `flux-packages.csv`, then run:

```powershell
flux sync
```

The report covers installed, upgraded, failed, *and* unmanaged (via reconcile) in one pass — everything you'd want out of an audit trail. Add `-ExportCsv` or `-Json` to feed it into your RMM's custom fields instead of just reading it in the console.

---

## 🔬 How It Works

**The Flux Capacitor (Alias Lookup)** — when you run `flux install vscode`, Flux first checks `flux-aliases.csv` for an exact match. If found, it installs immediately. No searching, no prompting, no waiting. This is the part that makes it all work.

**Fuzzy Matching (The Time Circuits)** — if no alias exists, Flux searches winget and scores every result using exact matching, word boundary matching, substring matching, and Levenshtein distance. Pre-release versions (Insiders, Preview, Beta, Canary) are penalized unless your query mentions them explicitly.

**Uninstall** — same logic. Alias lookup first, then fuzzy match against your installed packages.

**Reconciliation (Finding What's Missing From the Timeline)** — `flux reconcile` reads installed software straight from the registry rather than trusting winget's own view, since winget can only report on what it already knows about. Names are matched against winget's list using a lighter-weight comparison than the install fuzzy-matcher — exact match, substring, then word overlap — since the question here is just "is this roughly the same app," not "rank these candidates."

---

## 📁 Project Structure

```
flux/
├── flux.psd1                    # Module manifest
├── flux.psm1                    # Entry point and dispatcher
├── flux-aliases.csv             # 458 built-in aliases (the almanac)
├── flux-packages.example.csv    # Reference format for flux-packages.csv (not deployed)
├── Install-Flux.ps1             # System-wide installer
├── Update-Flux.ps1              # Updater (preserves your aliases + manifest)
├── Write-FluxOutput.ps1         # Shared output helpers
├── Invoke-Winget.ps1            # winget interface and output parser
├── Get-BestMatch.ps1            # Fuzzy matching engine
├── Install-FluxPackage.ps1      # flux install
├── Search-FluxPackage.ps1       # flux search
├── Uninstall-FluxPackage.ps1    # flux uninstall
├── Get-FluxPackage.ps1          # flux list
├── Get-FluxReconciliation.ps1   # flux reconcile
├── Sync-FluxPackages.ps1        # flux sync
├── Export-FluxManifest.ps1      # flux export
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
