# 12 — UX/UI

> **Status:** 🟡 Living document — v0.4, 2026-09-15
> **What is this?** How Traduce Señas looks, how it is navigated and how each screen behaves,
> designed before it is built.

---

## ⚠️ Read this first

- **There is no backend yet.** Screens are delivered as static HTML mockups in `mockup/layout/`.
  `mvp/` stays empty until a backend exists and screens can work with real data.
- **The mockups are the Claude Design export**, reorganised one folder per screen and with an
  accessibility layer on top. The visual design is the export's; nothing was redrawn by hand.
  What the export got wrong and what was corrected is in `design-system.md` § 10.
- **The SRS v2.0 (2026) decides which screens exist.** Where the SRS, the user stories in
  `04-requirements/` and the current frontend (`frontendTS`) disagree, the gap is recorded in
  `navigation-map.md` § 7 instead of being resolved silently.
- **Colours come from the code, corrected where they fail accessibility.** See `design-system.md` § 9.

---

## Structure

```
12-ux-ui/
├── README.md               ← you are here
├── navigation-map.md    ⭐ screens, requirement per screen, roles, flows, gaps
├── design-system.md        tokens for the four themes, type, components, accessibility checklist
├── mockup/
│   ├── build-from-export.ps1  regenerates layout/ from the Claude Design export
│   ├── verify-layout.ps1   checks links, roles, titles and dependencies without opening a browser
│   └── layout/
│       ├── _shared/        runtime, theme, header and footer, images, session,
│       │   │               accessibility layer, narrow-screen layer
│       │   ├── vendor/     React, Babel and Lucide, pinned by version
│       │   └── fonts/      Nunito Sans, latin subset
│       └── <screen>/       index.html — one folder per screen (17)
└── mvp/                    empty until the backend exists
```

### Screens in `mockup/layout/`

| Group | Folders |
|-------|---------|
| Public web | `view-landing` · `view-about-us` · `try-translator-demo` · `try-alphabet-demo` |
| Access | `sign-in` · `register-account` · `recover-password` · `view-terms` · `view-privacy-policy` |
| User | `translate-signs` · `view-alphabet` · `view-translation-history` · `manage-profile` · `change-password` |
| Administrator | `view-usage-statistics` · `view-admin-dashboard` · `train-recognition-model` |

`navigation-map.md` § 2 lists 21 screens; these are the 17 that have a mockup. `verify-code` and
`set-new-password` are drawn inside `recover-password`, which is a three-step flow on a single page.
`view-notifications` (RF4) and `view-achievements` (RF8) are specified but not drawn yet.

---

## How to use the mockups

1. Open any `mockup/layout/<screen>/index.html` in a browser. **No server and no internet are needed.**
   React, Babel, the Lucide icons and Nunito Sans live in `_shared/vendor/` and `_shared/fonts/`, each
   pinned to a version. If a page cannot start, it says so in a red banner instead of showing half a
   screen, and with JavaScript disabled it says that too.
2. Header and footer are export components (`_shared/SiteHeader.dc.html`, `_shared/SiteFooter.dc.html`).
   The runtime would fetch them, which browsers block on local files, so every page carries them
   embedded as `data:` URIs in `window.__resources`.
3. Links and bars navigate between pages, so the flows in `navigation-map.md` § 5 can be clicked through.
4. **The navigation bar depends on who is logged in.** `_shared/session.js` decides the role from the
   email, with the same list as `frontendTS/src/shared/utils/adminAccess.ts`:

   | Sign in with | Lands on | Sees in the bar |
   |--------------|----------|-----------------|
   | `aleosea777@gmail.com` | Estadísticas | Estadísticas · Admin |
   | Any other email | Traductor | Traductor · Alfabeto · Historial |

   Typing the address of a section that does not belong to your role shows a permission notice instead
   of the content. **With no session started every page shows normally**, so the design can be reviewed
   without going through the login. "Cerrar sesión" in Perfil ends the session.
5. Theme and accent are kept in `localStorage` under `ts-prefs`: the moon button in the header switches
   light and dark, and the choice is remembered across pages.
6. The pages fit narrow screens. `_shared/responsive.css` stacks the grids and wraps the navigation bar
   at 1200, 900 and 640 pixels. Checked with no horizontal overflow on all 17 screens down to 500 px.

### Rebuilding and checking

```powershell
powershell -ExecutionPolicy Bypass -File mockup\build-from-export.ps1 -Src <export folder>
powershell -ExecutionPolicy Bypass -File mockup\verify-layout.ps1
```

The build script regenerates the 17 pages from the export and reapplies every change the repository
adds: local runtime, accessibility, narrow screens, roles and the content fixes. The verification
script checks titles, language, links, shared files, role guards, image alternative text and that no
page asks the network for anything. It returns a non-zero exit code, so it can run in CI.

### Conventions for a new mockup

| Rule | Detail |
|------|--------|
| One folder per screen | Named after the user action, `kebab-case`, English (ADR-001): `translate-signs/` |
| One file | `index.html`; everything shared (runtime, theme, images, header, footer) lives in `_shared/` |
| Same runtime | A new screen is exported from Claude Design and added to `build-from-export.ps1`, not hand-written |
| Nothing from the network | Every script, font and image comes from `_shared/`; `verify-layout.ps1` fails otherwise |
| Tokens only | Colours and sizes from `design-system.md`; no new hex values |
| Accessibility | `_shared/a11y.css` and `_shared/a11y.js` load on every page and must not be bypassed |
| Role | The page declares who it is for with `__tsGuardRole`, using `user` or `admin` |
| Traceability | `navigation-map.md` § 2 gets a row naming the requirement |
| Done | Passes the checklist in `design-system.md` § 8 in light and dark mode |

---

## Current state

| Item | State |
|------|-------|
| `navigation-map.md` | ✅ v0.3 — 21 screens (18 in the frontend, 3 new), 20 recorded gaps |
| `design-system.md` | ✅ v0.4 — four themes, contrast-adjusted, brand identity (§ 10) |
| `mockup/layout/` | ✅ 17 screens from the Claude Design export, accessible, role-aware, offline, checked in light and dark mode and down to 500 px |
| `mockup/layout/` — missing | ⏸ `view-notifications` and `view-achievements` have no mockup yet |
| `mockup/verify-layout.ps1` | ✅ 17 pages, 0 problems |
| `mvp/` | ⏸ Waiting for the backend |

### Decisions taken in this version

| Date | Decision |
|------|----------|
| 2026-09-15 | The sign alphabet has **26 letters, A–Z, without Ñ**. SRS ERF7.1 must be corrected |
| 2026-09-15 | Screens are delivered as HTML mockups first; the MVP comes after the backend |
| 2026-09-15 | Lexicon and linguist screens are not designed: the SRS v2.0 does not require them |
| 2026-09-15 | **Roles in the navigation bar:** the administrator sees **only Estadísticas and Administración**; a regular user sees Traducción, Alfabeto and Historial and neither of those two (ERF6.1). Perfil is reachable by both |
| 2026-09-15 | **The Claude Design export is the mockup set**, kept in the repository as `mockup/layout/` with an accessibility layer on top, instead of being copied by hand into self-contained pages |
| 2026-09-15 | **Nothing is fetched from the network.** The runtime, the icons and the typeface are copied into `_shared/` and pinned by version, so a mockup opened later renders the same as today |

---

## Correlations with other sections

| Fed by… | Feeds… |
|---------|--------|
| SRS v2.0 § 3.1.1 (user interfaces), RF1–RF8, RNF8, RNF9 | The screens in `mockup/layout/` |
| `04-requirements/user-stories.md` — acceptance criteria | The states shown in each mockup |
| `04-requirements/non-functional.md` — NFR-001, NFR-009 | `design-system.md` § 8 |
| `06-data/domains/` — the fields each screen shows | `07-api/` — the data each screen will ask the backend for |

---

## Questions this section answers

- How many screens are there, and which requirement justifies each one? → `navigation-map.md` § 2
- What can a visitor, a user and an administrator reach? → `navigation-map.md` § 4
- What does the product look like in each theme? → `design-system.md` and the mockups
- What still disagrees between the SRS and the frontend? → `navigation-map.md` § 7

---

## Change log

| Version | Date | Change |
|---------|------|--------|
| v0.1 | 2026-09-15 | Scaffold template replaced with project content: mockup/MVP structure, 21 HTML mockups, navigation map and design system built from the SRS v2.0, the style manuals and `frontendTS` |
| v0.2 | 2026-09-15 | Mockups polished with the visual identity of the Claude Design export: Nunito Sans, real logo and images, gradients, tinted tiles, stepper, colour KPI tiles |
| v0.4 | 2026-09-15 | The mockups stop depending on the network and on a desktop screen: React, Babel, Lucide and Nunito Sans move into `_shared/` pinned by version, the images drop from 6169 KB to 241 KB, every page gets a title and a failure notice, `_shared/responsive.css` handles 1200, 900 and 640 pixels, and the build and verification scripts move into the repository |
| v0.3 | 2026-09-15 | The hand-built mockups are replaced by the Claude Design export itself: 17 screens in `mockup/layout/` with `_shared/`, an accessibility layer (NFR-001) and a role-aware navigation bar. Four screens lose their mockup: `verify-code` and `set-new-password` are now steps inside `recover-password`; `view-notifications` and `view-achievements` are still to be drawn |
