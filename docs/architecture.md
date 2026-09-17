# Architecture

**This document describes the long-term intended architecture of Veil.**

Nothing below the "Foundation (exists today)" section is implemented. These are
boundaries, not code. They exist now so that future subsystems have a defined
place to live and a defined interface to respect, and so we do not accidentally
build something that violates them later.

---

## 0. Foundation (exists today)

```
Chromium
   ↓
Brave / brave-core          pinned upstream, fetched into a workspace
   ↓
Veil                        this repository — pins, patches, docs, tooling
```

Veil today is a **thin meta-repository**: revision pins, build/run scripts,
privacy and licensing records, and the documented plan for what changes.

---

## 1. Target system shape

```
                            USER
                              │
                              ▼
                    ┌──────────────────┐
                    │   BROWSER UI     │
                    └────────┬─────────┘
                             │
                ┌────────────┼────────────┐
                ▼            ▼            ▼
            Browser       Agent      Workspace
                │            │            │
                │        ┌───┴───┐        │
                │        │       │        │
                │      Cloud   Local      │
                │       AI      AI        │
                │                         │
                │                   ┌─────┴─────┐
                │                   │ Files     │
                │                   │ CLI       │
                │                   │ MCP       │
                │                   └───────────┘
                │
                ▼
           Browser API
                │
        ┌───────┼────────┐
        ▼       ▼        ▼
       DOM    Input   Network

        ┌────────────────────┐
        │  PERMISSION LAYER  │   (cross-cutting — gates every arrow above)
        └────────────────────┘

        ┌────────────────────┐
        │  ACTIVITY / AUDIT  │   (cross-cutting — records what was permitted)
        └────────────────────┘
```

Two properties are load-bearing and must not be designed away:

1. **The permission layer is cross-cutting, not a dialog.** It sits between every
   capability and its effect. A UI prompt is one possible *rendering* of it.
2. **The activity/audit layer is cross-cutting, not a log file.** What an agent
   (or the browser) did, and under whose authority, is a first-class record.

---

## 2. Component boundaries

Each boundary below is intended to be independently developable and testable.
This is what "every future subsystem should have a clear boundary" means
concretely.

### `browser/` — Browser

**Owns:** Veil's changes to the browser layer itself — chrome UI surfaces,
toolbar, tab strip behaviour, new tab page, settings surfaces, chrome:// pages,
first-run experience, default preferences, branding strings.

**Depends on:** brave-core, Chromium.

**Must not:** reach into agent, security or developer subsystems to implement
features. If the browser UI needs data from the agent subsystem, it goes through
a defined interface, not a direct call.

**Status:** partially exists upstream; Veil's `browser/` layer is not created
yet. UI work is deliberately deprioritised (see "Sequencing" below).

### `agent/` — Agent

**Owns:** the agent runtime, model provider abstraction, tool interface,
planning/execution loop, agent memory, conversation state, and the wiring that
lets an agent act on the browser through the Browser API.

**Depends on:** the Browser API, the permission layer, the activity/audit layer.

**Must not:** talk to a network provider without passing through the permission
layer and being recorded by the audit layer. Must not embed a specific vendor's
SDK as the only path.

**Status:** design only. **Not implemented in Phase 0.**

### `developer/` — Developer

**Owns:** CLI surface, MCP server/interface, editor integrations
(OpenCode/Codex/Claude Code and equivalents), local tooling, project/workspace
concepts, file access surface, automation entry points, the browser SDK.

**Depends on:** the Browser API, the permission layer, the activity layer.

**Must not:** bypass the permission layer because "it's a dev tool". Developer
tools are exactly the tools that most need an explicit authority model.

**Status:** design only. **Not implemented in Phase 0.**

### `security/` — Security

**Owns:** the permission engine, capability grants and revocation, secret
handling, network controls, prompt-injection defences, data-access boundaries,
and the auditable record of all of the above.

**Depends on:** little. This layer is deliberately near the bottom of the stack
so it can be depended upon rather than depend.

**Must not:** be optional, bypassable, or implemented as UI sugar. A permission
check that lives only in a UI layer is not a permission check.

**Status:** design only. **Not implemented in Phase 0.**

### `shared/` — Shared

**Owns:** shared types, interfaces, protocol definitions and small utilities that
are genuinely used by more than one of the above.

**Must not:** become a dumping ground. If something is used by exactly one
consumer, it belongs to that consumer. Create this layer only when a real,
demonstrated second consumer exists.

**Status:** does not exist. Correctly so.

---

## 3. Interfaces (the only cross-boundary contracts)

These are described, not defined in code yet. They are the seams that make the
boundaries real.

### Browser API

The structured surface through which anything (a human action, an agent, a CLI,
an MCP client) reads and manipulates the browser: navigation, tabs, DOM access,
input synthesis, network observation, capture.

Requirements:
- Every capability in it is **individually permissionable**.
- It is **the same surface** for every caller class. Agents do not get a
  privileged back door.
- It is **inspectable**: an advanced user can enumerate what it can do.

### Permission Layer

A single decision point: *may this principal perform this capability, on this
target, right now?*

Requirements:
- Principal-aware (user, agent, dev tool, extension — distinguished).
- Target-aware (this tab, this origin, this file, this network destination).
- Grant-lifetime-aware (once, this session, always, revocable).
- Deny-by-default for anything not explicitly granted.
- Every decision is observable.

### Activity / Audit

An append-only record of capabilities exercised, by whom, under what grant, with
what result. Local-first. User-inspectable and user-exportable. Not something
that is uploaded anywhere by default.

---

## 4. Explicit non-goals of this design

To prevent over-building:

- No microservice decomposition. Veil is a desktop application.
- No plugin architecture until there is a demonstrated need for third-party
  extension of Veil itself (browser extensions are a separate, upstream-provided
  story).
- No "everything is an event bus" abstraction.
- No agent framework selected before an agent exists.
- No provider abstraction designed in detail before there are two providers.

---

## 5. Sequencing

Deliberately chosen order:

1. **Foundation (Phase 0, current).** Repository, pins, docs, tooling.
   *No UI work — architecture first.*
2. **A build that runs.** Obtain upstream, build, launch, browse. Prove the
   foundation is real before building on it.
3. **Browser surface reduction.** Apply the KEEP/REMOVE/REPLACE decisions in
   [brave-customization-plan.md](brave-customization-plan.md) to produce a
   minimal browser. Refine UI here — not earlier.
4. **Privacy baseline verification.** Audit actual network behaviour against
   [privacy-model.md](privacy-model.md).
5. **Permission + activity layers.** Establish the boundaries before anything
   needs to ask for permission.
6. **Browser API.** A stable, permissioned, inspectable surface.
7. **Developer surface.** CLI, then MCP.
8. **Agent.** Last, because it depends on everything above being trustworthy.

The ordering principle: **a capability should not exist before the mechanism
that lets the user control it.**
