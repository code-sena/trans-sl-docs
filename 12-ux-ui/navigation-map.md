# Navigation Map

> **Status:** 🟡 Living document — v0.3, 2026-09-15
> **Sources:** SRS v2.0 (2026) · `frontendTS/src/app/routes/` · `04-requirements/user-stories.md`
> **Mockups:** 18 of the 21 screens below have their HTML in `mockup/layout/<folder>/index.html`

Defines every screen of Traduce Señas, how the screens connect, who can reach each one and which
requirement justifies it. When a screen is added, removed or renamed, this file changes in the same PR.

---

## 1. Entry points

| Platform | First screen | Why |
|----------|--------------|-----|
| Web | `view-landing` | The public pages (landing, about us, demos) only exist on web |
| Android / iOS | `sign-in` | The app opens directly on the login screen; public pages are not registered on mobile |

After a successful login the app shows the tab bar. **The tabs depend on the role** (§ 4).

---

## 2. Screen inventory

**21 screens:** 18 already exist in the frontend, 3 are required by the SRS and do not exist yet (🆕).

| # | Mockup folder | Screen (UI name) | Frontend component | Requirement | Access | Platform | Frontend |
|---|---------------|------------------|--------------------|-------------|--------|----------|----------|
| 1 | `view-landing` | Inicio | `LandingScreen` | RF2 · ERF2.1 | Visitor | Web | ✅ |
| 2 | `view-about-us` | Nosotros | `NosotrosScreen` | — (informative page) | Visitor | Web | ✅ |
| 3 | `try-translator-demo` | Demo del traductor | `TranslatorDemoScreen` | RF3 (public demo) | Visitor | Web | ✅ |
| 4 | `try-alphabet-demo` | Demo del alfabeto | `AlphabetDemoScreen` | RF7 (public demo) | Visitor | Web | ✅ |
| 5 | `sign-in` | Ingresar | `LoginScreen` | RF1 · ERF1.2 | Visitor | Web · Mobile | ✅ |
| 6 | `register-account` | Crear cuenta | `RegisterScreen` | RF1 · ERF1.1 | Visitor | Web · Mobile | ✅ |
| 7 | `verify-code` | Verificar código | `VerifyCodeScreen` | RF1 · ERF1.1, ERF1.3 | Visitor | Web · Mobile | ✅ |
| 8 | `recover-password` | Recuperar contraseña | `ForgotPasswordScreen` | RF1 · ERF1.3 | Visitor | Web · Mobile | ✅ |
| 9 | `set-new-password` | Nueva contraseña | `NewPasswordScreen` | RF1 · ERF1.3 | Visitor | Web · Mobile | ✅ |
| 10 | `view-terms` | Términos y condiciones | `TermsScreen` | RF1 · ERF1.1 | Everyone | Web · Mobile | ✅ |
| 11 | `view-privacy-policy` | Política de privacidad | `PrivacyPolicyScreen` | — (RNF8) | Everyone | Web · Mobile | ✅ |
| 12 | `translate-signs` | Traducción | `TranslationScreen` | RF3 · ERF3.1, ERF3.2 | User | Web · Mobile | ✅ |
| 13 | `view-alphabet` | Alfabeto | `AlphabetScreen` | RF7 · ERF7.1 | User | Web · Mobile | ✅ |
| 14 | `view-translation-history` | Historial | `HistoryScreen` | RF5 · ERF5.5 | User | Web · Mobile | ✅ |
| 15 | `manage-profile` | Perfil | `ProfileScreen` | RF5 · ERF5.1, ERF5.2, ERF5.4 | User · Admin | Web · Mobile | ✅ |
| 16 | `change-password` | Cambiar contraseña | — | RF5 · ERF5.3 | User · Admin | Web · Mobile | 🆕 |
| 17 | `view-notifications` | Notificaciones | — | RF4 · ERF4.1 | User | Web · Mobile | 🆕 |
| 18 | `view-achievements` | Mis logros | — | RF8 · ERF8.1, ERF8.2 | User | Web · Mobile | 🆕 · dibujado |
| 19 | `view-usage-statistics` | Estadísticas | `StatsScreen` | RF6 · ERF6.1 | Admin | Web · Mobile | ✅ |
| 20 | `view-admin-dashboard` | Administración | `AdminDashboardScreen` | — | Admin | Web · Mobile | ✅ |
| 21 | `train-recognition-model` | Entrenar la IA | `AdminTrainingScreen` | — (supports RF3, RNF8) | Admin | Web · Mobile | ✅ |

> **RF2 · ERF2.1 (navigation bar) applies to every screen**, not only to the landing: the SRS requires the
> bar to be visible on all pages and to work on PC, tablet and phone.

**Which screens have a mockup.** 18 of the 21 have their own folder in `mockup/layout/`. The three that
do not:

| # | Screen | Where it is instead |
|---|--------|---------------------|
| 7 | `verify-code` | Step 2 of `recover-password`, which is a single page with three steps |
| 9 | `set-new-password` | Step 3 of the same page |
| 17 | `view-notifications` | Not drawn yet — RF4 · ERF4.1 still needs a mockup |

---

## 3. Navigation tree

```
Web only (visitor)
├── view-landing ─────────┬── try-translator-demo
│                         ├── try-alphabet-demo
│                         ├── view-about-us
│                         ├── sign-in
│                         └── register-account
│
Access (visitor, web + mobile)
├── sign-in ──────────────┬── recover-password ── verify-code ── set-new-password ── sign-in
│                         ├── register-account ── verify-code ── translate-signs
│                         ├── view-terms
│                         └── view-privacy-policy
│
Tabs · role USER
├── [Traducción] translate-signs
├── [Alfabeto]   view-alphabet
├── [Historial]  view-translation-history
├── [Perfil]     manage-profile ──┬── change-password
│                                 ├── view-achievements
│                                 ├── view-notifications
│                                 ├── view-terms
│                                 └── view-privacy-policy
└── (header bell, every tab) ── view-notifications
│
Tabs · role ADMIN
├── [Estadística] view-usage-statistics
├── [Admin]       view-admin-dashboard ── train-recognition-model
└── [Perfil]      manage-profile
```

---

## 4. Access matrix

| Screen | Visitor (web) | User | Admin |
|--------|:-------------:|:----:|:-----:|
| `view-landing`, `view-about-us`, demos | ✅ | ➖ redirected to tabs | ➖ redirected to tabs |
| `sign-in`, `register-account`, `verify-code`, `recover-password`, `set-new-password` | ✅ | ➖ | ➖ |
| `view-terms`, `view-privacy-policy` | ✅ | ✅ | ✅ |
| `translate-signs`, `view-alphabet`, `view-translation-history` | ❌ | ✅ | ❌ decided, UX-03 |
| `manage-profile`, `change-password` | ❌ | ✅ | ✅ |
| `view-notifications`, `view-achievements` | ❌ | ✅ | ❌ |
| `view-usage-statistics`, `view-admin-dashboard`, `train-recognition-model` | ❌ | ❌ | ✅ |

✅ allowed · ❌ not reachable · ➖ not shown while a session is open

---

## 5. Main flows

### 5.1 Registration — ERF1.1 · HU-IAM-001, HU-IAM-002

```
register-account ──► verify-code ──► translate-signs
      │                  ├── wrong code ──► error, 3 attempts left
      │                  └── expired    ──► "Enviar código nuevo"
      ├── terms not accepted ──► inline error, account not created
      └── email already used ──► warning + link to sign-in
```

Two screens from start to verified account (NFR-009 allows up to four). Google or Facebook skip
`verify-code`: the account is born active.

### 5.2 Sign in — ERF1.2 · RNF4 · HU-IAM-003, HU-IAM-004

```
sign-in ──► translate-signs (user) / view-usage-statistics (admin)
   ├── wrong credentials ──► error alert
   ├── 3 failures        ──► temporary lock 1 → 5 → 10 min (countdown shown)
   ├── ladder exhausted  ──► account blocked, contact the administrator
   └── email not verified ─► info alert + "Ingresar el código" ──► verify-code
```

### 5.3 Password recovery — ERF1.3 · HU-IAM-006

```
recover-password ──► verify-code ──► set-new-password ──► sign-in
```

The confirmation is identical whether or not the email exists, so the screen cannot be used to discover
registered accounts.

### 5.4 Change password — ERF5.3

```
manage-profile ──► change-password ──► manage-profile
                        └── wrong current password ──► inline error + link to recover-password
```

### 5.5 Translation — RF3 · ERF3.1, ERF3.2 · HU-TRA-001, HU-TRA-004

```
translate-signs
  ├── no permission yet ──► explain why ──► system prompt
  │                              └── denied ──► "Abrir ajustes" + link to view-alphabet
  └── camera ready ──► Iniciar cámara ──► recognising
          ├── recognised     ──► text + confidence + Escuchar/Copiar ──► saved to history
          ├── low confidence ──► result marked "Incierto" + repeat hint
          ├── no hands       ──► framing tips
          └── offline        ──► error alert; produced text kept and synced later
```

The text always stays on screen while audio plays (ERF3.2, RNF9).

### 5.6 Notifications and achievements — RF4, RF8

```
any tab ── bell (unread count) ──► view-notifications ── tap a card ──► the screen it refers to
achievement unlocked ──► one-time dialog ──► view-achievements
```

With notifications switched off, the achievement still unlocks; only the notice is skipped (ERF8.2).

---

## 6. Navigation rules

| Rule | Behaviour |
|------|-----------|
| Session | Without a session only the visitor screens are reachable; any private screen goes to `sign-in` |
| Session expired | Back to `sign-in` with the message "Tu sesión terminó. Ingresa de nuevo." |
| Role | Admin screens are not rendered for a user, and user tabs are not rendered for an admin |
| Navigation bar | Visible on every private screen (ERF2.1). Secondary screens keep the bar and add a back button |
| No dead ends | Every screen offers a way back or forward; empty states include the action that fills them |
| Destructive actions | Delete history entry, delete account, replace dataset, clear training: always a confirmation dialog that names what is lost |
| Feedback | Every alert is visual and stays until the user acts or the state changes; nothing depends on sound (RNF9) |

---

## 7. Gaps between the SRS, the stories and the frontend

Recorded so they are decided, not rediscovered. Owner: whoever takes the matching story.

| ID | Gap | Proposed action |
|----|-----|-----------------|
| UX-01 | **Alphabet has 26 letters (A–Z, no Ñ)** — team decision, 2026-09-15. SRS ERF7.1 still says 27 with Ñ. The training list in `AdminTrainingScreen` / `AdminDashboardScreen` adds an extra `'5'` | Correct ERF7.1 in the SRS; remove `'5'` from the letter list |
| UX-02 | The admin is detected by a hard-coded email (`shared/utils/adminAccess.ts`), not by roles | Replace with the role model of RF1 / HU-AUTHZ-001 when the backend exists |
| UX-03 | ✅ **Decided 2026-09-15:** signing in with the administrator email shows **only Estadísticas and Administración** — no Traducción, Alfabeto or Historial — and a regular user never sees those two. Matches `MainTabNavigator` and ERF6.1 | Applied in both mockup sets. When roles replace the hard-coded email (UX-02), the bar is built from the role |
| UX-04 | "Cambiar contraseña" in the profile reuses the recovery flow (`ForgotPassword` with `fromProfile`). ERF5.3 asks for current + new + confirmation | Build `change-password` as in the mockup |
| UX-05 | No notifications screen; the switch in the profile is local state and is not saved | Build `view-notifications`; persist the switch (HU-PROF-005) |
| UX-06 | ✅ **Resolved:** `view-achievements` drawn in `mockup/layout/view-achievements` (RF8 · ERF8.1, ERF8.2): unlocked vs locked with progress, empty and error states, one-time unlock dialog; unlocking works with notifications off | Build it in the app. Closing GAP-01 in `04-requirements/` still needs the RF8 decision |
| UX-07 | Statistics use fixed sample data and have no date or activity filter (ERF6.1) | Add both filters; connect to real data with the backend |
| UX-08 | The frontend ships four languages (es, en, fr, pt); the SRS and HU-PROF-004 mention Spanish and English | Decide whether fr and pt stay |
| UX-09 | Public pages use `LandingTheme`, fixed light purple: they ignore dark mode and the green accent | Move them to the theme tokens, as the mockups do |
| UX-10 | Low-confidence threshold: 0.70 in `TranslationScreen`, 0.60 in HU-TRA-004 | Pick one and write it in the story |
| UX-11 | Text → sign is out of scope, but `feature/readme.md` still describes it and `es.ts` keeps `modeText`, "Texto → Seña" and "Voz → Seña" | Remove the leftovers |
| UX-12 | `NosotrosScreen` shows "Nombre Apellido" placeholders, says "26 letras" next to a "100% Pasión" stat, and its "Conócenos" button opens Register | Real names and a button label that matches its destination, as in the mockup |
| UX-13 | Three screens have no functional requirement: `view-about-us`, `view-admin-dashboard`, `train-recognition-model` | Add a requirement to the SRS or accept them as support screens |
| UX-14 | The lexicon stories (HU-LEX-001 to 003) and the LSC linguist role exist in `04-requirements/` but not in the SRS nor in any screen | Align `04-requirements/` with the SRS v2.0 |
| UX-15 | The brand is written "TraduceSeña" (`es.ts`, headers, and now the mockups) and "Traduce Señas" (`app.json`, SRS) | The team picks one name; the mockups then follow it |
| UX-16 | RNF8 requires express, revocable consent for training samples; neither the frontend nor the mockups have a UI for it | Consent step in `train-recognition-model` and a switch in `manage-profile` |
| UX-17 | The terms text mentions "modelos 3D interactivos"; the 3D avatar is out of scope | Update the terms |
| UX-18 | Password length is inconsistent: `shortPassword` says 6, the registration hint says 8; RF11 makes the policy configurable | Always show the rules of the active policy |
| UX-19 | The Claude Design export, now the mockup set, brought its own gaps: 27 letters with Ñ, "Estadísticas" in the user navigation, a 30-day lock on changing the name, avatar upload, invented contact details, four languages | The first three were corrected when the export was organised; the rest stay visible in the mockups and must be decided by the team. Details in `design-system.md` § 10.4 |
| UX-20 | `view-usage-statistics` is administrator-only (UX-03), but its subtitle still says "tu progreso aprendiendo lengua de señas", copy written for a user | Rewrite the page copy as platform metrics |

---

## Correlations

- Visual rules for these screens → `design-system.md`
- Acceptance criteria per screen → `04-requirements/user-stories.md`
- Roles and permissions → `06-data/domains/02-authorization.md`

## Change log

| Version | Date | Change |
|---------|------|--------|
| v0.1 | 2026-09-15 | Template replaced with the real screen inventory (21 screens), navigation tree, access matrix, flows and 18 recorded gaps. Alphabet fixed at 26 letters |
| v0.2 | 2026-09-15 | UX-19 added after reviewing the Claude Design export |
| v0.3 | 2026-09-15 | The export became the mockup set: the table now says which four screens have no mockup, UX-19 rewritten, UX-20 added (statistics copy still addresses a user), UX-15 and UX-16 corrected |
