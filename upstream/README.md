# upstream/

Machine-readable revision pins and the record of what a Veil build actually
checked out.

---

## Contents

| File | Purpose |
| --- | --- |
| `versions.json` | **The pins.** Which upstream repositories Veil builds on, at which revisions, and the exact build requirements upstream declares. |
| `lock/` | **The facts.** Snapshots of the generated `.gclient_entries` file from real builds. Created after the first successful sync — see below. |

---

## `versions.json` is intent; `.gclient_entries` is truth

This distinction matters and is easy to get wrong.

`versions.json` records what Veil *intends* to build:

- brave-core `master` @ version `1.98.7`
- Chromium tag `154.0.8037.49`
- depot_tools `main`

But a Chromium checkout is not resolved by a single revision. `gclient sync`
resolves **~240 repositories**, including transitive dependencies whose
revisions brave-core selects at sync time. Those resolutions are not in
`versions.json` and cannot be predicted from it.

The generated file **`<workspace>/.gclient_entries`** in the build workspace
"lists out the exact versions that have been checked out". That file is the
actual revision lock.

**Therefore:**

> A build is only reproducible if its `.gclient_entries` was captured.

After every successful sync, snapshot it:

```
upstream/lock/2026-09-17-brave-core-1.98.7-gclient-entries.txt
```

and reference the snapshot in `versions.json` under `reproducibility`.

**Current state: no build has been performed, so `lock/` does not exist yet.**
That is expected in Phase 0 and is stated plainly rather than papered over.

---

## The pins, in short

| Component | Pin | Role |
| --- | --- | --- |
| **brave-core** | `1.98.7` on `master` | Primary upstream. Source, GN build integration, patch tooling. Cloned to `<workspace>/src/brave`. |
| **Chromium** | tag `154.0.8037.49` | The engine. Resolved into `<workspace>/src`. |
| **depot_tools** | `main` | `gclient`/`gn`/`ninja` bootstrap. Resolved into `<workspace>/vendor/depot_tools`. |
| **brave-browser** | `v1.95.102` (latest release) | **Not buildable.** Issues, releases and wiki only. Recorded for reference. |
| **adblock-rust** | resolved at sync time | Linked via `components/adblock_rust_ffi`. Record the resolved revision in `lock/`. |

---

## Why `brave-browser` is listed but not used

`brave/brave-browser` looks like the obvious upstream — it has the releases and
the wiki. It is a **thin repository**. Its own README says:

> "This repository is not needed for building the browser and only holds issues,
> releases and the wiki. The source code and contributions are at
> https://github.com/brave/brave-core."

It contains no source, no build scripts and no `config.projects`. The buildable
source is `brave/brave-core`.

It is recorded here because it is genuinely useful for version and release
signals — just not as a build input.

---

## Changing a pin

1. Read `package.json` from brave-core at the target ref and extract
   `version` and `config.projects.chrome.tag`.
2. Update `upstream/versions.json`.
3. `scripts/verify-pins.ps1` — confirm the new refs actually resolve upstream.
4. Sync the workspace (`pnpm run sync --init` in `src/brave`).
5. Snapshot `.gclient_entries` into `lock/`.
6. Re-apply Veil's changes; rebuild; re-validate.

The rules that keep upstream updates cheap are in
[`../docs/upstream-strategy.md`](../docs/upstream-strategy.md) §4–§5.

---

## Build requirements declared by upstream

Recorded in `versions.json` because they are **hard failures**, not warnings:

- **Node.js** `>=24.16.0 <25.0.0` — `devEngines` with `onFail: "error"`.
- **pnpm** `>=11.11.0` — `devEngines` with `onFail: "error"`.
- **Git** 2.41+ — and explicitly *not* the Git inside depot_tools.
- **Visual Studio** 2022 17.8.3+ with the **Desktop development with C++**
  workload and the **Windows SDK** (Windows builds).
- **Windows Developer Mode** enabled.
- **Administrator rights, once**, to install the C++ workload and SDK.

### Verified in Phase 1: there is no hermetic toolchain escape hatch

brave-core's `build/commands/lib/config.ts` sets
`DEPOT_TOOLS_WIN_TOOLCHAIN = '0'` for anyone without a Brave-internal
remote-execution service, which makes depot_tools use the **locally installed
Visual Studio**. The `USE_BRAVE_HERMETIC_TOOLCHAIN` branch is commented
*"Use hermetic toolchain only internally"* and points at Brave's internal
dependencies URL.

So: **Visual Studio with the C++ workload is genuinely mandatory on Windows**,
not a wiki formality. The `GYP_MSVS_HASH` variable in current source is
`GYP_MSVS_HASH_3bfcb536c8 = '3dce9a2ec1'` — the wiki's
`GYP_MSVS_HASH_68a20d6dee` name is stale.

See [`../docs/upstream-strategy.md`](../docs/upstream-strategy.md) §7.1 for the
source excerpt, and
[`../docs/development-workflow.md`](../docs/development-workflow.md) §1.1 for the
measured environment and the exact unblock commands.
