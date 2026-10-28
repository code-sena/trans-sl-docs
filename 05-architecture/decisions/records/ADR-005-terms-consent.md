# ADR-005 — Express Consent on Account Creation (Ley 1581)

> Based on: Backend `19ff387` (`origin/main`, v1.2.0), Frontend `origin/develop` after #63

- **ID:** ADR-005
- **Date:** 2026-10-23
- **Status:** Accepted
- **Authors:** Luis Alejandro Duarte Aldana (proposal and implementation); accepted by the development team on 2026-10-23 (Backend #52 reviewed and merged by Juan Mauricio Suaza Solórzano)

---

## Context

Ley 1581 de 2012 and Decreto 1377 de 2013 require an **express, informed and verifiable** authorization before processing personal data (`01-context/overview.md`, `01-context/scope.md`). The 2026-10-21 end-to-end evaluation (finding H-04) found that consent was not stored on the server:

- `iam.users` already had `terms_accepted` and `terms_accepted_at` (`services/iam-service/db/000_users.sql`), but the repository stamped `terms_accepted = true, terms_accepted_at = NOW()` on **every** new account, even though the client never sent anything.
- The register screen required the checkbox, but `AuthContext` dropped it when building the request.
- There was no record of **which version** of the terms was accepted.
- Google and Facebook sign-in created accounts the same way, without any consent step.

**Known constraints:**
- The installed APK 1.0.2 sends no consent, so making it mandatory blocks new registrations from that APK until users update.
- Existing accounts must keep logging in without a new step.
- The terms text lives in the app (`TermsScreen`, `PrivacyPolicyScreen`) with a "last updated" date, not in the backend.

---

## Decision

**We decided:** an account is created only with express consent, and the server stores the version of the terms that was accepted.

- **Email register** (`POST /api/auth/register`, Backend #52): `acceptedTerms` (only `true`) and `termsVersion` (1–20 characters) are **required**. Without them the answer is `400 INVALID_BODY` and no account is created. The same rule is checked in the domain (`userDomainService.ensureRegistrationIsValid`), so no other entry point can skip it.
- **Google and Facebook** (`POST /api/auth/google`, `POST /api/auth/facebook`, Backend #61): the fields are optional. An existing account logs in as before. A **new** account without consent gets `400 TERMS_REQUIRED`; the app asks for consent and retries with the same provider token (Frontend #72, `signInWithSocialConsent`).
- **Storage:** new column `users.terms_version VARCHAR(20)` (`db/013_users_terms_version.sql`, Liquibase changeset `016`). `NULL` marks accounts created before this decision.
- **Version identifier:** `TERMS_VERSION` in the frontend (`src/app/config/legal.config.ts`), today `'2025-01'`, matching "Última actualización: enero 2025" on the terms screens. It must change whenever the terms text changes.

**Justification:**
- The client is the only place that knows which text the person saw, so it sends the version; the server stores what it receives instead of assuming.
- Rejecting the request (not defaulting to `true`) is what makes the record evidence of consent.
- Keeping consent optional on social login for existing accounts avoids asking returning users again.

---

## Evaluated alternatives

| Alternative | Pros | Cons | Reason for discarding |
|------------|------|------|-----------------------|
| Required consent + stored version (chosen) | Verifiable record; meets H-04 closing criterion ("a register without the checkbox gets 400") | APK 1.0.2 cannot register until updated | — (chosen) |
| Transition period: accept missing consent, store `NULL` version | No break for the installed APK | The audit finding stays open; accounts keep being created without consent | The team chose to close H-04 now (decision of 2026-10-23) |
| Server-side terms version (backend decides the current version) | Single source of truth | The server cannot know which text the client displayed | The text and its date live in the app |
| Separate consent table with history | Supports withdrawal and re-consent per version | More schema and endpoints than the MVP needs | Can be added later; the column is enough to prove the initial consent |

---

## Consequences

**Positive:**
- Every account created from now on has `terms_accepted_at` and `terms_version` backed by an explicit request.
- The rule is enforced in the HTTP schema and in the domain, with tests in `services/iam-service/tests` and `src/feature/auth/services/__tests__`.

**Negative / Trade-offs:**
- **APK 1.0.2 cannot create accounts** once the backend change is deployed. APK 1.1.0 must be published at the same time. Login of existing accounts is not affected.
- Backend and web must be deployed together, and the migration `013` applied by hand on the server first (migrations are still manual, finding H-02).
- Withdrawing consent is not implemented as its own flow; account deletion remains the way to revoke it.

**Impact on the system:**
- Affected services: `iam-service`; frontend auth (`AuthContext`, register form, Google and Facebook hooks).
- Documents updated: `07-api/contracts/openapi/iam-service.yaml` (Docs #21, #24), `06-data/models.md`.

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Terms text changes but `TERMS_VERSION` is not bumped | Medium | Medium | Comment next to the constant; bump it in the same PR that edits the terms |
| Users keep the old APK and cannot register | High (short term) | Medium | Publish APK 1.1.0 together with the deploy; the download page shows the latest release |
| Accounts created before 2026-10-23 have no version | Certain | Low | `terms_version IS NULL` identifies them; ask for consent again if the policy requires it |

---

## References

- Backend: #52 (register), #61 (social login); `services/iam-service/db/013_users_terms_version.sql`
- Frontend: #63 (register body), #72 (social login consent); `src/app/config/legal.config.ts`
- Docs: #21, #24 (OpenAPI contracts)
- Evaluation of 2026-10-21, finding H-04
- Related to: ADR-002 (JWT authentication)
