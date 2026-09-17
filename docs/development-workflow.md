# Development Workflow

How to obtain upstream, build Veil, run it, update it, and inspect what changed.

> **Read the prerequisites before starting.** A Chromium build is a large
> commitment: roughly 60 GB of source, significant additional disk for build
> output, many hours of compile time, and a machine with real memory headroom.
> If your environment does not meet the requirements, stop at
> [§1](#1-prerequisites) rather than discovering it three hours in.

---

## 0. The one thing to get right first: where the workspace lives

This is the most common way to waste a day.

**The build workspace must be on a short, space-free path at the root of a
drive.**

- Chromium's build tools break on paths **longer than 256 characters**.
- Chromium's build tools break on paths containing **spaces**.
- You **cannot** build from a directory mounted inside another drive/partition
  without its own drive letter. Upstream documents this failing inside
  `src/testing/generate_location_tags.py` with
  `The system cannot find the path specified.`

Good workspaces:

```
C:\veil-build
D:\veil
/home/dev/veil
```

Bad workspaces:

```
C:\Users\First Last\Documents\My Projects\Veil      ← spaces
C:\Work\Project Open Browser                        ← spaces
```

**This repository can live anywhere** — it is documentation, pins and scripts.
Only the *build workspace* has the path constraint. `VERIFY:` The scripts take
the workspace path as a parameter (`$VEIL_WORKSPACE` / `$VEIL_WORKSPACE`), so
this repository location does not matter.

The workspace layout that upstream expects, and that the scripts create:

```
<workspace>/
├── src/                     Chromium (fetched by gclient)
├── src/brave/               brave-core (cloned by scripts/fetch-upstream)
├── vendor/depot_tools/      gclient, gn, ninja bootstrap
└── out/                     build output
```

`brave-core` **must** live at `<workspace>/src/brave`. Upstream's own
instructions are explicit about this: `git clone ... path-to-your-project-folder/src/brave`.

---

## 1. Prerequisites

Follow upstream's platform guide, and note what is actually required.

### Windows (the platform this project is currently set up for)

Authoritative upstream source: Brave's `Windows-Development-Environment` wiki
page, which directs you to Chromium's "Checking out and Building Chromium for
Windows" guide — **stopping before the `Get the code` step**, because brave-core
supplies its own fetch step.

| Requirement | Detail |
| --- | --- |
| **Windows version** | Must satisfy Chromium's system requirements. Windows 10 or 11. |
| **Developer Mode** | Must be **enabled** (Windows settings → For developers). |
| **Antivirus exclusions** | Add exclusions for the workspace. Defender is on by default and will materially slow or break the build. |
| **Visual Studio** | **Visual Studio Community 2022, Update 17.8.3** (later versions probably work). Include the **Desktop development with C++** workload and the **Windows SDK** (the Windows 11 SDK also works on Windows 10). Upstream references Google's omaha `doc/DeveloperSetupGuide.md` for the supported toolchain. |
| **Git** | **2.41 or newer**, from git-scm.com. ⚠️ **Do NOT use the Git bundled inside `depot_tools`** — it is incompatible with Brave's patching system. |
| **Git configuration** | Apply the `git config --global` settings from Chromium's "Get the Code" section. Brave documents its own requirements in `docs/git_configuration.md` **[V]**. |
| **Node.js** | **v24 or newer.** brave-core's `devEngines` demands `>=24.16.0 <25.0.0` and is configured to **fail hard** otherwise. |
| **pnpm** | **v11 or newer** — `npm install -g pnpm@latest`. brave-core's `devEngines` demands pnpm `>=11.11.0` and fails hard otherwise. |
| **Python** | Python 3. The build uses depot_tools' own Python. Some legacy scripts still expect Python 2.7. Do **not** put depot_tools' Python on your PATH — that causes known issues. |
| **RAM** | Chromium linking is memory-hungry. 16 GB is marginal; more is strongly preferred. |
| **Disk** | ~60 GB for the checkout alone, plus substantial build output. Budget well over 150 GB free. |

**Shell note.** Run the browser from a normal `cmd.exe` window or from Explorer.
Debug builds log to stderr, and that **crashes under Cygwin or Git Bash**.

### Linux / macOS

Follow the corresponding upstream wiki pages:
`Linux-Development-Environment`, `macOS-Development-Environment`. The script
`scripts/setup-linux.sh` checks the common prerequisites; it does not install
them.

### Verify your environment

```powershell
.\scripts\setup-windows.ps1
```

```bash
./scripts/setup-linux.sh
```

These are **checks**, not installers. They report what is missing and what to
do. They deliberately install nothing.

---

## 2. Clone this repository

```powershell
git clone https://github.com/anhsirk-design/veil-browser.git
cd veil-browser
```

Nothing about the upstream build happens here. This repository is pins,
documentation and scripts.

---

## 3. Fetch upstream

```powershell
# Choose a SHORT, SPACE-FREE workspace path (see §0)
$env:VEIL_WORKSPACE = 'C:\veil-build'

.\scripts\fetch-upstream.ps1
```

```bash
export VEIL_WORKSPACE=/home/dev/veil-build
./scripts/fetch-upstream.sh
```

This clones **brave-core** into `<workspace>/src/brave` at the pinned revision
from [`../upstream/versions.json`](../upstream/versions.json). It does **not**
download Chromium — that is `pnpm run init`'s job in the next step, because
Chromium is fetched by `gclient` which brave-core bootstraps itself.

Before running it, you can confirm the pins are still reachable upstream:

```powershell
.\scripts\verify-pins.ps1
```

---

## 4. Configure the build

Build configuration lives in `.env` **in the brave-core repository root**
(`<workspace>/src/brave/.env`).

Start from the template:

```powershell
Copy-Item .env.example "$env:VEIL_WORKSPACE\src\brave\.env"
```

Read [`.env.example`](../.env.example) — it explains every flag and, importantly,
documents that **a Veil build supplies none of Brave's service credentials**.
You do not need any of them for a normal developer build.

Every flag in that file corresponds to a service that upstream Brave operates
and pays for. Upstream's own documentation is explicit that external developers
must supply their own values. A non-official build does not require them.

---

## 5. Build

```powershell
.\scripts\build.ps1
```

```bash
./scripts/build.sh
```

This runs the two upstream steps in sequence, inside `<workspace>/src/brave`:

1. **`pnpm run init`** — this is the big one. It downloads depot_tools
   (including `gclient`), sets build environment variables, writes `.gclient`,
   runs `gclient sync`, and applies Brave's patches. Upstream warns that this
   "will download the Chromium source, which has a large history (10's of
   gigabytes of data)". In practice `gclient sync` fetches on the order of
   **240 repositories and ~60 GB**.
2. **`pnpm run build`** — configures GN and compiles. Upstream warns it "could
   potentially take a few hours" and "can be very slow and use a lot of RAM".
   The default build type is **component** (a debug-friendly build). Other
   types: `Release`, `Static`, `Debug`.

Override the build type and target platform:

```powershell
.\scripts\build.ps1 -BuildType Release
.\scripts\build.ps1 -TargetOs windows -TargetCpu x64
```

**Patch-only fast path.** If you only need to re-apply patches after a source
change, upstream exposes `pnpm run apply_patches` inside `src/brave`. That is
far cheaper than a full `sync`.

### What the build actually does, mechanically

Worth understanding, because it explains most failures:

- `pnpm run init` sets env vars including `DEPOT_TOOLS_WIN_TOOLCHAIN=1`,
  `USE_BRAVE_HERMETIC_TOOLCHAIN=1`, and a Brave-hosted toolchain base URL; it
  creates `.gclient` with two solutions — `src` (Chromium) and `src/brave`
  (brave-core) — and runs `gclient sync`.
- The real revision lock is the generated **`<workspace>/.gclient_entries`**,
  which lists the exact versions checked out. `versions.json` is our *intent*;
  `.gclient_entries` is the *fact*.
- Building is `gn gen` followed by `autoninja` (Brave customises **siso**,
  Chromium's distributed-build replacement for ninja — see brave-core's
  `docs/siso_customization.md` **[V]**). The default target is `brave:all`.
- MSVC handling lives in `build/commands` inside brave-core.

---

## 6. Run

```powershell
.\scripts\run.ps1
```

```bash
./scripts/run.sh
```

This runs `pnpm start [Release|Component|Static|Debug]` inside
`<workspace>/src/brave`.

**Run it from a plain `cmd.exe` or Explorer**, not from a Cygwin/Git Bash
environment — debug builds write to stderr and that crashes in those shells.

---

## 7. Updating upstream

Upstream moves constantly. Veil pins deliberately and moves in steps.

```powershell
# In <workspace>/src/brave
pnpm run sync                                  # minimal incremental sync
pnpm run sync --force                          # force chromium + brave-core to latest
                                               # for the current ref, re-apply all
                                               # patches, force-update child deps
pnpm run sync --init                           # force to the versions in
                                               # brave-core/package.json + all deps
pnpm run sync --sync_chromium true             # also sync Chromium
pnpm run sync -D                               # delete unused deps (gclient sync -D)
```

The documented `sync` semantics, from upstream:

- **no flags** — minimal incremental update.
- **`--force`** — force Chromium and brave-core to the latest remote for the
  current ref, re-apply all patches, force-update child dependencies.
- **`--init`** — force to the versions declared in brave-core's `package.json`,
  plus force-update all dependencies.
- **`--sync_chromium`** — control whether Chromium is synced.
- **`-D` / `--delete_unused_deps`** — mirrors `gclient sync -D`.
- Positional `brave_core_ref` — target a specific brave-core ref.

**After any pin change:**

1. Update [`upstream/versions.json`](../upstream/versions.json).
2. Run `scripts/verify-pins.ps1`.
3. Sync the workspace.
4. **Snapshot `<workspace>/.gclient_entries`** into `upstream/lock/` — this is
   what makes the build reproducible after the fact.
5. Re-apply Veil's changes and rebuild.
6. See [upstream-strategy.md](upstream-strategy.md) §5 for the rules that keep
   this cheap.

---

## 8. Tests, lint and format

Upstream exposes these inside `src/brave` **[V]**:

| Command | Purpose |
| --- | --- |
| `pnpm run test` | Test runner (`test.ts`) |
| `pnpm run test-unit` | Unit tests (jest) |
| `pnpm run eslint` | `eslint --quiet .` |
| `pnpm run format` | Formatting (`format.ts`) |
| `pnpm run presubmit` | Presubmit checks |
| `pnpm run gn_check` | GN consistency check |
| `pnpm run network-audit` | **Network audit tests** (`brave_network_audit_tests`) — directly relevant to [privacy-model.md](privacy-model.md) §5 |
| `pnpm run versions` | Version information |
| `pnpm run get_build_var` | Read a build variable |
| `pnpm run generate_about_credits` | Regenerate the attribution/credits data — relevant to [licensing.md](licensing.md) §4 |

**Veil's own contribution** is currently docs, scripts and pins — there is no
Veil source to lint yet. When Veil code lands, its lint/format/test commands get
added here.

---

## 9. Inspecting changes

The discipline that keeps this project maintainable.

**In the Veil repository (this one):**

```powershell
git status
git diff
```

**In the workspace:**

```powershell
cd $env:VEIL_WORKSPACE\src\brave
git status          # should be clean upstream except for applied-patch state
git log --oneline -20
```

**The rule:** an edit made directly inside `<workspace>/src/...` and not captured
as a Veil script, patch or configuration value is an edit that will be destroyed
at the next upstream sync, silently. See
[upstream-strategy.md](upstream-strategy.md) §4.

**Inspect build configuration:**

```powershell
# Inside <workspace>, after a successful gn gen
gn args out\Component_Default --list          # list all available args
```

---

## 10. Troubleshooting quick reference

| Symptom | Likely cause |
| --- | --- |
| `The system cannot find the path specified.` in `src/testing/generate_location_tags.py` | Workspace is on a folder-mounted drive, or its path contains spaces or exceeds 256 chars. Move it. |
| `devEngines` failure during `pnpm install` | Node or pnpm is below the hard minimum. Brave requires Node `>=24.16.0 <25.0.0` and pnpm `>=11.11.0`, and fails hard otherwise. |
| Patch application failures after a sync | Veil's or Brave's patches no longer apply to the moved Chromium pin. See [upstream-strategy.md](upstream-strategy.md) §5. |
| Extremely slow builds | Antivirus is scanning the workspace. Add exclusions. |
| Debug build crashes with no output | Running under Cygwin/Git Bash. Use `cmd.exe` or Explorer. |
| Build breaks after a Windows update | Visual Studio or Windows SDK version drift. Chromium is sensitive to specific toolchain versions. |

Upstream's own `Troubleshooting` wiki page and Chromium's Windows build
instructions are the first stop for build-system errors we have not seen before.

---

## 11. Repository conventions

- **This repository is for Veil's own artifacts**: pins, scripts, patches,
  documentation, and — in later phases — Veil source.
- **Never commit upstream source.** No Chromium, no brave-core, no workspace
  output. `.gitignore` enforces this.
- **Never commit `.env`.** Only `.env.example` belongs in the repository.
- **Never commit secrets.** No keys, tokens, certificates, or machine-specific
  configuration.
- **Keep upstream-facing changes distinguishable from Veil's** — see
  [upstream-strategy.md](upstream-strategy.md) §4.
- **Meaningful commits.** The git history is documentation.
