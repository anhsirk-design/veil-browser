# Veil

**A minimal, privacy-first, AI-native desktop browser for people who build software.**

Veil is an open-source browser built on the Brave / Chromium foundation. It is
designed for developers, AI/ML engineers, security researchers, automation
developers and technical power users — not for general consumers.

> **Status: Phase 0 — Foundation.**
> This repository currently contains the project skeleton, the pinned upstream
> revisions, the build scripts and the design documentation. The actual
> Chromium/brave-core source fetch and compilation are **deliberately deferred**
> (see [Build status](#build-status)).

---

## What Veil is

- **Open source.** Mozilla Public License 2.0 for Veil's own code.
- **Minimal.** No ads, no crypto wallet, no rewards program, no engagement
  machinery, no upsell surfaces.
- **Privacy-first.** No telemetry, no analytics, no behavioural tracking, and
  no data sent to Veil-operated infrastructure by default.
- **Based on real browser engineering.** Veil is a fork layered on
  **Chromium → brave-core → Veil**, not an Electron/Tauri wrapper.
- **AI-native and agent-native, eventually.** AI and agent capabilities will be
  explicit, inspectable, permissioned interfaces — not an opaque chatbot bolted
  onto a toolbar.
- **Developer-focused and programmable.** Built to be driven from a CLI and
  from external tools.

The long-term destination:

> A minimal, open-source, privacy-first browser that humans can use normally,
> and that AI agents can operate through explicit, inspectable,
> user-controlled interfaces.

Veil is **not** affiliated with, endorsed by, or presented as the official
Brave Browser. See [docs/branding.md](docs/branding.md).

---

## Architecture in one line

```
Chromium
   ↓
Brave / brave-core          (upstream foundation, pinned)
   ↓
Veil                        (this repository)
   ↓
Veil-specific browser, agent, developer and security systems
```

Upstream source is **never vendored into this repository**. Veil is a thin
meta-repository that pins upstream revisions, applies Veil's own changes on top,
and keeps the two cleanly separable so upstream can be re-synced.

See [docs/upstream-strategy.md](docs/upstream-strategy.md) and
[docs/architecture.md](docs/architecture.md).

---

## Pinned upstream revisions

Everything about a Veil build is determined by these pins. They are recorded
machine-readably in [`upstream/versions.json`](upstream/versions.json).

| Component | Revision | Source |
| --- | --- | --- |
| **brave-core** | `1.98.7` (tracking `master`) | https://github.com/brave/brave-core |
| **Chromium** | tag `154.0.8037.49` | https://chromium.googlesource.com/chromium/src.git |
| **depot_tools** | tracking `main` | https://chromium.googlesource.com/chromium/tools/depot_tools.git |
| **brave-browser** (issues/releases/wiki only) | `v1.95.102` | https://github.com/brave/brave-browser |

`brave/brave-browser` is a **thin repository** — it holds issues, releases and
the wiki only. The buildable source and all build tooling live in
`brave/brave-core`. This was verified directly against upstream.

---

## Repository layout

```
.
├── README.md                     you are here
├── LICENSE                       MPL-2.0 (Veil's own code)
├── .env.example                  template for Brave build-time service keys
├── .gitignore
├── docs/
│   ├── upstream-strategy.md      which upstreams we depend on and how we sync
│   ├── architecture.md           long-term component boundaries (not built yet)
│   ├── brave-customization-plan.md   KEEP / REMOVE / REPLACE / AUDIT LATER
│   ├── privacy-model.md          what talks to the network, and why
│   ├── licensing.md              per-component license obligations
│   ├── branding.md               naming, assets, trademark notes
│   └── development-workflow.md   clone → fetch → build → run → update
├── upstream/
│   ├── versions.json             machine-readable revision pins
│   └── README.md                 what each pin means and how to move it
└── scripts/
    ├── setup-windows.ps1         prerequisites check + install guidance
    ├── setup-linux.sh            prerequisites check (POSIX)
    ├── fetch-upstream.ps1        clone brave-core into <workspace>/src/brave
    ├── fetch-upstream.sh         same, for POSIX
    ├── build.ps1                 pnpm run init + pnpm run build
    ├── build.sh                  same, for POSIX
    ├── run.ps1                   pnpm start
    ├── run.sh                    same, for POSIX
    └── verify-pins.ps1           validate upstream pins are reachable
```

There are intentionally **no empty placeholder directories** for future
subsystems. The boundaries for `browser/`, `agent/`, `developer/`, `security/`
and `shared/` are specified in [docs/architecture.md](docs/architecture.md) as
interfaces and documentation, and will be created when there is code to put in
them.

---

## Quick start

> ⚠️ **Read this first.** A full build requires roughly **60 GB** of source,
> **~100 GB** of disk headroom for build output, and a machine with **much more
> than 16 GB RAM**. A Visual Studio C++ toolchain and `depot_tools` are
> mandatory on Windows. Do not start unless you meet the prerequisites in
> [docs/development-workflow.md](docs/development-workflow.md).

```powershell
# 1. Put the build workspace on a SHORT, SPACE-FREE path at the root of a drive.
#    Chromium's build tools break on paths >256 chars and on paths with spaces,
#    and they cannot build from a directory mounted inside another drive.
#    Example:  C:\veil-build
$env:VEIL_WORKSPACE = 'C:\veil-build'

# 2. Check prerequisites.
.\scripts\setup-windows.ps1

# 3. Clone brave-core into $VEIL_WORKSPACE\src\brave
.\scripts\fetch-upstream.ps1

# 4. Download Chromium (~60 GB) and apply Brave's patches. Takes hours.
.\scripts\build.ps1

# 5. Launch.
.\scripts\run.ps1
```

POSIX equivalents: `scripts/setup-linux.sh`, `scripts/fetch-upstream.sh`,
`scripts/build.sh`, `scripts/run.sh`.

**Do not clone this repository into a path containing spaces** if you intend to
build. `C:\Work\Project Open Browser` is fine for authoring documentation but is
**not** a valid build workspace.

---

## Build status

Phase 0 ships the foundation, documentation and tooling. It does **not** ship a
compiled browser.

The local build is deferred because the current workstation does not yet satisfy
upstream's requirements:

| Requirement | Required | Present |
| --- | --- | --- |
| Node.js | `>=24.16.0 <25.0.0` (hard `devEngines` constraint) | `v24.14.0` ❌ |
| pnpm | `>=11.11.0` | not installed ❌ |
| `depot_tools` / `gclient` | required | not installed ❌ |
| Visual Studio C++ toolchain + Windows SDK | required | not verified ❌ |
| RAM | comfortable headroom above 16 GB | 15.2 GB ⚠️ |
| Free disk | ~176 GB free is enough for checkout; build output adds significantly | 176.2 GB ⚠️ |

These are environment limitations, **not** blockers in Veil's architecture.
Nothing in this repository substitutes a different browser engine. See
[docs/development-workflow.md](docs/development-workflow.md) for the exact
prerequisite list and the full build sequence.

---

## Documentation

| Document | Covers |
| --- | --- |
| [docs/upstream-strategy.md](docs/upstream-strategy.md) | Upstream repositories, authority, how Veil's changes stay separable, how to re-sync upstream |
| [docs/architecture.md](docs/architecture.md) | Long-term component boundaries: browser, agent, developer, security, shared. **Design only — not implemented.** |
| [docs/brave-customization-plan.md](docs/brave-customization-plan.md) | KEEP / REMOVE / REPLACE / AUDIT LATER classification of Brave-specific features |
| [docs/privacy-model.md](docs/privacy-model.md) | Known network behaviour, product-controlled communication, unresolved audit areas |
| [docs/licensing.md](docs/licensing.md) | Chromium, Brave, brave-core and bundled dependency licensing and obligations |
| [docs/branding.md](docs/branding.md) | Product naming, temporary upstream branding, trademark considerations |
| [docs/development-workflow.md](docs/development-workflow.md) | Full setup, fetch, build, run, package, test and update workflow |

---

## Principles

1. **No telemetry.** Veil adds no analytics, no usage tracking, no crash
   uploading, no product metrics, no profiling.
2. **No ads, ever.** No advertising, no sponsored content, no affiliate
   injection.
3. **No silent data movement.** Nothing leaves the user's machine for
   Veil-operated infrastructure unless the user explicitly chooses it.
4. **Explicit permissions.** Capabilities are granted, inspectable and
   revocable — including for agents.
5. **Auditable.** An advanced user should be able to determine what the browser
   is doing and why.
6. **No invented privacy claims.** Upstream browser functionality requires
   legitimate network traffic. Veil documents it rather than pretending it does
   not exist.

---

## Non-goals for Phase 0

Deliberately **not** implemented in this phase, and out of scope until their own
milestones: AI provider integrations (OpenAI, Anthropic, Gemini, local LLMs),
agent runtime, MCP, OpenCode/Codex/Claude Code integration, browser automation
tools, a permission engine, secret management, collaboration, sync, accounts,
cloud backends, ads, rewards and crypto features.

---

## License

Veil's own source code is licensed under the **Mozilla Public License 2.0**
(see [LICENSE](LICENSE)).

This repository is only one part of a Veil build. A built binary contains
Chromium (BSD-3-Clause and others), brave-core (MPL-2.0) and hundreds of bundled
third-party components, each under its own license. See
[docs/licensing.md](docs/licensing.md).

"Veil" is a project name, not a claim over the upstream "Brave" or "Chromium"
trademarks. See [docs/branding.md](docs/branding.md).
