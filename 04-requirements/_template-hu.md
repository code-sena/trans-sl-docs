# HU-[SERVICE]-[NNN]: [Story Title]

> **ID convention:** `HU-[SERVICE_ABBREVIATION]-[NNN]`
> Examples: HU-IAM-001, HU-TRA-003, HU-LEX-006
> Modules in this project: IAM · AUTHZ · PROF · LEX · TRA · NOTIF · AI · USG · GAM · AUD · CFG · NAV

---

## Story

**As** [deaf or hard-of-hearing person / hearing learner / administrator / LSC linguist]
**I want** [concrete action they want to perform]
**So that** [benefit they receive / problem they solve]

---

## Acceptance criteria

> Format: "Given [context/initial state], when [user action], then [expected and verifiable result]"

- [ ] **AC1:** Given that [context], when [action], then [result]
- [ ] **AC2:** Given that [context], when [action], then [result]
- [ ] **AC3:** [Error scenario] Given that [invalid context], when [action], then [expected error]

---

## Technical notes

> [Implementation constraints, performance considerations, required integrations]

**Responsible service(s):** [iam / recognition / lexicon / analytics / profile — matches the owning service of the TableGroup in the data model]
**Endpoint(s) implemented:** [method + path]
**Events generated:** [if applicable]
**Required permissions:** [minimum role to perform this action]

---

## Definition of Done (DoD)

> This HU can only be closed when it meets the team's full DoD.
> See: [`00-governance/definition-of-done.md`](../../00-governance/definition-of-done.md)

**Additional checks specific to this HU (if applicable):**
- [ ] Accessibility checklist passed (NFR-001) — mandatory if this HU introduces a screen
- [ ] [Additional check — e.g.: DB migration executed in staging]
- [ ] [Remove this section if there are no additional checks]

---

## Estimation and priority

| Field | Value |
|-------|-------|
| Story Points | [1 / 2 / 3 / 5 / 8 / 13] |
| Priority | High / Medium / Low |
| Target sprint | Sprint N |
| Dependencies | [HU-XXX-NNN that must be completed first] |
