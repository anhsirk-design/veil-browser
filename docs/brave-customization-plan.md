# Brave Customization Plan

What Veil keeps from Brave, what it removes, what it replaces, and what needs a
decision later.

> **Phase 0 scope note.** This document is a **plan**, not an execution log.
> Phase 0 performs **no feature removal**. Removing components before the build
> workspace exists would be guessing at a dependency graph we have not traced.
> The project rule is explicit: *do not remove Chromium/Brave components
> blindly — understand dependencies first.*

---

## How to read this document

Each area is classified:

| Class | Meaning |
| --- | --- |
| **KEEP** | Fits Veil. Retained as-is, or with minor Veil configuration. |
| **REMOVE** | Does not fit Veil. To be excluded or deleted in a later phase. |
| **REPLACE** | The capability is wanted, but Brave's implementation is not. |
| **AUDIT LATER** | Real network/behavioural surface. Cannot be classified until inspected. |

Every entry records: what it does, where it lives, what depends on it, whether it
fits Veil, the intended disposition, and the risk of removal.

### Confidence levels used below

Because Phase 0 defers the source checkout, code locations are marked:

- **[V]** — **verified** this phase (from brave-core's `package.json`, docs
  index, or repository listings).
- **[I]** — **indicative** path, derived from Brave's documented layout and
  directory conventions. **Must be verified against the pinned checkout before
  any deletion.**

Treat every **[I]** path as a search hint, not a fact.

---

## 1. Classification summary

| Area | Class | Removal risk |
| --- | --- | --- |
| Ad blocking / Shields (adblock-rust) | **KEEP** | n/a |
| Brave Rewards (BAT) | **REMOVE** | Medium |
| Brave Wallet | **REMOVE** | High |
| Web3 / crypto infrastructure (beyond Wallet) | **REMOVE** | High |
| Brave Talk | **REMOVE** | Low |
| Brave News / Brave Today | **REMOVE** | Low |
| Brave Playlist | **REMOVE** | Low |
| Sponsored images / promotional UI | **REMOVE** | Low |
| Affiliate / referral injection | **REMOVE** | Low |
| Brave VPN / Firewall + Premium | **REMOVE** | Medium |
| Brave Leo (built-in AI chat) | **REPLACE** | Medium |
| Brave Search default / search-with-Brave | **REPLACE** | Low |
| Brave Sync | **AUDIT LATER** | High |
| Brave Stats / P3A / usage ping | **REMOVE** | Medium |
| Crash reporting / breakpad | **AUDIT LATER** | High |
| Variations ("Griffin") | **REMOVE** | Medium |
| Brave services key + Safe Browsing config | **AUDIT LATER** | High |
| Tor / Private Window with Tor | **AUDIT LATER** | Medium |
| IPFS | **AUDIT LATER** | Low |
| Brave-hosted new tab page (sponsored/partner content) | **REPLACE** | Low |
| Brave-branded chrome UI, strings, icons | **REPLACE** | Low |
| Brave's update/telemetry endpoints in build config | **REMOVE** | Low |
| Updater (Sparkle/Brave updater) | **AUDIT LATER** | High |

---

## 2. Detailed entries

### 2.1 Ad blocking / Shields — **KEEP**

- **What it does.** Content and tracker blocking via `adblock-rust`, with
  per-site shields, cosmetic filtering, script blocking and fingerprinting
  protection.
- **Where it lives. [V]** `adblock-rust` is an external repo
  (`https://github.com/brave/adblock-rust`), linked through
  `brave/adblock-rust-ffi` at `components/adblock_rust_ffi`. Shields UI and
  integration live in brave-core's `components/brave_shields` and related
  browser-layer files. **[I]**
- **What depends on it.** Nearly every content-loading path consults shields.
  The rewards feature also hooks block counts — that coupling disappears with
  Rewards removal.
- **Fits Veil?** Yes. Tracking and ad blocking is a core privacy feature and one
  of the few Brave subsystems that is squarely aligned with Veil's purpose.
- **Disposition.** Keep. Retune defaults toward strict; disable any
  "acceptable ads"-style programme if one exists upstream.
- **Risk of removal.** N/A — we are keeping it. *Removing* it would be the risky
  act.

### 2.2 Brave Rewards (BAT) — **REMOVE**

- **What it does.** A cryptocurrency tipping and advertising-revenue-sharing
  system (Basic Attention Token). Includes a publisher verification pipeline,
  a rewards wallet, contribution flows, ad-reward claiming, and a
  background rewards service that talks to Brave-operated endpoints.
- **Where it lives. [I]** `components/brave_rewards/*`, `browser/brave_rewards/*`,
  `vendor/bat-native-*/`, Rewards panels/WebUI, and several GN targets and
  feature flags.
- **What depends on it.** The Rewards panel UI, parts of the new tab page,
  settings pages, the Brave ads pipeline, the Brave-configured endpoints in
  `package.json`/`.env`, and a set of bundled native BAT libraries.
- **Fits Veil?** No. Veil has no advertising, no cryptocurrency, no reward
  programme and no engagement incentives. This is the single largest mismatch
  with Veil's product direction.
- **Disposition.** Remove. Expect to remove the associated native libraries and
  build targets too, not just UI.
- **Risk of removal.** **Medium.** Rewards is woven through settings, the new tab
  page and the toolbar. Deletion must be staged: first disable by build
  flag/feature flag, then remove in whole-file units. Expect string resources
  and preferences to reference it after the feature is gone.

### 2.3 Brave Wallet — **REMOVE**

- **What it does.** A built-in multi-chain cryptocurrency wallet: key
  management, dApp provider injection (`window.ethereum`-style), transaction
  signing, swap/bridge integrations, NFT handling and a wallet panel.
- **Where it lives. [I]** `components/brave_wallet/*`, `browser/brave_wallet/*`,
  wallet WebUI resources, wallet page UI, and native dependency builds.
- **What depends on it.** Wallet page/panel, Web3 provider injection into pages,
  settings, and the wallet build targets. The provider injection path is a
  security-relevant surface that overlaps with Web3 features.
- **Fits Veil?** No. Veil is a developer/professional browser, not a crypto
  wallet, and does not want a page-visible signing surface.
- **Disposition.** Remove, including the injected provider.
- **Risk of removal.** **High.** Wallet is deeply integrated: build targets,
  resource bundles, settings section, and cross-references from other components.
  Do this after the build is proven working and after dependency tracing.

### 2.4 Web3 / crypto infrastructure beyond Wallet — **REMOVE**

- **What it does.** Blockchain RPC plumbing, ENS/UD resolution, NFT metadata,
  swap/bridge back-ends, and related preferences/UI.
- **Where it lives. [I]** `components/brave_wallet/*` (much of it shares the
  Wallet tree), plus `components/brave_ethabella`-era and NFT components in
  older layouts.
- **What depends on it.** Wallet, the new tab page, some settings pages.
- **Fits Veil?** No.
- **Disposition.** Remove alongside Wallet, as one workstream.
- **Risk of removal.** **High** — same coupling as Wallet. Treat as a single
  unit of work with Wallet rather than a separate effort.

### 2.5 Brave Talk — **REMOVE**

- **What it does.** Entry point to Brave's WebRTC video-calling service.
- **Where it lives. [I]** Toolbar/settings entries and a Brave-operated service
  endpoint; mostly a UI entry point plus a services key rather than heavy native
  code.
- **What depends on it.** Toolbar menu, settings, possibly new tab page.
- **Fits Veil?** No — it is an upsell into a Brave-hosted service.
- **Disposition.** Remove entry points; ensure no residual service endpoint is
  referenced.
- **Risk of removal.** **Low.**

### 2.6 Brave News / Brave Today — **REMOVE**

- **What it does.** A content-feed/suggested-reading system on the new tab
  page, fed by a Brave-operated news service with publisher/partner feeds and
  optional ads.
- **Where it lives. [I]** `components/brave_news/*`, new tab page feed surfaces,
  and a Brave news feed endpoint.
- **What depends on it.** New tab page; feed preferences; possibly the ads
  pipeline (news supports ad cards).
- **Fits Veil?** No. It is a content-promotion surface fed from Brave's servers.
- **Disposition.** Remove feature and its feed endpoint.
- **Risk of removal.** **Low** to **Medium** — new tab page integration needs
  care, especially if we simultaneously replace the new tab page.

### 2.7 Brave Playlist — **REMOVE**

- **What it does.** A media queue/playlist system with "add to playlist"
  affordances on pages, media detection, and an optional cloud sync of playlist
  items.
- **Where it lives. [I]** `components/brave_playlist/*`, playlist WebUI, media
  detection scripts, and a cloud sync backend reference.
- **What depends on it.** Playlist WebUI, content-script media detection,
  settings.
- **Fits Veil?** No.
- **Disposition.** Remove, including any cloud sync surface.
- **Risk of removal.** **Low.**

### 2.8 Sponsored images / promotional UI — **REMOVE**

- **What it does.** Sponsored new tab background images, promotional banners,
  "Brave" brand upsell surfaces, onboarding that pushes Brave services, and
  similar engagement/promotion machinery.
- **Where it lives. [I]** New tab page components, `brave_ads` sponsored-image
  path, and assorted promo components.
- **What depends on it.** New tab page; ads pipeline.
- **Fits Veil?** No. Veil has no advertising of any kind.
- **Disposition.** Remove. Highest-priority removal after the build is proven,
  because it is user-visible and directly contradicts the product promise.
- **Risk of removal.** **Low** individually; the ads pipeline behind sponsored
  images is shared with Rewards, so sequence this after Rewards.

### 2.9 Affiliate / referral injection — **REMOVE**

- **What it does.** Brave is a Chromium fork and at times has shipped affiliate
  or referral code paths (e.g. in the browser's upstream-origin story and
  partner integrations). Veil explicitly rejects this behaviour regardless of
  exact upstream state.
- **Where it lives. [I]** Search/partner integration points, upstream-origin
  branding files, and partner config.
- **What depends on it.** Search integration and default-partner configuration.
- **Fits Veil?** Absolutely not. Injecting affiliate parameters into user
  navigation is incompatible with the project's stated principles.
- **Disposition.** Remove or ensure it cannot be enabled. Verify during the
  privacy audit that no referral/affiliate parameter is appended to any
  navigation.
- **Risk of removal.** **Low.**

### 2.10 Brave VPN / Firewall + Premium — **REMOVE**

- **What it does.** A paid VPN service integration and a "Brave Premium"
  upsell/account surface, including purchase flows and account linking.
- **Where it lives. [I]** `components/brave_vpn/*`, purchase/account components,
  a Brave-operated VPN backend and credentials, plus a premium/preferences UI.
- **What depends on it.** Toolbar/settings entries, account surfaces.
- **Fits Veil?** No. It is a paid upstream service tied to Brave accounts.
- **Disposition.** Remove. (A future, provider-agnostic network-control story
  belongs to `security/`, designed by us — not inherited from Brave.)
- **Risk of removal.** **Medium** — account/purchase plumbing can be entangled
  with other premium surfaces.

### 2.11 Brave Leo (built-in AI chat) — **REPLACE**

- **What it does.** A built-in AI assistant/chat sidebar that can send page
  context to Brave-operated or third-party model providers, with a BYO-key
  option and a Brave-provided default path.
- **Where it lives. [I]** `components/ai_chat/*`, sidebar UI, and the
  `service_key_aichat` build-time credential. Note: brave-core's `package.json`
  contains an `ai-chat-shared-conversation-lib-dev` script **[V]**, confirming
  the subsystem's presence and its shared-conversation machinery.
- **What depends on it.** Sidebar, settings, and a build-time service key.
- **Fits Veil?** **Partially.** Veil wants agent/AI capability — but as an
  explicit, permissioned, provider-agnostic, inspectable interface, not as a
  bundled assistant with an upstream default provider and shared-conversation
  backend.
- **Disposition.** **REPLACE.** Not in Phase 0 (AI is explicitly out of scope).
  When the agent milestone arrives, it is designed by Veil, provider-agnostic,
  and routed through the permission layer. Upstream Leo is not the foundation
  for it.
- **Risk of removal.** **Medium** — it is a fairly self-contained sidebar
  subsystem, but removing it should not be rushed before the agent design
  exists, so that we delete it once, not twice.

### 2.12 Brave Search default / search-with-Brave — **REPLACE**

- **What it does.** Brave Search as the default search engine, plus
  "search with Brave" and a Brave-operated suggestions endpoint.
- **Where it lives. [I]** Search-engine configuration, search provider
  components, and the default search preference.
- **What depends on it.** The omnibox/address bar and the search suggestion
  provider.
- **Fits Veil?** The capability — a search field — is required. Brave's specific
  provider and its suggestion endpoint are a privacy question, not a given.
- **Disposition.** **REPLACE.** Veil ships with no vendor-default dependency it
  cannot explain. Decide the default search + suggestion provider as an explicit
  product decision; make search suggestions opt-in and local where possible.
- **Risk of removal.** **Low** technically.

### 2.13 Brave Sync — **AUDIT LATER**

- **What it does.** Cross-device synchronisation of bookmarks, history,
  passwords, tabs and settings, through a Brave-operated sync endpoint
  configured via the `brave_sync_endpoint` build flag.
- **Where it lives. [I]** `components/brave_sync/*`, sync service plumbing, and
  the build-time endpoint.
- **What depends on it.** Sync UI in settings, and the build-time
  `brave_sync_endpoint` value **[V]** (confirmed present in upstream's
  documented build flags).
- **Fits Veil?** Unknown yet. Sync is genuinely useful, but it is a
  data-egress feature and Veil's principle is that nothing leaves the machine
  unless the user explicitly chooses it. An encrypted, self-hostable or
  user-controlled sync story is plausible; inheriting Brave's is not
  automatically acceptable.
- **Disposition.** **AUDIT LATER.** Do not remove yet — it is self-contained
  enough to leave disabled while we decide. Remove or replace once the privacy
  model is settled.
- **Risk of removal.** **High** if entangled with prefs/accounts; low if simply
  left disabled.

### 2.14 Brave Stats / P3A / usage ping — **REMOVE**

- **What it does.** Upstream usage statistics: a "stats" ping with an install
  identifier and usage counters, plus P3A ("Privacy-Preserving Product
  Analytics") — a Brave-designed aggregate telemetry channel with a
  build-time API key and updater URL.
- **Where it lives. [I]** `components/p3a/*`, `components/brave_stats/*`, and
  the build flags `brave_stats_api_key` / `brave_stats_updater_url` **[V]**
  (confirmed present in upstream's documented build flags).
- **What depends on it.** The stats updater, the new tab page's "Brave stats"
  panel, and the build-time credentials.
- **Fits Veil?** No. Veil adds no telemetry, and upstream's telemetry is not an
  exception. The project rule is that upstream telemetry must be documented and
  classified, not silently inherited.
- **Disposition.** **REMOVE**, and ensure a Veil build carries no stats
  endpoint or key. Because Brave's stats credentials are injected at build time
  from `.env` and a Veil build supplies none, a Veil developer build should
  already be inert here — **but inert-by-omission is not the same as
  removed-by-design, and must be verified during the privacy audit.**
- **Risk of removal.** **Medium** — the cleanest path is confirming the feature
  is off/absent in a Veil-built binary rather than performing surgery now.

### 2.15 Crash reporting / breakpad — **AUDIT LATER**

- **What it does.** Crash capture and upload. In Chromium this is generally
  off-by-default outside official builds and depends on a configured crash
  service; Brave configures its own reporting story.
- **Where it lives. [I]** Chromium's `components/crash/*`, breakpad/crashpad
  dependencies, and Brave's crash configuration.
- **What depends on it.** Stability telemetry only.
- **Fits Veil?** Unclear. Veil wants **no automatic error uploads**, but a
  purely local crash dump (never uploaded) is a legitimate debugging aid.
- **Disposition.** **AUDIT LATER.** Do not remove blindly: crash handling is a
  stability-critical Chromium subsystem (project Rule 10 / Rule 8). Target state
  is *local-only, never auto-uploaded*.
- **Risk of removal.** **High** — removing it entirely can affect build
  configuration and debugging capability. Configure, don't delete.

### 2.16 Variations ("Griffin") — **REMOVE**

- **What it does.** Brave's server-driven feature-rollout/experimentation
  system, configured by `brave_variations_server_url`. It allows the browser's
  behaviour to be changed remotely after shipping.
- **Where it lives. [I]** `components/variations/*` in brave-core, plus the
  build-time variations URL **[V]** (documented in upstream's build flags; the
  subsystem is also documented in brave-core's `docs/griffin.md` **[V]**).
- **What depends on it.** Feature flags consumed across brave-core.
- **Fits Veil?** No. Remote reconfiguration of a privacy tool by a third party
  is a direct contradiction of "explicit about data movement" and
  "fully inspectable".
- **Disposition.** **REMOVE** as a server-driven system. Note that Chromium's
  own field-trial/variations machinery is a separate and much larger question
  and must not be conflated with Brave's.
- **Risk of removal.** **Medium** — features may read variation-driven defaults;
  removal must not silently change unrelated defaults. Verify flag by flag.

### 2.17 Brave services key + Safe Browsing configuration — **AUDIT LATER**

- **What it does.** Brave injects build-time credentials for Brave-operated
  services: `brave_services_key` / `brave_services_key_id`,
  `brave_google_api_key` / `brave_google_api_endpoint`,
  `safebrowsing_api_endpoint`, and the Google default client id/secret.
- **Where it lives. [V]** Documented in upstream's build-configuration wiki as
  `.env` values consumed at build time.
- **What depends on it.** Various Brave service calls; Safe Browsing depends on
  a Google API key (upstream README notes the optional `GOOGLE_API_KEY` env var
  to *enable* Safe Browsing **[V]**).
- **Fits Veil?** Safety features are valuable; calling a third-party endpoint
  with a vendor key, silently, is exactly what Veil must be explicit about.
- **Disposition.** **AUDIT LATER.** Decide Safe Browsing's fate as an explicit,
  documented, user-visible choice. Never inherit Brave's credentials.
- **Risk of removal.** **High** — do not remove security features by reflex. A
  Veil build without a Google API key has Safe Browsing disabled; that is a
  product decision to make openly, not accidentally.

### 2.18 Tor / Private Window with Tor — **AUDIT LATER**

- **What it does.** A private window mode routed through Tor via a bundled
  proxy configuration.
- **Where it lives. [I]** `components/tor/*`, private-window UI and proxy
  configuration.
- **What depends on it.** Private window modes, settings, some onboarding.
- **Fits Veil?** Plausibly — it is a privacy capability, not a monetisation
  one. But it is operationally sensitive (it changes the network model) and
  must be honestly represented.
- **Disposition.** **AUDIT LATER.** Likely keep or restage deliberately; never
  present it as a guarantee it does not provide.
- **Risk of removal.** **Medium.**

### 2.19 IPFS — **AUDIT LATER**

- **What it does.** Optional IPFS gateway support for `ipfs://` URIs.
- **Where it lives. [I]** `components/ipfs/*` and address-bar handling.
- **What depends on it.** Protocol handler registration only.
- **Fits Veil?** Marginal. It is a niche protocol that adds an outbound gateway
  dependency. For a developer-focused browser it is not obviously wrong.
- **Disposition.** **AUDIT LATER** — low priority either way; decide after the
  core browser surface is minimal.
- **Risk of removal.** **Low.**

### 2.20 Brave-hosted new tab page — **REPLACE**

- **What it does.** A new tab page that combines sponsored images, news feed,
  stats panels and Brave service entry points, with some content fetched from
  Brave servers.
- **Where it lives. [I]** `components/brave_new_tab_ui/*` and associated
  resource bundles.
- **What depends on it.** Nearly every promotional surface above.
- **Fits Veil?** A new tab page is expected. Brave's version is a promotion
  surface pointed at Brave's servers.
- **Disposition.** **REPLACE** — a minimal, local, Veil-owned new tab page with
  no remote content. This is where removing the promotional features
  above naturally converges.
- **Risk of removal.** **Low**, but it is the point where several removals
  intersect; do it once, deliberately.

### 2.21 Brave branding, strings and icons — **REPLACE**

- **What it does.** Product name, logos, icons, about-page strings, welcome
  flows and brand assets.
- **Where it lives. [I]** Resource bundles, `*.grd`/`*.grdp` files, icon sets,
  branding directories, and platform packaging metadata.
- **What depends on it.** Packaging, installer, about page, window titles.
- **Fits Veil?** Veil must present as Veil, not as Brave.
- **Disposition.** **REPLACE.** Staged: first remove misleading brand and
  service references (so we never ship something that looks official), then
  introduce Veil identity later. **Do not spend time on final visual identity in
  this phase.** See [branding.md](branding.md).
- **Risk of removal.** **Low** technically; **high** if done carelessly with
  respect to upstream licensing/attribution, which must be preserved (see
  [licensing.md](licensing.md)).

### 2.22 Brave-configured update / telemetry endpoints — **REMOVE**

- **What it does.** Build-time endpoints for Brave's stats, sync, variations
  and service keys.
- **Where it lives. [V]** The `.env` build-flag set documented upstream
  (`brave_stats_api_key`, `brave_stats_updater_url`, `brave_sync_endpoint`,
  `brave_variations_server_url`, `brave_services_key`, `brave_services_key_id`,
  `service_key_aichat`, `service_key_stt`, `email_aliases_api_key`, …).
- **What depends on it.** The corresponding features above.
- **Fits Veil?** No Veil build should carry Brave's endpoints or credentials.
- **Disposition.** **REMOVE** by construction: a Veil build's `.env` supplies
  none of these. `../.env.example` documents this deliberately.
- **Risk of removal.** **Low** — this is configuration, not code.

### 2.23 Updater — **AUDIT LATER**

- **What it does.** The mechanism that keeps the browser current, with platform
  variants (Windows updater, macOS Sparkle, Linux packaging).
- **Where it lives. [I]** Platform update components plus Brave's update
  service configuration.
- **What depends on it.** Security posture, release engineering.
- **Fits Veil?** Updates matter for security, but an auto-update channel is a
  network channel and a trust relationship. Veil must own that decision
  explicitly rather than inherit Brave's update story.
- **Disposition.** **AUDIT LATER.** Treat placing updates on our own
  infrastructure, or making them explicit/manual, as a first-class security
  decision.
- **Risk of removal.** **High.** Do not break the update path before an
  alternative exists.

---

## 3. Sequencing of removals (when we get there)

Removals are ordered to minimise rework and dependency damage:

1. **Prove the build first.** Nothing is removed before a stock upstream build
   compiles and launches. Otherwise removal bugs are indistinguishable from
   build-setup bugs.
2. **Configuration-level exclusion.** Clear the `.env` service keys/endpoints
   that a Veil build should never carry. Zero code risk.
3. **Feature-flag disable.** Turn off Promotional UI, Rewards, Rewards-adjacent
   ads, News, Talk, VPN, Playlist, variations. Reversible; produces no patches.
4. **UI-surface removal.** Remove toolbar/settings entry points and the
   Brave-hosted new tab page content.
5. **Whole-component deletion.** Rewards, Wallet/Web3, Playlist, News, VPN —
   in whole-file units, with dependency tracing before each.
6. **Replace.** New tab page, search defaults, branding, and (much later) the
   AI surface.

---

## 4. What Phase 0 does and does not do

**Does:**

- Classify every major Brave-specific area above.
- Record the intended disposition and the risks.
- Establish the principle that exclusion-by-configuration beats
  deletion-by-patch.
- Record the build-time credential set that a Veil build must not inherit.

**Does not:**

- Delete, disable or modify any Brave code.
- Attempt to trace component dependency graphs (no checkout exists).
- Ship a minimal browser — see [architecture.md](architecture.md) §5 for why the
  browser surface reduction comes *after* a working build.

---

## 5. Verification checklist for the removal phase

Before declaring any area removed:

- [ ] The pinned checkout was searched to confirm the real paths (all **[I]**
      entries re-marked as **[V]** or corrected).
- [ ] `gn` dependency trace completed for the component's targets.
- [ ] No dangling `.grd`/`.grdp` strings or preference registrations.
- [ ] No orphaned build targets in GN files.
- [ ] Browser builds.
- [ ] Browser launches.
- [ ] Normal browsing still works on real sites.
- [ ] No new outbound network requests appear (privacy audit re-run).
- [ ] The change is recorded as either a configuration change or a patch, per
      [upstream-strategy.md](upstream-strategy.md) §4.
