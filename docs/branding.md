# Branding

Veil is its own product. It is **not** the Brave Browser, is not affiliated with
Brave Software, and must never be presented as official Brave software.

This document records the naming decision, how branding is handled while the
foundation is still upstream, and the trademark questions that must be resolved
before any public release.

> **Phase 0 note.** No final visual identity work is in scope. The only branding
> requirement today is that we do not *misrepresent* the product. Designing
> Veil's identity comes later — see [architecture.md](architecture.md) §5,
> step 3.

---

## 1. Current naming

| Item | Value |
| --- | --- |
| **Product name** | Veil |
| **Repository** | `veil-browser` |
| **Status** | Working name |
| **Trademark search performed?** | **No** |
| **Visual identity designed?** | No |
| **Logo / icon set** | None |

"Veil" is chosen for the product's purpose: a browser that keeps what happens on
the user's machine under the user's control. It is short, pronounceable, and has
no crypto/ads/AI-vendor connotation.

**It is a working name, not a cleared mark.** A trademark search must be done
before any public release or distributable binary. If the name is unavailable,
it changes here and nowhere else that matters — the repository name is the one
irreversible artifact and can be renamed on GitHub if necessary.

---

## 2. Present state: upstream branding is still visible

Because Phase 0 does not modify the browser, a Veil build made from the current
pinned upstream **still looks and behaves like Brave** — name, icons, about
page, strings, installer metadata and all. This is expected and acceptable *only*
while no binary is distributed.

The rule that follows from this:

> **A Veil build must not be distributed to anyone, under any name, while it
> still presents itself as Brave.**

Shipping a binary that says "Brave" while calling it "Veil" is the specific
failure this document exists to prevent.

---

## 3. Branding inventory

The following upstream branding surfaces exist in the foundation. Each will need
to be addressed before a distributable binary.

| Surface | Where it appears | Treatment |
| --- | --- | --- |
| Product name (window title, menus, about) | Resource bundles, `*.grd`/`*.grdp`, app metadata | **Replace** |
| Application icons | Icon sets, platform packaging resources | **Replace** |
| Installer / packaging metadata | Windows installer config, macOS bundle, Linux desktop entries | **Replace** |
| About page and version strings | About/credits WebUI | **Replace** |
| Welcome / first-run flow | Onboarding WebUI | **Replace** |
| New tab page branding | New tab page resources | **Replace** (converges with the new tab page replacement) |
| Default search branding | Search provider config | **Replace** (see [brave-customization-plan.md](brave-customization-plan.md) §2.12) |
| Error pages / internal pages branding | Internal page resources | **Replace** |
| Brave service names in settings | Settings WebUI | **Remove** (features removed → surfaces removed) |
| Brave-hosted promotional surfaces | New tab page, toolbar | **Remove** |
| **License and copyright notices** | Throughout source | **Preserve — never replace** |
| **Chromium/third-party attribution / credits** | Credits surface | **Preserve** |

The last two rows are the important ones. **Branding is replaced; attribution is
not.** License notices and copyright headers are not branding and must survive
every rebrand. See [licensing.md](licensing.md) §4.

---

## 4. What Veil will *not* do

- Will not use the Brave name, logo, or brand assets as Veil's product identity.
- Will not describe Veil as "Brave-based" in a way that implies endorsement,
  partnership, or official status. It is accurate to say Veil is built on the
  Chromium and Brave open-source foundations — and it must be said as a factual
  dependency, not as an affiliation.
- Will not use Chromium or Google Chrome marks to imply endorsement.
- Will not strip upstream copyright or license notices under the banner of
  "rebranding".
- Will not spend Phase 0 effort on final visual design.

---

## 5. How to describe Veil accurately

Correct:

> Veil is an open-source browser built on the Chromium and Brave (brave-core)
> open-source foundations, with its own product direction. It is not affiliated
> with Brave Software.

Incorrect:

> Veil is Brave.
> Veil is made by Brave.
> Veil is an official Brave product.
> Veil is a Brave-supported fork.

The distinction matters both legally and as a matter of not confusing users.

---

## 6. Path to a Veil identity

Staged, and deliberately **not** Phase 0 work:

1. **Nothing misleading.** Remove or neutralise Brave service/promotional
   references so a build never reads as official Brave software. *(Safety
   requirement, not a design task.)*
2. **Functional neutrality.** Replace the name and icons with neutral
   placeholders so the product is identifiable as Veil rather than misrepresented
   as Brave.
3. **Identity.** Name confirmed, mark cleared, icon set and typography designed,
   installer and about-page presentation finalised.

Until step 1 is complete, no Veil build leaves the machine.

---

## 7. Open items

1. **Trademark search for "Veil"** — not performed.
2. Confirm the final product name; the repository name can be renamed, but the
   decision should be made before any distribution.
3. Confirm whether a distinct binary/product identifier is required per platform
   (Windows app id, macOS bundle id, Linux desktop entry) and whether the
   existing upstream identifier can be reused during development.
4. Decide how Veil describes its upstream dependency publicly — accurate and
   non-implying, per §5.
5. Icon/identity design — deferred.
