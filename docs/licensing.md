# Licensing

What is licensed how, what obligations Veil inherits, and what must be preserved.

> **Scope of this document.** This records what can be established from the
> upstream repositories and their stated licenses. It is **not legal advice**,
> and beyond verifiable facts no legal conclusions are drawn or implied. Where
> something is unknown, it is marked unknown rather than assumed.

---

## 1. The licensing picture in one paragraph

A Veil build is not one work under one license. It is a **combination**:

- **Chromium** — primarily BSD-3-Clause, with many components under their own
  licenses (MIT, Apache-2.0, LGPL, and others), plus generated and
  third-party code under still other terms.
- **brave-core** — Mozilla Public License 2.0, and it is itself a **layer of
  patches over Chromium**.
- **Bundled third-party dependencies** — hundreds of them, each with its own
  license, introduced by both Chromium and Brave.
- **Veil's own code** — this repository, MPL-2.0.

Veil's own license therefore governs only Veil's own files. It does not, and
cannot, relicense anything upstream.

---

## 2. Component-by-component

### 2.1 Chromium

| | |
| --- | --- |
| **Primary license** | BSD-3-Clause |
| **Additional licenses** | Numerous; Chromium ships per-directory license files and a consolidated `about:credits` page |
| **Source** | `https://chromium.googlesource.com/chromium/src.git` |
| **Veil obligation** | Preserve copyright notices, license text, and the credits/attribution mechanism. Provide the corresponding notices in binary distributions. |

**Notes.** Chromium's license is permissive, which is why forks are possible at
all. But "BSD-3-Clause" describes the *project default*, not *every file*.
Chromium contains components under copyleft-ish and notice-heavy licenses, and
some third-party components carry obligations that survive binary distribution.
The authoritative record for a given build is the license metadata that ships
with it — in practice, the credits/attribution surface.

brave-core provides `generate_about_credits` in its `package.json` **[V]**,
which is directly relevant to satisfying attribution obligations for a Veil
build.

### 2.2 brave-core

| | |
| --- | --- |
| **License** | Mozilla Public License 2.0 **[V]** (confirmed on the repository) |
| **Source** | `https://github.com/brave/brave-core` |
| **Role** | Patches over Chromium plus Brave's own components and build tooling |
| **Veil obligation** | MPL-2.0 is file-level copyleft: MPL-covered files, and modifications to them, stay under MPL-2.0. Combining MPL-covered code with other code in a Larger Work is permitted, but the MPL-covered Source Code Form must remain available under MPL-2.0 and its notices must not be removed. |

**What this means for Veil, practically.**

- Veil may build on brave-core and distribute the result.
- Any **modification Veil makes to an MPL-covered file stays MPL-covered** and
  its source must be made available under MPL-2.0.
- Veil may not remove or alter the substance of Brave's license notices
  (MPL-2.0 §3.4).
- Veil's **own new files** are not automatically MPL-covered just for sitting in
  the same build — MPL-2.0 is file-scoped, not project-scoped. This is why Veil
  can license its own files as it chooses.
- MPL-2.0 §3.3 permits distribution as part of a Larger Work under other terms,
  provided the MPL conditions for the covered software are met.

### 2.3 Brave's patch layer

brave-core's role includes maintaining patches against Chromium
(`src/brave/patches`, tracked via `*.patchinfo` files, applied by the **plaster**
tool) **[V]**. This is a licensing-relevant fact:

- The patches are Brave's (or Brave-contributed) work, under brave-core's
  MPL-2.0.
- The Chromium code they modify remains under its own license.
- Veil's future patches inherit the same structure: **Veil's patch files are
  Veil's contribution and can be MPL-2.0; the patched Chromium files stay
  Chromium-licensed.**

### 2.4 Veil (this repository)

| | |
| --- | --- |
| **License** | Mozilla Public License 2.0 |
| **Rationale** | See §3 |
| **Files covered** | Every file in this repository that does not carry a different notice |
| **Copyright** | Veil contributors |

### 2.5 Bundled dependencies

Beyond Chromium itself, a Veil build pulls in third-party code. Notable examples
encountered while establishing the foundation:

| Dependency | Notes |
| --- | --- |
| **depot_tools** | Chromium's build tooling; not redistributed in the browser, but governs how source is obtained and built |
| **adblock-rust** (`https://github.com/brave/adblock-rust`) | Brave's adblock engine, linked via `brave/adblock-rust-ffi` at `components/adblock_rust_ffi` **[V]**. Its own license applies (verify from the repo at the pinned revision) |
| **Rust crates** | Introduced by Chromium and Brave; each crate has its own license. brave-core documents its Rust usage in `docs/rust.md` **[V]** |
| **Node/npm packages** | Build-time only; not shipped in the binary, but a supply-chain surface with its own licenses |
| **BAT / Rewards native libraries** | If Rewards is removed (see [brave-customization-plan.md](brave-customization-plan.md) §2.2), these dependencies disappear from a Veil build, removing their obligations too |
| **Brave Wallet dependencies** | Same story if Wallet is removed |

**Verification requirement.** Package managers are not a license inventory. Any
redistributed Veil binary requires actually enumerating the licenses present in
that build.

---

## 3. Veil's license choice

**Mozilla Public License 2.0.**

Reasoning:

1. **Consistency with the layer we build on.** brave-core is MPL-2.0. Where
   Veil's code sits alongside or modifies MPL-covered code, MPL-2.0 avoids
   introducing a licensing conflict or a boundary that has to be policed
   file-by-file.
2. **File-level copyleft is the right shape here.** Veil is a layered fork, not
   an all-or-nothing product. MPL-2.0's file-scoped copyleft keeps Veil's
   improvements open without attempting to reach into Chromium's differently
   licensed files.
3. **It is not viral across the whole build.** MPL-2.0 permits combining with
   Chromium (BSD-3-Clause) and with permissively licensed dependencies, which a
   GPL-family choice would complicate substantially for a browser fork.
4. **It matches the project's stated openness.** Veil is open source and intends
   its own improvements to stay open.

This is a project decision about Veil's own files. It does not, and cannot,
apply to upstream code.

---

## 4. Obligations Veil must preserve

Regardless of what Veil removes or rebrands, these survive:

1. **License text and notices.** All upstream license files and copyright
   notices must remain in the source tree and in distributions. MPL-2.0 §3.4
   forbids altering their substance.
2. **Source availability for MPL-covered code.** MPL-2.0 §3.1/§3.2: distributed
   Source Code Form — including Modifications — must remain available under
   MPL-2.0, and recipients must be told how to obtain it.
3. **Attribution for Chromium and bundled components.** Chromium's credits
   mechanism must be preserved. Upstream's `generate_about_credits` target **[V]**
   exists for exactly this purpose; a Veil build should keep an equivalent
   attribution surface.
4. **No relicensing of upstream code.** Veil's LICENSE covers Veil's files only.
   Any binary distribution must not imply otherwise.
5. **No removal of notices during feature removal.** Deleting a Brave component
   does not license deleting its license headers from files that remain.
6. **Trademark caution.** Licenses grant copyright/patent rights, generally
   **not** trademark rights — MPL-2.0 §2.3 explicitly excludes rights in
   contributors' trademarks, service marks and logos except as needed for notice
   compliance. See §5.

---

## 5. Trademarks and naming

Copyright licensing and trademark rights are separate. A permissive or
copyleft license over source code does **not** grant the right to use a
trademark as a product identity.

- **"Brave"** and the Brave logo are marks associated with Brave Software. Veil
  must not present itself as the official Brave Browser or use Brave branding as
  its own product identity. See [branding.md](branding.md).
- **"Chromium"** and **"Google Chrome"** are marks associated with Google. Veil
  is not Chrome and must not imply endorsement.
- **"Veil"** is this project's own name. Before any public release, a trademark
  search should be done — **this has not been done**, and the name is currently a
  working name.

MPL-2.0 §2.3 is explicit that the license grants no trademark rights beyond
what notice compliance requires. Removing or replacing upstream branding is
therefore **required**, but removing it does **not** remove the copyright
notices — the two are separate obligations.

---

## 6. Unknowns that must be resolved before shipping a binary

Recorded deliberately as open:

1. The **complete license inventory** of a specific Veil build (not tractable
   from this repository; requires the built checkout and its license metadata).
2. The **exact license of every Brave component Veil keeps**, at the pinned
   revision — especially any component with redistribution terms beyond
   BSD/MPL/MIT/Apache.
3. Whether any **patent grants or additional terms** attach to components Veil
   keeps but upstream used differently.
4. The **license terms of any code Veil adds** from third parties in future
   phases (AI SDKs, MCP libraries, CLI tooling) — each must be vetted *before*
   adoption, not after.
5. Whether the **"Veil" name** is clear for use (trademark search not performed).
6. Whether a **NOTICE / THIRD-PARTY-LICENSES** file needs to be produced for
   binary distribution, and in what form.

---

## 7. Practical rules for Veil contributors

1. Do not remove or alter existing license headers or notices.
2. New files in this repository carry the MPL-2.0 notice (Exhibit A form).
3. Do not copy code from a source whose license has not been checked.
4. Do not add a dependency without checking its license — especially anything
   copyleft that would reach beyond its own files in a combined distributed
   binary.
5. Never use upstream branding as Veil's identity.
6. When in doubt about a redistribution obligation, stop and document it here
   rather than assuming.
