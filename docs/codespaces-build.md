# Codespaces Build Feasibility

**Verdict: GitHub Codespaces, as currently available to this account, cannot
hold — let alone build — the pinned Brave/Chromium source tree.**

This is a capacity failure, not a performance judgement. The audit is recorded
here in full so the conclusion can be re-checked if the account's plan changes,
rather than re-litigated from memory.

Audit date: 2026-09-17 · Repository: `anhsirk-design/veil-browser` · Pins:
brave-core `1.98.7`, Chromium `154.0.8037.49`

---

## 1. Codespaces availability (measured)

Queried live via the GitHub API
(`GET /repos/anhsirk-design/veil-browser/codespaces/machines`):

| Machine name | Display name | OS | CPUs | RAM | Storage |
| --- | --- | --- | --- | --- | --- |
| `basicLinux32gb` | 2 cores, 8 GB RAM, 32 GB storage | linux | 2 | 8 GB | **32 GB** |
| `standardLinux32gb` | 4 cores, 16 GB RAM, 32 GB storage | linux | 4 | 16 GB | **32 GB** |

`total_count: 2`.

**Only these two machine types are offered.** GitHub's wider catalogue includes
8-core/32 GB/64 GB, 16-core/64 GB/128 GB and 32-core/128 GB types, but **none of
them are available to this repository/account**, which is a free personal plan
(`GET /user` → `plan: null`, `type: User`).

Repo state: public, owner type `User`, no `.devcontainer` present.

**Maximum attainable storage on the available machines: 32 GB.**

---

## 2. Is Linux a supported target for our pinned foundation?

**Yes — verified.**

Brave's `Linux-Development-Environment` wiki page (fetched 2026-09-17) is an
active, maintained development guide and states:

- Follow Chromium's
  [Linux build instructions](https://chromium.googlesource.com/chromium/src/+/main/docs/linux/build_instructions.md)
  for system requirements.
- Requires **Git v2.41+, Python 3, and Node.js v24+**.
- On Ubuntu: `apt-get install build-essential python-setuptools python3-distutils`
- After `pnpm run init`: run **`./src/build/install-build-deps.sh`** (Debian/Ubuntu;
  `--unsupported` for other distros).
- Build configuration via `.env` in the brave-core root.
- Build acceleration via remote build execution is **Brave-internal only**.

Linux is a first-class brave-core development target, so **no part of the
Windows-specific MSVC/SDK blocker exists on Linux**.

### Required Linux toolchain (summary)

| Requirement | Value | Source |
| --- | --- | --- |
| Distribution | Debian/Ubuntu supported directly; others via `install-build-deps.sh --unsupported` | Brave wiki |
| Compiler | GCC/Clang as provisioned by `install-build-deps.sh` (no MSVC anywhere) | Brave wiki → Chromium docs |
| Python | Python 3 (`python3`; may need `python-is-python3` if only `python3` exists) | Brave wiki |
| Node.js | **v24+**; brave-core `devEngines` hard-requires `>=24.16.0 <25.0.0` | Brave wiki + `package.json` |
| pnpm | `>=11.11.0` (hard `devEngines`) | brave-core `package.json` |
| Git | **v2.41+**, and *not* the Git inside depot_tools | Brave wiki |
| System packages | `build-essential python-setuptools python3-distutils`, then `install-build-deps.sh` | Brave wiki |
| `sudo` | Required by `install-build-deps.sh` (available in Codespaces) | Brave wiki / Codespaces |

---

## 3. Resource requirements

### Storage

| Component | Estimate | Basis |
| --- | --- | --- |
| Chromium + brave-core checkout (`gclient sync`) | **~60 GB** | Upstream states ~240 repositories and ~60 GB decompressed; Brave's own `README` warns of "10's of gigabytes" |
| depot_tools, vpython, toolchain downloads | ~10 GB | Upstream build tooling |
| Build output (`out/`) | ~30–60 GB | Chromium component/release builds, observed range |
| caches / intermediates (siso, ninja) | ~10 GB | Upstream |
| **Total** | **~110–140 GB** | |

**The checkout alone (~60 GB) is roughly twice the entire maximum Codespaces
disk (32 GB).** The source tree does not fit. This is the decisive finding —
everything after it is secondary.

### RAM

Chromium's system requirements and practical experience place the floor at
**16 GB**, with link steps benefiting substantially from more. The largest
available Codespaces machine offers exactly 16 GB — the floor, not comfortable.

### CPU

Build time scales roughly with core count. The largest available machine is
**4 cores**. A full Chromium-family build on 4 cores is measured in many hours.

---

## 4. Cost considerations

Published GitHub Codespaces pricing (fetched from GitHub's own billing
documentation, 2026-09-17 — verify before relying on it, as pricing changes):

| Machine type | Price per hour |
| --- | --- |
| 2 core | $0.18 |
| 4 core | $0.36 |
| 8 core | $0.72 |
| 16 core | $1.44 |
| 32 core | $2.88 |
| Storage | $0.07 per GB-month |

Included free quotas for personal accounts:

| Plan | Storage per month | Compute per month |
| --- | --- | --- |
| GitHub Free for personal accounts | **15 GB-month** | **120 hrs** |
| GitHub Pro | 20 GB-month | 180 hrs |

### Implications

1. **The free storage quota is 15 GB-month; the smallest Codespace disk is
   32 GB.** A Codespace that exists for a full month consumes ~32 GB-month
   against a 15 GB-month allowance — it exceeds the free quota simply by
   existing, before any work happens. There is no way to shrink the disk; it is
   tied to the machine type.
2. **Compute is cheap per hour but expensive per build on small machines.**
   A 4-core build at $0.36/hr is affordable per hour, but if it takes 10+ hours
   that is 40+ core-hours and a day of wall-clock time — most of the free
   120-hour allowance for one build.
3. **Large builds are the *reason* to pay.** If a 16-core/64 GB machine were
   available at $1.44/hr and a build took ~4 hours, one build session ≈ **$5.76**
   plus ~64 GB-month storage ≈ **$4.48/month**. That is a practical cost for
   occasional build sessions — but those machine types are not offered here.
4. **Persistent vs build-only.** Given storage is billed continuously, the
   sensible pattern *if* larger machines were available would be a
   build-session-only Codespace, stopped outside build windows, rather than a
   persistent development environment. That is a workflow design point, not a
   recommendation to spend money now.

**Nothing was purchased or provisioned during this audit.**

---

## 5. Comparison: local Windows vs Codespaces

| Constraint | Local Windows (measured Phase 1) | Codespaces (available) |
| --- | --- | --- |
| OS | Windows 11 build 26200 | Linux (container) |
| CPU | Ryzen 7 6800H, 16 logical cores | 2 or **4 cores max** |
| RAM | 15.25 GB | 8 GB or **16 GB max** |
| Disk | **175.6 GB free** | **32 GB max** |
| MSVC C++ toolchain | **Missing** | Not required |
| Windows SDK | **Missing** | Not required |
| Admin rights needed | **Yes — currently unavailable** | Not needed for build deps (`sudo` present) |
| Can hold the ~60 GB checkout | Yes (tight) | **No** |
| Can run a full build | Yes, if toolchain installed | **No — not enough disk** |
| Can launch a browser and browse | Yes (has a display) | **No — headless, no display** |
| Cost | Existing hardware | Free quota insufficient; billed beyond |

**Codespaces would remove the toolchain blocker — the exact thing blocking us —
but replaces it with a harder one: the disk is smaller than the source tree.**
It also cannot perform runtime verification, because a Codespace has no display
and Phase 1's goal includes launching the browser and loading real sites.

---

## 6. Option analysis

Constraints each option must satisfy: **(S)** enough storage; **(T)** a working
C++/Linux toolchain with no admin dependency; **(R)** ability to launch and
browse; **(C)** acceptable cost; **(K)** no architectural change to the Brave/
Chromium foundation.

### OPTION A — Local Windows development + local Windows build

- **Satisfies:** S (175.6 GB free — tight but sufficient), R (has a display), K (unchanged foundation)
- **Fails:** T (MSVC + Windows SDK absent; installing them needs Administrator rights, which the agent does not have)
- **Advantages:** uses existing hardware; no new cost; only a display and full runtime verification possible here; matches the Phase 0/1 documentation already written.
- **Disadvantages:** storage headroom is thin (35–65 GB after checkout + build output); 15.25 GB RAM is marginal; long build on 8 physical cores.
- **Major blocker:** one elevated `vs_installer.exe modify` command (documented in [development-workflow.md](development-workflow.md) §1.1).
- **Complexity:** Low.

### OPTION B — Codespaces Linux development + Linux build

- **Satisfies:** T (no MSVC needed; `sudo` available for build deps), K (unchanged foundation)
- **Fails:** **S (32 GB disk vs ~60 GB checkout)**, **R (no display — cannot launch/browse)**, C (free quota exceeds by mere existence)
- **Advantages:** removes the Windows toolchain blocker entirely; Linux is an officially supported brave-core target; clean, reproducible container.
- **Disadvantages:** cannot hold the source; cannot verify runtime; slowest available CPU.
- **Major blocker:** machine type availability on this account.
- **Complexity:** Low — but blocked on resources, not effort.

### OPTION C — Codespaces for application/agent development + separate machine for browser builds

- **Satisfies:** T (Linux toolchain for app-layer work), C (small Codespace is cheap if kept small)
- **Fails:** S and R for the *browser build* half unless a second environment exists
- **Advantages:** separates cheap day-to-day work (docs, TypeScript, WebUI, agent/CLI code, which are small) from expensive browser builds; a small Codespace is genuinely well-suited to the app layer.
- **Disadvantages:** two environments to keep in sync; the browser-build half still needs a solution.
- **Major blocker:** does not by itself solve the browser build.
- **Complexity:** Medium.

### OPTION D — Other approaches

- **D1 — Local Windows with a one-time elevated install.** Satisfies S, T, R, K. Cost: zero. Requires the user to run one command as Administrator. Complexity: Low. *This is the shortest path given the evidence.*
- **D2 — GitHub plan upgrade (Pro or billing enabled).** Would raise quotas (20 GB-month, 180 hrs) and *may* unlock larger machine types. **Unverified** — the machine list would have to be re-queried after any change. Note that even Pro's 20 GB-month storage quota is below the 32 GB minimum disk, so a Codespace would still incur storage charges.
- **D3 — A generic Linux cloud VM** (e.g. 32 GB RAM / 200+ GB disk). Satisfies S, T, K; R only with extra display work (X forwarding / VNC / headless verification). Cost is a recurring monthly figure. Complexity: Medium.
- **D4 — Local Linux (dual-boot/WSL2) on the existing machine.** Satisfies T (no MSVC), S (same 175.6 GB disk), K. R depends on WSLg/X support. Complexity: Medium. Note that WSL2 still consumes the same physical disk.

---

## 7. Recommended arrangement (evidence-based)

Given the measured constraints, the browser build and the application layer have
**different** optimal homes, and conflating them is what makes the choice look
hard:

1. **Browser build + runtime verification → the local Windows machine**, after
   the one-time elevated VS C++ workload install. It is the only environment
   audited that satisfies storage, runtime and cost simultaneously.
2. **Application-layer development (docs, TS/WebUI, future agent/CLI code) →
   a small Codespace is viable**, and matches Option C, because that work is
   small, needs no Chromium checkout, and benefits from a consistent Linux
   container.

**Codespaces is not viable for the browser build itself at this time** —
specifically because the maximum available disk (32 GB) is smaller than the
source checkout alone (~60 GB), and because a headless Codespace cannot perform
the launch-and-browse verification that defines a working baseline.

This is a constraint statement, not a preference ranking.

---

## 8. Risks

1. **Machine type availability may change without notice.** Re-run
   `gh api /repos/{owner}/{repo}/codespaces/machines` before relying on any
   conclusion here.
2. **Storage is billed continuously and cannot be reduced independently of the
   machine type.** A Codespace left running consumes quota even when idle.
3. **16 GB RAM is the floor for Chromium, not a comfortable figure.** Even if
   storage were solved, the largest available machine sits exactly at the floor.
4. **No display in Codespaces.** Runtime verification would require headless
   workarounds (Xvfb, screenshot harnesses) that add complexity and still do not
   replicate real browsing.
5. **`install-build-deps.sh` assumes Debian/Ubuntu**; other bases need
   `--unsupported` and may still fail.
6. **Free-quota exhaustion blocks resumption** if no payment method is on file.
7. **Chromium's sandbox and some build steps behave differently in
   containers**, which is a known source of environment-specific failures.
8. **Do not adjust the project to fit the environment.** Nothing in this audit
   justifies changing the Brave/Chromium foundation, and no such change was
   made.

---

## 9. What was and was not done

**Done:** repository documentation reviewed; Codespaces machine types queried
live; account plan and repo metadata checked; Linux build support verified
against Brave's own wiki; system requirements and pricing taken from GitHub's
own documentation; storage compared against upstream-stated checkout size.

**Not done, deliberately:** no source fetched; no build attempted; no Codespace
created; nothing purchased; no architecture changed; no application code
touched.

**To re-open this audit**, the single check that matters is:

```bash
gh api /repos/anhsirk-design/veil-browser/codespaces/machines
```

If that ever lists a machine with **64 GB or more of storage**, the storage
objection disappears and the remaining questions become cost, build time and
headless runtime verification.
