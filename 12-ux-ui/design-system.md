# Design System

> **Status:** 🟡 Living document — v0.4, 2026-09-15
> **Sources:** the four theme style manuals (light, dark, purple, green) extracted from
> `frontendTS/src/shared/constants/` on 2026-09-15 · SRS v2.0 § 3.1.1 and RNF9 · NFR-001
> **Applied in:** every mockup in `mockup/layout/`

The shared visual language of Traduce Señas. **Before creating a component, check whether it is here.**
Values marked **Adjusted** differ from the current code because the code value fails WCAG AA; the code
should adopt the adjusted value.

---

## 1. Principles

1. **Visual first.** The primary users are Deaf and hard-of-hearing people. No information depends on
   sound; audio is an extra, never a replacement for text (RNF9).
2. **Clarity over decoration.** Camera, sign and translation always have the highest hierarchy.
3. **Accent is scarce.** The accent colour marks actions and states, not large areas.
4. **Never colour alone.** Every state carries an icon or a word as well as a colour.
5. **Friendly shapes.** Rounded corners (12–18 px), soft tones, subtle motion that respects
   `prefers-reduced-motion`.

---

## 2. Themes

Two modes × two accents = four combinations. All four must pass § 8.

| | Value | Stored as |
|---|---|---|
| Mode | Light (default) · Dark | `@app_theme` in AsyncStorage |
| Accent | Purple (default, brand) · Green | `@app_color_accent` in AsyncStorage |
| Where | The whole app, **including public pages** (Adjusted: today they use a fixed `LandingTheme`) | — |

---

## 3. Colour tokens

### 3.1 Text and surfaces

| Token | Light · Purple | Light · Green | Dark · Purple | Dark · Green | Use |
|-------|----------------|---------------|---------------|--------------|-----|
| `text` | `#1F2937` | `#1F2937` | `#ECEAF5` | `#E9F0EB` | Titles and body |
| `text2` | `#4B5563` **Adjusted** (was `#6B7280`) | `#4B5563` | `#A9A4C0` | `#A2B6A9` | Secondary text, inactive tabs |
| `hint` | `#6B7280` **Adjusted** (was `#9CA3AF`, 2.54:1) | `#6B7280` | `#8B85A6` | `#87A091` | Placeholders only — never information |
| `bg` | `#FBFAFE` | `#F7FBF8` **Adjusted** (was lilac) | `#121019` | `#0E1610` | Page background |
| `surface` | `#FFFFFF` | `#FFFFFF` | `#211E2C` | `#1A251E` | Cards, sheets, bars |
| `input` | `#F3F4F6` | `#F3F4F6` | `#2A2637` | `#212E25` | Field fill |
| `border` | `#EEE9FA` | `#E3EFE8` **Adjusted** (was lilac) | `#332F43` | `#2C3B31` | Separators, card borders |
| `border-input` | `#E3DBF7` | `#CFE3D7` **Adjusted** (was lilac) | `#3B3650` | `#35473A` | Field border at rest |

### 3.2 Accent

| Token | Light · Purple | Light · Green | Dark · Purple | Dark · Green | Use |
|-------|----------------|---------------|---------------|--------------|-----|
| `primary` | `#9B77E6` | `#4CAF82` | `#AE90F0` | `#5FC894` | Focus ring, large icons, chart accents — not text |
| `link` | `#7E5AD0` **Adjusted** (was `#9B77E6`, 3.40:1) | `#23704A` **Adjusted** (was `#4CAF82`, 2.71:1) | `#C6ADF7` | `#8ADCB4` | Links, accent text, active tab |
| `action` | `#7E5AD0` **Adjusted** (was a light gradient, 1.93–2.74:1) | `#23704A` **Adjusted** | `#5B3FA8` **Adjusted** | `#1F6B47` **Adjusted** | Primary button fill, active switch |
| `primary-bg` | `#EDE9FE` | `#E8F5EE` | `#251F3D` | `#14301F` | Secondary button, chips, badges, icon plates |
| `primary-lighter` | `#C4B5FD` | `#A8D8BC` | `#5B4E86` | `#3E6B54` | Secondary button border |
| `toggle-off` | `#6B7280` **Adjusted** | `#6B7280` | `#7A7590` **Adjusted** | `#6F8A78` **Adjusted** | Switch off (≥ 3:1 against the surface) |

White text on `action`: 4.93:1 (light purple) · 6.0:1 (light green) · 7.72:1 (dark purple) · 6.46:1 (dark green).

### 3.3 Status

Status colours have a **text** token (for words and icons) and a **bg** token (for the alert fill).

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `success-text` / `success-bg` | `#047857` **Adjusted** (was `#10B981`, 2.54:1) / `#ECFDF5` | `#34D399` / `#12302A` | Done, saved, verified |
| `error-text` / `error-bg` | `#B91C1C` **Adjusted** (was `#EF4444`, 3.76:1) / `#FEF2F2` | `#F87171` / `#3A1D22` | Validation errors, failures |
| `warning-text` / `warning-bg` | `#92400E` **Adjusted** (was `#F59E0B`) / `#FFFBEB` | `#FBBF24` / `#33290F` | Low confidence, temporary lock |
| `info-text` / `info-bg` | `#1D4ED8` **Adjusted** (was `#3B82F6`) / `#EFF6FF` | `#60A5FA` / `#172554` | Neutral guidance |
| `danger` | `#B91C1C` **Adjusted** (was `#EF4444`, 3.76:1 with white) | `#B91C1C` | Destructive button fill |
| `overlay` | `rgba(0,0,0,.5)` | `rgba(8,6,14,.66)` | Behind dialogs |

---

## 4. Typography

**Family:** **Nunito Sans** (400 · 600 · 700 · 800), adopted in v0.2 from the Claude Design export
(§ 10), with the system font as fallback (SF Pro on iOS, Roboto on Android, `system-ui` on web). The
frontend still uses only the system font — `src/assets/fonts/` is empty — so the app has to load
Nunito Sans with `expo-font` to match the mockups.

| Style | Size / line height | Weight | Use |
|-------|--------------------|--------|-----|
| Display | 48 / 1.2 (34 on phones) | 800 | Web hero only |
| H1 | 32 / 1.2 | 800 | Screen or page title, translation result |
| H2 | 24 / 1.3 | 700 | Section title, dialog title |
| H3 | 20 / 1.35 | 700 | Card title, app header title |
| Body | **18 / 1.5 on mobile** · 16 / 1.5 on desktop | 400 | Running text |
| Button | 18 | 700 | Every button (**Adjusted**: was 15) |
| Label | 16 | 700 | Form labels, setting names |
| Small | 14 / 1.5 | 400–600 | Dates, hints. **Minimum size for any information** |

Rules: no justified text · no text below 14 px · the translation result is never smaller than 32 px.

---

## 5. Space, shape and layout

| Aspect | Value |
|--------|-------|
| Spacing scale | 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 72 |
| Side margins | 16 mobile · 24 tablet and desktop |
| Radius | 8 small · 12 buttons and fields · 18 cards · 22 sheets · 999 pills |
| Shadow | Card `0 3px 10px` at 7% (light); in dark mode separate surfaces with borders, not shadows |
| Touch target | **Minimum 48 × 48** for everything interactive; primary actions 56 high |
| Breakpoints | Mobile < 768 · Tablet 768–1023 · Desktop ≥ 1024 (**Adjusted**: the code uses seven different values). The mockups apply theirs at 640, 900 and 1200, where the export's fixed layout actually breaks (§ 10.6) |
| Content width | 1200 pages · 820 long reading · 560 forms |
| Grid | 4 columns mobile · 8 tablet · 12 desktop |

---

## 6. Components

### 6.1 Buttons

| Variant | Fill / border / text | When |
|---------|----------------------|------|
| Primary | `action` / — / white | The main action. **One per view** |
| Secondary | `primary-bg` / `primary-lighter` / `link` | Alternative actions |
| Outline | transparent / `link` / `link` | Secondary action on busy backgrounds |
| Ghost | transparent / — / `link` | Tertiary actions, "Cancelar" |
| Danger | `danger` / — / white | Confirming a destructive action inside a dialog |
| Danger ghost | transparent / `error-text` / `error-text` | Opening a destructive flow ("Eliminar cuenta") |
| Social | `surface` / `border-input` / `text` | Google and Facebook |

Sizes: 40 (small, inside cards) · 48 (default) · 56 (primary action of a screen). States: pressed scale
0.97 · disabled opacity 0.5 · loading shows a spinner **and** the verb in progress ("Ingresando…").

### 6.2 Form fields

- Label always visible above the field; the placeholder is an example, never the label.
- Height 48, radius 12, border 1.5 `border-input`, fill `input`. Focus: `primary` border and a 3 px ring.
- Error: message below the field with an alert icon, in `error-text`, **saying how to fix it**
  ("Escribe el correo de tu cuenta, por ejemplo nombre@correo.com"), never only "Campo inválido".
- Password: show/hide button; rules as a checklist with ✓ / ✗ icons and words, updated while typing.
- Verification code: six single-digit boxes, numeric keyboard.

### 6.3 Surfaces and selection

| Component | Spec |
|-----------|------|
| Card | `surface`, border 1 `border`, radius 18, padding 16 |
| Row | Min height 56, icon plate 44, label, optional badge, chevron |
| Chip | Height 44, pill; selected = `primary-bg` + bolder text (not colour alone) |
| Segmented control | Theme, accent, language, period; selected segment raised on `surface` |
| Switch | 56 × 34; on = `action`, off = `toggle-off`; always next to a visible label |
| Badge | Pill 14 px bold; neutral, success, warning, error variants, always with a word |
| Progress | Height 10, `action` fill, with the value also written as text |

### 6.4 Feedback

| Component | When | Duration |
|-----------|------|----------|
| Inline alert (icon + title + what to do) | Errors, warnings, confirmations | **Stays until the user acts or the state changes** |
| Field error | Validation | Until corrected |
| Dialog / bottom sheet | Destructive or irreversible actions, one-time notices | Until the user decides |
| Spinner inside the button | Operations > 200 ms started by a button | Until finished |
| Skeleton | Loading lists, grids, charts | Until loaded |
| Empty state (icon + title + reason + action) | A list with no data | — |

**No auto-dismissing toasts for errors.** A message that disappears after four seconds can be missed
by someone watching the signer instead of the screen.

### 6.5 Navigation

| Component | Spec |
|-----------|------|
| Tab bar (app) | Bottom, 56-high targets, icon + label always; active = `link` + `primary-bg` + heavier icon |
| App header | 64 high; brand plate or back button, H3 title, notifications bell with unread count |
| Site header (web) | Brand, nav with icon + label, "Ingresar" (outline) and "Registrarse" (primary); active item underlined |

### 6.6 Product-specific components

| Component | Spec |
|-----------|------|
| Camera view | 3:4 on phones, 4:3 on web. Dashed framing guide, "En vivo" tag, status bar at the bottom with icon + text |
| Result card | Label "Texto reconocido", result ≥ 32 px, confidence badge in words ("Confianza alta · 92%" / "Incierto · 54%"), progress bar, Escuchar / Copiar |
| Letter tile | Square, min 72, letter 28 px bold; opens a sheet with the 2D image, how-to text and previous/next |
| Sign image | Always with a text description available to screen readers (RNF9) |
| Notification card | Icon plate, title, message, time; unread = left bar **and** "Sin leer" badge |
| Achievement card | Unlocked: success badge with points and date. Locked: lock badge + progress "48 / 50". Secret: "?" plate |
| Bar chart | Values written above each bar and a text summary in `aria-label` |

### 6.7 Icons

Ionicons (`@expo/vector-icons`) in the code: outline by default, filled only for the active tab. Sizes
16 · 20 · 24 · 32. The mockups use the equivalent Lucide line icons, loaded from unpkg by the export
runtime; decorative ones carry `aria-hidden` and icon-only buttons carry an `aria-label` in Spanish.

---

## 7. UX patterns

| Situation | Pattern |
|-----------|---------|
| Camera permission | Ask in context, explaining why, before the system prompt; if denied, offer the settings and something else to do |
| Recognition uncertain | Show the result marked "Incierto" and ask to repeat, instead of hiding it |
| No connection | Persistent alert that says what is kept and what will sync |
| Destructive action | Dialog that names exactly what is lost; typing a word to confirm for account deletion |
| Sensitive answers | Password recovery shows the same confirmation whether or not the email exists |
| Empty state | Explain why it is empty and link to the action that fills it |
| Consent (RNF8) | Explicit, versioned, revocable; revoking never blocks translation |

---

## 8. Accessibility checklist (per screen)

A screen is not done until every line passes in the four themes (NFR-001, SRS RNF9).

- [ ] No information depends on sound; audio output keeps the text visible
- [ ] Text contrast ≥ 4.5:1; large text and UI components ≥ 3:1
- [ ] Every interactive element is at least 48 × 48
- [ ] Body text 18 px on mobile, nothing below 14 px
- [ ] No state communicated by colour alone
- [ ] Every field has a visible label; every icon-only button has an accessible name
- [ ] Errors explain how to fix them and stay visible
- [ ] Focus is visible and follows the visual order
- [ ] Images of signs have a text description
- [ ] Works with TalkBack and VoiceOver in the main flows (sign-in, translation, alphabet)
- [ ] Destructive actions ask for confirmation
- [ ] Animations respect `prefers-reduced-motion`

**Where the mockups stand.** The accessibility layer in § 10.5 covers contrast, focus, accessible names,
page titles, `role="alert"`, `aria-current`, minimum text size and reduced motion. Two lines are not met
yet: touch targets are raised to 44 px, not the 48 px this checklist asks for, and the screen-reader pass
with TalkBack and VoiceOver belongs to the app, not to a web mockup.

---

## 9. Adjustments the code needs

| Area | Today in `frontendTS` | This design system |
|------|-----------------------|--------------------|
| Primary button | White on a light gradient, 1.93–2.74:1 in light mode | Solid `action` |
| Links | `#9B77E6` / `#4CAF82` on white | `link` token |
| Status text | `#10B981`, `#EF4444` used as text | `*-text` tokens |
| Green accent | Inherits lilac borders and backgrounds; purple hover shadow | Own neutrals, no purple |
| Public pages | Fixed `LandingTheme` | Theme tokens |
| Type | Hand-written 12–15 px sizes everywhere; buttons 15 px | Scale in § 4 |
| Breakpoints | 380 · 480 · 600 · 640 · 768 · 900 · 1024 | 768 · 1024 |
| Brand name | "TraduceSeña" and "Traduce Señas" | "Traduce Señas" (pending team confirmation) |
| Unused images | `traducion-real.png` (duplicate), slides, `testimonial.jpg`, 5000 px `facebook.png` | Remove |

---

## 10. Brand identity and visual style

> **Source:** the Claude Design export "TraduceSeña landing page" (2026-09-15). **The export is the
> mockup set**: its pages were reorganised one folder per screen into `mockup/layout/`, with the shared
> runtime, theme, images, header and footer in `_shared/`. The visual design below is the export's; the
> repository adds an accessibility layer (§ 10.5), a narrow-screen layer (§ 10.6), the role-aware
> navigation bar and the content fixes in § 10.4. The export's runtime is kept, but every piece of it
> now lives in the repository, so the pages open with no server and no internet.

### 10.1 What was adopted

| Element | Spec in the mockups |
|---------|---------------------|
| Font | **Nunito Sans** 400 · 600 · 700 · 800 from Google Fonts, falling back to the system font. Replaces the system-font entry in § 4 |
| Logo | `icono-señas.png` (line-art hands) at 38 px on a 44 px tinted plate (`--plate`), always next to the brand name written as text, today "TraduceSeña" (UX-15). Inverted in dark mode |
| Primary button | 135° gradient from `action` to `action-2` with an accent shadow. **Adjusted:** both stops keep white text ≥ 4.5:1 (light purple `#7E5AD0 → #6D28D9`, light green `#23704A → #1B5E3D`, dark purple `#5B3FA8 → #4C2F96`, dark green `#1F6B47 → #185A3B`) |
| Section header | Eyebrow pill with an icon, H1 with the key words in `link`, short 48 × 3 accent rule |
| Backgrounds | Soft diagonal gradient `--hero-grad` behind hero areas; `--soft` for secondary surfaces |
| Image plates | Radius 20, accent shadow, floating white caption card with icon, title and subtitle |
| Inputs | Leading icon inside the field (mail, lock, key, user, calendar, search); the visible label stays above |
| Social login | Real Google and Facebook marks on neutral buttons, side by side |
| Stepper | Dots with the current step elongated, **always** paired with the text "Paso N de M" |
| Camera | Corner brackets instead of a dashed frame; "Cámara en vivo" card header with a status pill in words |
| Status pill | Dot + word ("Modelo activo", "En línea", "Apagada") — never the dot alone |

### 10.2 Tinted palette

Used for alphabet tiles, pillars, team cards and type pills. The badge on each tile is `ink` with white
text, which passes 4.5:1 in both modes.

| Tint | Tile (light) | Ink / badge | Icon in dark mode |
|------|--------------|-------------|-------------------|
| 1 · purple | `#EFEBFD` | `#6D28D9` | `#C4B5FD` |
| 2 · blue | `#E4EEFE` | `#1D4ED8` | `#93C5FD` |
| 3 · green | `#DCF5EA` | `#047857` | `#6EE7B7` |
| 4 · amber | `#FCF3D6` | `#92400E` | `#FCD34D` |
| 5 · pink | `#FCE3EC` | `#BE185D` | `#F9A8D4` |
| 6 · red | `#FDE4E4` | `#B91C1C` | `#FCA5A5` |

KPI tiles use four gradients with white text: accent (`action → action-2`), blue `#1D4ED8 → #1E40AF`,
teal `#047857 → #065F46`, amber `#B45309 → #92400E`.

### 10.3 Images

All of them live in `mockup/layout/_shared/assets/` and are referenced from there, not embedded.

| File | Mockup use |
|------|-----------|
| `comunicate-sinbarreras.png` | Landing hero |
| `traduccion-real.png` | Landing hero |
| `login.png` | Login banner |
| `icono-señas.png` · `icono.png` | Logo in the header, the login card and the footer |

These images appear to be **AI-generated illustrations** (one carries a generator watermark and shows
English text on a phone). They are fine for mockups; before any public release replace them with real
photographs taken with the consent of the people shown.

### 10.4 What was corrected in the export

| In the export | What the mockups do instead | Why |
|---------------|-----------------------------|-----|
| Alphabet of 27 letters with Ñ, admin chart with 28 symbols (Ñ and "5") | 26 letters, A–Z | Team decision, 2026-09-15 |
| White text on `#BE9EF4 → #D4C2F3` buttons | Gradient `#7E5AD0 → #6D28D9` | About 2:1 contrast; fails NFR-001 |
| `#9CA3AF` for subtitles and hints, `#EF4444` for error text | `#6B7280` and `#B91C1C` | Below 4.5:1 on white |
| "Estadísticas" in the user navigation | The bar is built from the role | ERF6.1: statistics are for the administrator only |
| The login sent **any** email to Estadísticas | The destination comes from `__tsHomeFor(email)` | Everyone looked like an administrator |
| "100% Pasión", "+1000 señas", "Nombre Apellido" | "ADSO · Programa SENA", "Texto y voz · en tiempo real", the real team names | Unsupported claims and placeholders |

**Still in the mockups, pending a team decision** (also recorded as gaps in `navigation-map.md` § 7):

| What | Why it is open |
|------|----------------|
| The brand reads "TraduceSeña" | The SRS says "Traduce Señas" (UX-15) |
| Contact `hola@traducesena.com`, `+57 300 123 4567`, social links | Not real channels |
| Four languages in the selector | The SRS mentions Spanish and English (UX-08) |
| Profile name locked for 30 days, avatar upload | Not required by the SRS |
| Statistics subtitle speaks of "tu progreso" | The page is administrator-only (UX-20) |

### 10.5 Accessibility layer

`_shared/a11y.css` and `_shared/a11y.js` load on every page. They do not change the structure: they sit
on top of the inline styles the export's runtime writes, so the design stays the export's.

| What | In the export | In the mockups |
|------|---------------|----------------|
| Primary button | White on light lilac, about 2:1 | Gradient `#7E5AD0 → #6D28D9`, at least 4.9:1 |
| Links and accent text | `#9B77E6`, 3.4:1 | `#7E5AD0`, 4.9:1 (green accent: `#23704A`) |
| Subtitles, dates, hints | `#9CA3AF` and similar, 2.5–3:1 | `#6B7280`, 4.8:1 |
| Red and green as text | `#EF4444`, `#10B981` | `#B91C1C`, `#047857` |
| Small text | 10–13 px | Minimum 14 px; body text 15 → 16 px |
| Keyboard focus | No indicator | 3 px ring |
| Touch targets | Buttons of 36–40 px | Minimum 44 px |
| Icon-only buttons | No name | `aria-label` in Spanish |
| Fields with no `label for` | No name | `aria-label` from the visible label; OTP boxes "Dígito N de 6" |
| Error messages | Loose text | `role="alert"` |
| Active navigation item | Colour only | `aria-current="page"` |
| Document | — | `lang="es"` and a "Ir al contenido" skip link |
| Page title | The 17 pages had no `<title>` | "Alfabeto \| TraduceSeña" and so on, one per screen (WCAG 2.4.2) |
| Heading | The translator had no heading at all | An `h1` for screen readers, hidden visually with `.a11y-only` |
| No JavaScript | Half a screen, with no explanation | A `noscript` notice, and a banner if the runtime does not start |
| Motion | — | Respects `prefers-reduced-motion` |

### 10.6 Narrow screens and offline

ERF2.1 asks for PC, tablet and phone. The export is a fixed desktop layout, so `_shared/responsive.css`
adds what it lacks, again without touching the structure.

| Width | What changes |
|-------|--------------|
| ≤ 1200 px | The navigation bar wraps and the menu takes its own line, instead of pushing the buttons off screen |
| ≤ 900 px | The login stacks, the footer goes from four columns to two, the indicator tiles from four to two and the alphabet from nine to five. Side margins drop to 24 px |
| ≤ 640 px | Everything goes to one column, the alphabet to four, side margins to 16 px, and headings from 50 px down to 34 |

Everything the page needs is in the repository, pinned by version, so a mockup opened next year renders
the same as today.

| In `_shared/` | Weight | Was |
|---------------|-------:|-----|
| `vendor/babel.min.js` | 3064 KB | unpkg, compiles the export's JSX in the browser |
| `vendor/lucide.min.js` | 429 KB | `lucide@latest`, which could change without notice. Now 1.46.0 |
| `vendor/react-dom.production.min.js` | 128 KB | unpkg |
| `vendor/react.production.min.js` | 10 KB | unpkg |
| `fonts/` | 268 KB | Nunito Sans from Google Fonts, five weights, latin subset |
| `assets/` | 241 KB | 6169 KB of PNG. The three photographs are now 760 px JPEG; the logos stay PNG |

One change was needed inside the export's runtime: it signed React and Babel with `integrity`, and a
browser cannot validate that signature over `file://`, so it refused the local copy and left the page
empty. The signature is now kept only while the address is `http` or `https`.

---

## Correlations

- Screens and flows that use these components → `navigation-map.md`
- Accessibility requirement → `04-requirements/non-functional.md` (NFR-001, NFR-009)
- Theme and language preferences as data → `06-data/domains/03-profile.md`

## Change log

| Version | Date | Change |
|---------|------|--------|
| v0.1 | 2026-09-15 | Template replaced with the real tokens of the four themes, type scale, components and patterns. Contrast failures of the current code corrected as **Adjusted** values |
| v0.2 | 2026-09-15 | § 10 added: brand identity taken from the Claude Design export (Nunito Sans, logo, gradients, tinted palette, image plates, stepper), contrast-corrected, with the list of what was rejected |
| v0.4 | 2026-09-15 | § 10.6 added: the runtime, the icons, the typeface and the images move into the repository pinned by version, the images drop to 241 KB, and the narrow-screen layer covers 1200, 900 and 640 px. § 10.5 gains page titles, the translator heading and the failure notices |
| v0.3 | 2026-09-15 | The export became the mockup set in `mockup/layout/`. § 10 rewritten: it is no longer a visual reference; § 10.4 now separates what was corrected from what is still open; § 10.5 added with the accessibility layer; icons are Lucide and images are files in `_shared/assets/` |
