# User Stories — Backlog

> **Status:** 🟡 Living document — v0.2
> **Last updated:** 2026-09-08
> **ID convention:** `HU-[MODULE]-[NNN]` — the module matches a `TableGroup` in the data model
> **Modules:** IAM (Identity) · AUTHZ (Authorization) · PROF (Profile) · LEX (Lexicon) · TRA (Translation) · NOTIF (Notification) · AI · USG (Usage) · GAM (Gamification) · AUD (Audit) · CFG (Configuration) · NAV (Navigation)

---

## Backlog status

| Cut | Sprint | Total HUs | Refined | In progress | Completed |
|-----|--------|-----------|---------|-------------|-----------|
| Cut 1 — Foundation | Sprint 1–2 | 14 | 14 | 0 | 0 |
| Cut 2 — Core function | Sprint 3–4 | 16 | 8 | 0 | 0 |
| Cut 3 — Administration | Sprint 5–6 | 15 | 0 | 0 | 0 |
| Cut 4 — Optional | Sprint 7 | 8 | 0 | 0 | 0 |
| **Total** | | **53** | **22** | **0** | **0** |

> Numbers reflect the state of the backlog at baseline. They are updated at each
> Sprint Planning.

---

## Roles used

Per the rule "do not write 'as a user'", these are the four concrete roles in this product:

| Role | Who it is |
|------|-----------|
| **Deaf or hard-of-hearing person** | The primary end user. Uses LSC and needs to be understood by people who do not sign. |
| **Hearing learner** | Registered user learning LSC — consults the alphabet and the lexicon. |
| **Administrator** | Manages content, users, models and statistics. |
| **LSC linguist** | Domain expert who captures and validates gesture samples for training. |

---

## Epics

| ID | Epic | Description | HUs |
|----|------|-------------|-----|
| EP-001 | Account and access | Registration, verification, login, social providers, recovery, sessions | 10 |
| EP-002 | Roles and permissions | Access control for administration functions | 2 |
| EP-003 | Profile and preferences | Personal data, password, theme, language, notification switch | 5 |
| EP-004 | Sign lexicon | Catalog, search, sign detail, alphabet, content administration | 7 |
| EP-005 | Sign→text translation | The core function: camera, recognition, audio, history | 6 |
| EP-006 | Visual notifications | Type catalog, devices, delivery, scheduling, read state | 6 |
| EP-007 | AI model | Sample capture with consent, validation, training, publication | 5 |
| EP-008 | Usage statistics | Event recording and the administration dashboard | 4 |
| EP-009 | Gamification ⚠️ | Achievements and progress — **pending RF8 approval** | 4 |
| EP-010 | Audit and configuration | Change trail, error log, password policy | 3 |
| EP-011 | Navigation | Movement between the application's sections | 1 |

---

# EP-001 — Account and access

### HU-IAM-001 — Registration with email and password {#HU-IAM-001}

**Epic:** EP-001 · **FR:** FR-001, FR-002

> **As** a deaf or hard-of-hearing person
> **I want** to create an account with my personal data and accept the terms
> **so that** my translations and preferences are saved and follow me across devices

**Acceptance criteria:**

```gherkin
Scenario 1: Successful registration
  Given I am on the registration screen
  When  I enter a valid full name, birth date, username, email and a password
        that satisfies the active policy
  And   I check the terms and conditions acceptance box
  Then  the account is created with status INACTIVE
  And   the acceptance timestamp and the terms version are stored
  And   a 6-digit verification code is sent to my email

Scenario 2: Terms not accepted
  Given I have filled in every field correctly
  When  I submit the form without checking the terms box
  Then  the account is NOT created
  And   the message "You must accept the terms and conditions to continue" is shown

Scenario 3: Email already registered
  Given an account already exists with the email "ana@correo.com"
  When  I try to register with that same email
  Then  error "EMAIL_ALREADY_EXISTS" is returned
  And   the message "This email already has an account. Do you want to sign in?" is shown

Scenario 4: Password does not meet the policy
  Given the active policy requires 8 characters with uppercase, lowercase, number and symbol
  When  I enter the password "hola123"
  Then  the account is NOT created
  And   the specific unmet requirements are listed
```

**Definition of Done:**

- [ ] Code reviewed and approved
- [ ] Unit tests written
- [ ] Acceptance criteria verified
- [ ] API contract updated
- [ ] Accessibility checklist passed (NFR-001)
- [ ] Deployed to staging

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 1 |
| Status | Ready |
| Dependencies | HU-CFG-001 (password policy) |
| Module | IAM |

---

### HU-IAM-002 — Email verification with a 6-digit code {#HU-IAM-002}

**Epic:** EP-001 · **FR:** FR-003, FR-004

> **As** a person who has just registered
> **I want** to confirm my email with a code
> **so that** nobody can create an account using an address that is not theirs

**Acceptance criteria:**

```gherkin
Scenario 1: Valid code
  Given my account is INACTIVE and I received the code "482913"
  When  I enter that code before it expires
  Then  my account changes to ACTIVE
  And   the verification timestamp is recorded
  And   the code is marked as used and cannot be reused

Scenario 2: Expired code
  Given I received a code more than 15 minutes ago
  When  I enter it
  Then  error "TOKEN_EXPIRED" is returned
  And   the option to request a new code is offered

Scenario 3: Too many failed attempts
  Given I have entered the wrong code 5 times
  When  I try a sixth time
  Then  the code is invalidated
  And   I am required to request a new one
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 1 |
| Status | Ready |
| Dependencies | HU-IAM-001 |
| Module | IAM |

---

### HU-IAM-003 — Login with email and password {#HU-IAM-003}

**Epic:** EP-001 · **FR:** FR-005

> **As** a registered user
> **I want** to sign in with my credentials
> **so that** I can reach my history and my preferences

**Acceptance criteria:**

```gherkin
Scenario 1: Successful login
  Given my account is ACTIVE and not locked
  When  I enter my correct email and password
  Then  a session is opened with an access token valid for 1 hour
  And   a refresh token valid for 7 days is issued
  And   the failed attempt counter is reset to zero
  And   my last access timestamp is updated

Scenario 2: Unverified account
  Given my account is INACTIVE
  When  I enter correct credentials
  Then  the session is NOT opened
  And   the message "Confirm your email to continue" is shown with the option to resend the code

Scenario 3: Blocked account
  Given my account is BLOCKED
  When  I enter correct credentials
  Then  error "ACCOUNT_BLOCKED" is returned
  And   the message instructs me to contact the administrator
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 1 |
| Status | Ready |
| Dependencies | HU-IAM-002 |
| Module | IAM |

---

### HU-IAM-004 — Progressive lockout on failed attempts {#HU-IAM-004}

**Epic:** EP-001 · **FR:** FR-006, FR-007

> **As** an administrator responsible for account security
> **I want** repeated failed attempts to lock the account progressively
> **so that** an attacker cannot guess passwords by brute force

**Acceptance criteria:**

```gherkin
Scenario 1: First lockout level
  Given I have failed the password 3 consecutive times
  When  I fail again
  Then  the account is locked for 1 minute
  And   the lockout level goes to 1

Scenario 2: Lockout escalation
  Given my lockout level is 1 and I fail again after the wait
  When  the failure threshold is reached again
  Then  the account is locked for 5 minutes
  And   the next escalation locks it for 10 minutes

Scenario 3: Escalation exhausted
  Given my lockout level has reached the configured maximum
  When  I fail again
  Then  my account changes to BLOCKED
  And   the block timestamp is recorded
  And   only an administrator can restore it

Scenario 4: Level reset
  Given my lockout level is 2
  And   24 hours have passed with no failed attempts
  When  I attempt to sign in
  Then  the lockout level is reset to 0
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 2 |
| Status | Ready |
| Dependencies | HU-IAM-003 |
| Module | IAM |

---

### HU-IAM-005 — Registration and login with Google or Facebook {#HU-IAM-005}

**Epic:** EP-001 · **FR:** FR-008, FR-009

> **As** a person who does not want to remember another password
> **I want** to enter with my Google or Facebook account
> **so that** I can start using the app without a registration form

**Acceptance criteria:**

```gherkin
Scenario 1: First login with a provider
  Given I have no account in TraduceSeña
  When  I authenticate with Google and authorize the requested data
  Then  an account is created directly in ACTIVE status
  And   the email is marked as already verified
  And   the provider identity is linked to my account

Scenario 2: Linking a second provider
  Given I already have an account linked to Google
  When  I authenticate with Facebook using the same email
  Then  the Facebook provider is linked to my existing account
  And   a duplicate account is NOT created

Scenario 3: Provider identity already in use
  Given a Google identity is already linked to another account
  When  someone tries to link it to a second account
  Then  error "PROVIDER_ALREADY_LINKED" is returned
```

| Field | Value |
|-------|-------|
| Story Points | 8 |
| Priority | Must Have |
| Target sprint | Sprint 2 |
| Status | Ready |
| Dependencies | HU-IAM-001 |
| Module | IAM |

---

### HU-IAM-006 — Password recovery {#HU-IAM-006}

**Epic:** EP-001 · **FR:** FR-010

> **As** a user who forgot their password
> **I want** to reset it from a link sent to my email
> **so that** I do not lose access to my account and my history

**Acceptance criteria:**

```gherkin
Scenario 1: Successful recovery
  Given my account exists and is ACTIVE
  When  I request recovery with my email
  Then  an email arrives with a single-use link
  And   the link expires in 30 minutes
  When  I open the link and enter a valid new password
  Then  the password is updated
  And   the token is marked as used
  And   all my active sessions are closed

Scenario 2: Unregistered email
  Given the email "nadie@correo.com" is not registered
  When  I request recovery with that email
  Then  the same confirmation message is shown as in the success case
  And   no email is sent
  # Deliberate: revealing which emails exist enables account enumeration

Scenario 3: Reused link
  Given I already used the recovery link
  When  I open it again
  Then  error "TOKEN_ALREADY_USED" is returned
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 2 |
| Status | Ready |
| Dependencies | HU-IAM-003 |
| Module | IAM |

---

### HU-IAM-007 — Session with refresh token rotation {#HU-IAM-007}

**Epic:** EP-001 · **FR:** FR-011, FR-012

> **As** a user of the mobile app
> **I want** my session to stay open without asking me for the password every hour
> **so that** I can use the app without friction, without weakening security

**Acceptance criteria:**

```gherkin
Scenario 1: Token renewal
  Given my access token expired and my refresh token is valid
  When  the app requests a renewal
  Then  a new access token valid for 1 hour is issued
  And   a new refresh token is issued
  And   the previous refresh token is revoked and linked to its replacement

Scenario 2: Spent token reuse detected
  Given a refresh token that was already used and revoked
  When  someone presents it again
  Then  the renewal is rejected
  And   the entire session is revoked
  And   the event is recorded in the error log as an AUTH_ERROR
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 2 |
| Status | Ready |
| Dependencies | HU-IAM-003 |
| Module | IAM |

---

### HU-IAM-008 — Logout {#HU-IAM-008}

**Epic:** EP-001 · **FR:** FR-013

> **As** a user sharing a device
> **I want** to sign out and close my session
> **so that** nobody else can see my history

```gherkin
Scenario 1: Session closed
  Given I have an active session
  When  I sign out
  Then  the session status changes to CLOSED
  And   the end time is stamped and the duration in seconds is computed
  And   every refresh token of that session is revoked
```

| Field | Value |
|-------|-------|
| Story Points | 2 |
| Priority | Must Have |
| Target sprint | Sprint 1 |
| Status | Ready |
| Module | IAM |

---

### HU-IAM-009 — Account deletion {#HU-IAM-009}

**Epic:** EP-001 · **FR:** FR-014

> **As** a user who no longer wants to use the app
> **I want** to delete my account and my personal data
> **so that** my information stops being associated with me

```gherkin
Scenario 1: Deletion with anonymization
  Given I have an active account with translation history
  When  I confirm the deletion of my account
  Then  my row is marked as deleted and my personal data is anonymized
  And   my sessions and usage events survive with no user identity
  And   my audit trail survives with no user identity
  And   I can no longer sign in with those credentials
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Should Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Dependencies | HU-USG-004 |
| Module | IAM |

---

### HU-IAM-010 — Account administration {#HU-IAM-010}

**Epic:** EP-001 · **FR:** FR-015

> **As** an administrator
> **I want** to activate, deactivate or unblock user accounts
> **so that** I can restore access to a legitimate user who got locked out

```gherkin
Scenario 1: Unblocking
  Given a user account is BLOCKED
  When  I unblock it from the administration panel
  Then  the account returns to ACTIVE
  And   the lockout level and the failed attempt counter are reset
  And   the change is recorded in the audit log with my identity
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Should Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Dependencies | HU-AUTHZ-002 |
| Module | IAM |

---

# EP-002 — Roles and permissions

### HU-AUTHZ-001 — Role and permission model {#HU-AUTHZ-001}

**Epic:** EP-002 · **FR:** FR-101, FR-102

> **As** an administrator
> **I want** to assign roles to users and permissions to roles
> **so that** I can grant a new capability without inventing a new role each time

```gherkin
Scenario 1: Role assignment
  Given the roles USER, ADMIN and LINGUIST exist
  When  I assign the LINGUIST role to a user
  Then  that user gains every permission associated with the role
  And   the assignment timestamp is recorded

Scenario 2: A user with two roles
  Given a user holds the USER and LINGUIST roles
  When  their permissions are evaluated
  Then  they hold the union of both roles' permissions
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 2 |
| Status | Ready |
| Module | AUTHZ |

---

### HU-AUTHZ-002 — Administration access control {#HU-AUTHZ-002}

**Epic:** EP-002 · **FR:** FR-103, FR-104, FR-706

> **As** an administrator
> **I want** administration functions to be unreachable without the right permission
> **so that** no end user can modify content or read others' statistics

```gherkin
Scenario 1: Access denied
  Given I am authenticated as an end user with no administration permission
  When  I request the statistics endpoint
  Then  error 403 PERMISSION_ERROR is returned
  And   the response distinguishes "authenticated but not authorized"
        from "not authenticated"

Scenario 2: Role in use cannot be deleted
  Given the role LINGUIST is assigned to at least one user
  When  I try to delete that role
  Then  the deletion is rejected with error "ROLE_IN_USE"
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 2 |
| Status | Ready |
| Dependencies | HU-AUTHZ-001 |
| Module | AUTHZ |

---

# EP-003 — Profile and preferences

### HU-PROF-001 — View and edit profile {#HU-PROF-001}

**Epic:** EP-003 · **FR:** FR-201

> **As** a registered user
> **I want** to see and correct my personal data
> **so that** my profile reflects who I actually am

```gherkin
Scenario 1: Successful edit
  Given I am on my profile screen
  When  I change my full name and save
  Then  the change is persisted and the update timestamp is refreshed
  And   the change is recorded in the audit log

Scenario 2: Username already taken
  Given the username "mauro" belongs to another user
  When  I try to take it
  Then  error "USERNAME_TAKEN" is returned
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 3 |
| Status | Ready |
| Module | PROF |

---

### HU-PROF-002 — Change password {#HU-PROF-002}

**Epic:** EP-003 · **FR:** FR-202

> **As** a security-conscious user
> **I want** to change my password from within the app
> **so that** I can rotate it without going through the recovery flow

```gherkin
Scenario 1: Successful change
  Given I am authenticated
  When  I enter my current password and a valid new one
  Then  the password is updated
  And   my other sessions are closed, keeping the current one open

Scenario 2: Wrong current password
  When  I enter an incorrect current password
  Then  the change is rejected with error "INVALID_CREDENTIALS"
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 3 |
| Status | Ready |
| Dependencies | HU-CFG-001 |
| Module | PROF |

---

### HU-PROF-003 — Light and dark theme {#HU-PROF-003}

**Epic:** EP-003 · **FR:** FR-203, FR-206

> **As** a user who uses the app in low light
> **I want** to switch to a dark theme
> **so that** I can use it at night without straining my eyes

```gherkin
Scenario 1: Theme switch
  Given my preference is the light theme
  When  I select the dark theme in settings
  Then  the interface changes immediately
  And   the preference persists when I close and reopen the app
  And   the preference follows me if I sign in on another device

Scenario 2: Default preferences
  Given a newly created account
  When  the account is created
  Then  a preference record exists with Spanish, light theme and notifications enabled
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Should Have |
| Target sprint | Sprint 3 |
| Status | Ready |
| Module | PROF |

---

### HU-PROF-004 — Interface language {#HU-PROF-004}

**Epic:** EP-003 · **FR:** FR-204

> **As** a user more comfortable in English
> **I want** to switch the interface language
> **so that** I can understand the app without translating it in my head

```gherkin
Scenario 1: Language switch
  Given the interface is in Spanish
  When  I select English
  Then  every interface text changes to English
  And   the names of the signs in the lexicon change to their English localization
  And   my session stays open
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Should Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Dependencies | HU-LEX-005 |
| Module | PROF |

---

### HU-PROF-005 — Notification master switch {#HU-PROF-005}

**Epic:** EP-003 · **FR:** FR-205, FR-508

> **As** a user who does not want interruptions
> **I want** a single switch that turns all notifications off
> **so that** I can silence the app without uninstalling it

```gherkin
Scenario 1: Notifications disabled
  Given my notification switch is on
  When  I turn it off
  Then  no new notification is delivered to me through any channel
  And   notifications already received stay visible in my history
```

| Field | Value |
|-------|-------|
| Story Points | 2 |
| Priority | Must Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Module | PROF |

---

# EP-004 — Sign lexicon

### HU-LEX-001 — Browse the sign catalog {#HU-LEX-001}

**Epic:** EP-004 · **FR:** FR-301

> **As** a hearing learner
> **I want** to browse the signs organized by category
> **so that** I can learn LSC vocabulary by topic instead of at random

```gherkin
Scenario 1: Catalog by category
  Given the categories "Greetings", "Family" and "Numbers" exist
  When  I open the lexicon
  Then  I see the categories with their sign count
  When  I select "Greetings"
  Then  I see only the ACTIVE signs of that category

Scenario 2: Inactive signs are hidden
  Given a sign has status INACTIVE or DRAFT
  When  I browse its category
  Then  that sign does not appear
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 3 |
| Status | Ready |
| Module | LEX |

---

### HU-LEX-002 — Search the catalog {#HU-LEX-002}

**Epic:** EP-004 · **FR:** FR-302

> **As** a learner who needs a specific sign
> **I want** to search it by name
> **so that** I do not have to browse the whole catalog to find one word

```gherkin
Scenario 1: Search with results
  Given signs named "Hola", "Hospital" and "Hoy" exist
  When  I search "ho"
  Then  the three signs are shown ordered by relevance

Scenario 2: No results
  When  I search "xyz"
  Then  the message "No signs found for 'xyz'" is shown
  And   browsing by category is suggested
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 3 |
| Status | Ready |
| Dependencies | HU-LEX-001 |
| Module | LEX |

---

### HU-LEX-003 — Sign detail with multimedia {#HU-LEX-003}

**Epic:** EP-004 · **FR:** FR-303

> **As** a learner
> **I want** to see the sign performed in video, with its meaning and description
> **so that** I can reproduce it correctly

```gherkin
Scenario 1: Complete detail
  Given the sign "Hola" has a video and an animation
  When  I open its detail
  Then  I see its name, meaning and description in my interface language
  And   the resources play in their defined order
  And   the video is understandable with no sound   # NFR-001

Scenario 2: Sign with no resources
  Given a sign has no multimedia resources
  When  I open its detail
  Then  the textual information is shown
  And   a placeholder indicating the material is pending is shown
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 3 |
| Status | Ready |
| Dependencies | HU-LEX-001 |
| Module | LEX |

---

### HU-LEX-004 — Alphabet in signs {#HU-LEX-004}

**Epic:** EP-004 · **FR:** FR-304

> **As** a person starting to learn LSC
> **I want** to consult the manual alphabet letter by letter
> **so that** I can fingerspell words I do not yet know the sign for

```gherkin
Scenario 1: Complete alphabet
  When  I open the alphabet section
  Then  I see every letter of the LSC alphabet in order
  And   each letter shows its corresponding sign
  And   no letter appears twice

Scenario 2: Letter detail
  When  I select the letter "M"
  Then  I see the sign for that letter with its multimedia resource
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 3 |
| Status | Ready |
| Module | LEX |

---

### HU-LEX-005 — Stable code and localization per language {#HU-LEX-005}

**Epic:** EP-004 · **FR:** FR-305, FR-306

> **As** an administrator of the lexicon
> **I want** each sign to have one language-independent code and its written form per language
> **so that** switching the interface language does not duplicate the sign or break the AI model

```gherkin
Scenario 1: One sign, two languages
  Given the sign with code "GREETING_HELLO" exists
  And   it has the localization "Hola" in Spanish and "Hello" in English
  When  a user with the interface in English opens it
  Then  they see "Hello"
  And   it is the same sign record, not a copy

Scenario 2: The code is what the model predicts
  Given the AI model predicts the class "GREETING_HELLO"
  When  the translation is resolved
  Then  the sign is located by its code, not by its name
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 3 |
| Status | Ready |
| Module | LEX |

---

### HU-LEX-006 — Sign and category administration {#HU-LEX-006}

**Epic:** EP-004 · **FR:** FR-307, FR-308, FR-310

> **As** an administrator
> **I want** to create, edit and publish signs and categories
> **so that** the catalog can grow without a developer deploying code

```gherkin
Scenario 1: Creating a sign
  When  I create a sign with its code, type, category and localizations
  Then  it is saved with status DRAFT
  And   my identity is recorded as its creator
  When  I publish it
  Then  its status changes to ACTIVE and it becomes visible to users

Scenario 2: Category with signs cannot be deleted
  Given the category "Greetings" has 12 signs
  When  I try to delete it
  Then  the deletion is rejected with error "CATEGORY_IN_USE"
```

| Field | Value |
|-------|-------|
| Story Points | 8 |
| Priority | Must Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Dependencies | HU-AUTHZ-002 |
| Module | LEX |

---

### HU-LEX-007 — Multimedia resource management {#HU-LEX-007}

**Epic:** EP-004 · **FR:** FR-309

> **As** an administrator
> **I want** to attach images, videos and animations to a sign in a defined order
> **so that** the learner sees the material in the sequence that best explains the sign

```gherkin
Scenario 1: Ordered resources
  When  I attach a video at position 1 and an animation at position 2
  Then  both are saved with their order
  And   the detail plays them in that sequence

Scenario 2: Duplicate position
  When  I try to attach a second resource at position 1 of the same sign
  Then  the operation is rejected with error "POSITION_TAKEN"
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Dependencies | HU-LEX-006 |
| Module | LEX |

---

# EP-005 — Sign→text translation

### HU-TRA-001 — Translate signs into text with the camera {#HU-TRA-001}

**Epic:** EP-005 · **FR:** FR-401 · ⭐ **The product's core story**

> **As** a deaf or hard-of-hearing person
> **I want** to point my phone's camera at my hands and see my signs turned into written text
> **so that** I can communicate with someone who does not know LSC without an interpreter

```gherkin
Scenario 1: Successful translation
  Given I granted the camera permission
  And   the app has the active AI model downloaded
  When  I perform the sign for "Hola" in front of the camera
  Then  the text "Hola" appears on screen in under 500 ms
  And   the recognition confidence is displayed

Scenario 2: Camera permission denied
  Given I denied the camera permission
  When  I open the translation screen
  Then  an explanation of why the camera is needed is shown
  And   a button to open the system settings is offered
  And   the app does NOT crash

Scenario 3: The connection drops mid-session
  Given I am translating and the connection drops
  When  I perform a sign
  Then  the app tells me clearly whether it can still translate
  And   translations already produced are not lost
  And   they are queued to sync when the connection returns
  # ⚠️ Whether translation itself keeps working depends on the open inference
  # decision (02-domain/domain-map.md §5). Offline use is out of scope for v1.
```

| Field | Value |
|-------|-------|
| Story Points | 13 |
| Priority | Must Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Dependencies | HU-AI-005 (a published model) |
| Module | TRA |

---

### HU-TRA-002 — Audio output {#HU-TRA-002}

**Epic:** EP-005 · **FR:** FR-402

> **As** a deaf person talking to a hearing person who is not looking at the screen
> **I want** the translation to be spoken aloud
> **so that** the other person hears me without having to read my phone

```gherkin
Scenario 1: Audio playback
  Given I selected the audio output mode
  When  a translation completes
  Then  the text is spoken through the device speaker
  And   the text stays visible on screen at the same time    # NFR-001

Scenario 2: Audio mode does not hide information
  Given the audio mode is active
  When  the translation completes
  Then  every piece of information available in text mode is still visible
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Should Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Dependencies | HU-TRA-001 |
| Module | TRA |

---

### HU-TRA-003 — Persist the translation with its model version {#HU-TRA-003}

**Epic:** EP-005 · **FR:** FR-403, FR-404, FR-408

> **As** an administrator responsible for model quality
> **I want** each translation to record which model version produced it and with what confidence
> **so that** I can tell whether a new version improved or degraded recognition

```gherkin
Scenario 1: Translation stored with traceability
  When  a translation completes
  Then  the recognized text, the confidence and the model identifier are stored
  And   the individual signs are stored with their recognition order

Scenario 2: A model with history cannot be deleted
  Given model version 1.0.0 produced translations
  When  someone tries to delete it
  Then  the deletion is rejected, preserving historical traceability
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Dependencies | HU-TRA-001 |
| Module | TRA |

---

### HU-TRA-004 — Failed recognition feedback {#HU-TRA-004}

**Epic:** EP-005 · **FR:** FR-405

> **As** a user translating
> **I want** to be told clearly when nothing was recognized
> **so that** I know the app is working and I should adjust my position, instead of thinking it froze

```gherkin
Scenario 1: Nothing recognized
  Given the camera is active and no sign is detected for 5 seconds
  Then  a visual message is shown suggesting how to improve the capture
        (lighting, distance, hands within the frame)
  And   the event is recorded as TRANSLATION_FAILED

Scenario 2: Confidence below the threshold
  Given a sign is recognized with confidence below 0.60
  Then  the result is shown marked as uncertain
  And   repeating the sign is offered
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Dependencies | HU-TRA-001 |
| Module | TRA |

---

### HU-TRA-005 — Translation history {#HU-TRA-005}

**Epic:** EP-005 · **FR:** FR-406

> **As** a frequent user
> **I want** to consult my previous translations
> **so that** I can recover something I translated before without redoing it

```gherkin
Scenario 1: History listed
  When  I open my history
  Then  I see my translations from newest to oldest
  And   deleted entries do not appear
  And   the list loads paged, 20 at a time
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Dependencies | HU-TRA-003 |
| Module | TRA |

---

### HU-TRA-006 — Delete history entries {#HU-TRA-006}

**Epic:** EP-005 · **FR:** FR-407

> **As** a user who translated something private
> **I want** to delete individual entries from my history
> **so that** they do not stay visible to anyone who picks up my phone

```gherkin
Scenario 1: Logical deletion
  Given I have a translation in my history
  When  I delete it
  Then  it stops appearing in my history
  And   the record is preserved with a deletion timestamp for statistics
  And   the event is recorded as HISTORY_ENTRY_DELETED
```

| Field | Value |
|-------|-------|
| Story Points | 2 |
| Priority | Should Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Dependencies | HU-TRA-005 |
| Module | TRA |

---

# EP-006 — Visual notifications

### HU-NOTIF-001 — Notification type catalog {#HU-NOTIF-001}

**Epic:** EP-006 · **FR:** FR-501

> **As** an administrator
> **I want** to activate or withdraw a type of notification for everyone
> **so that** I can stop a class of alert that is bothering users without a deploy

```gherkin
Scenario 1: Type withdrawn
  Given the type PRACTICE_REMINDER is active
  When  I deactivate it
  Then  no new notification of that type is generated for any user
  And   already delivered notifications of that type stay visible
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Module | NOTIF |

---

### HU-NOTIF-002 — Receive and read visual notifications {#HU-NOTIF-002}

**Epic:** EP-006 · **FR:** FR-502, FR-507 · ⭐ **Accessibility-critical**

> **As** a deaf or hard-of-hearing user
> **I want** every alert to reach me visually
> **so that** I do not miss information just because I cannot hear a sound

```gherkin
Scenario 1: Visual alert
  When  the system sends me a notification
  Then  it arrives as a banner or an in-app card, never as sound alone
  And   an unread badge is shown

Scenario 2: Marking as read
  When  I open a notification
  Then  it is marked as read with its timestamp
  And   the unread count decreases
  And   the event is recorded as NOTIFICATION_OPENED

Scenario 3: No audio-only channel exists
  Given the set of available delivery channels
  Then  every one of them (push, in-app, email) is visual
  And   no audio-exclusive channel can be configured    # NFR-001
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Dependencies | HU-NOTIF-003 |
| Module | NOTIF |

---

### HU-NOTIF-003 — Device registration for push {#HU-NOTIF-003}

**Epic:** EP-006 · **FR:** FR-503, FR-509

> **As** a user with more than one device
> **I want** notifications to reach every device where I signed in
> **so that** I do not miss an alert because I had the other phone in hand

```gherkin
Scenario 1: Device registered
  When  I sign in on a new device and grant the notification permission
  Then  its push token and platform are registered as active

Scenario 2: Invalid token
  Given a push token is rejected by the provider
  When  a delivery is attempted
  Then  the device is deactivated with a revocation timestamp
  And   no further delivery to it is attempted

Scenario 3: Push requires a device
  When  a push-channel notification is created with no target device
  Then  the creation is rejected
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Module | NOTIF |

---

### HU-NOTIF-004 — Scheduled notifications {#HU-NOTIF-004}

**Epic:** EP-006 · **FR:** FR-504

> **As** an administrator
> **I want** to schedule a notification for a future date
> **so that** I can announce something at the moment it is relevant, not when I write it

```gherkin
Scenario 1: Scheduled delivery
  When  I schedule a notification for tomorrow at 9:00
  Then  it is stored as PENDING with its scheduled time
  And   it is not delivered before that moment
  When  the scheduled time arrives
  Then  it is delivered and marked as SENT
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Should Have |
| Target sprint | Sprint 6 |
| Status | Backlog |
| Module | NOTIF |

---

### HU-NOTIF-005 — Failed delivery handling {#HU-NOTIF-005}

**Epic:** EP-006 · **FR:** FR-505

> **As** an administrator
> **I want** to tell "not yet sent" apart from "attempted and failed"
> **so that** I can detect a provider outage instead of assuming everything is fine

```gherkin
Scenario 1: Delivery failure
  Given the push provider returns an error
  When  the delivery is attempted
  Then  the notification is marked as FAILED
  And   the failure is recorded in the error log as EXTERNAL_SERVICE_ERROR
  And   it is distinguishable from a notification still PENDING
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 6 |
| Status | Backlog |
| Dependencies | HU-NOTIF-003 |
| Module | NOTIF |

---

### HU-NOTIF-006 — Reference to the originating record {#HU-NOTIF-006}

**Epic:** EP-006 · **FR:** FR-506

> **As** a user receiving an alert
> **I want** tapping it to take me to what it is about
> **so that** the notification is useful and not just an announcement

```gherkin
Scenario 1: Notification with a reference
  Given I unlocked an achievement
  When  I receive the notification
  Then  it carries the type and identifier of the achievement that originated it
  When  I tap it
  Then  I am taken to that achievement's detail

Scenario 2: Notification module stays decoupled
  Given a notification references an achievement
  Then  there is no foreign key from the notification to the achievement
  And   the reference is resolved by the application layer
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Should Have |
| Target sprint | Sprint 6 |
| Status | Backlog |
| Dependencies | HU-NOTIF-002 |
| Module | NOTIF |

---

# EP-007 — AI model

### HU-AI-001 — Gesture sample capture {#HU-AI-001}

**Epic:** EP-007 · **FR:** FR-601, FR-603, FR-607

> **As** an LSC linguist
> **I want** to record several takes of a sign in one capture session
> **so that** the model learns the sign's natural variation, and I can discard a whole bad batch at once

```gherkin
Scenario 1: Capture session
  When  I record 20 takes of the sign "GREETING_HELLO"
  Then  the 20 samples are stored grouped under one capture session
  And   each one records who operated the interface and who physically performed the sign
  And   they are stored in the document database, decoupled from the relational model

Scenario 2: Discarding a session
  Given a capture session came out with bad lighting
  When  I discard the session
  Then  every sample in it is removed in a single operation
```

| Field | Value |
|-------|-------|
| Story Points | 8 |
| Priority | Must Have |
| Target sprint | Sprint 6 |
| Status | Backlog |
| Dependencies | HU-AI-002 |
| Module | AI |

---

### HU-AI-002 — Demonstrable consent per sample {#HU-AI-002}

**Epic:** EP-007 · **FR:** FR-602 · ⚖️ **Legal — Law 1581 of 2012**

> **As** the project's data controller
> **I want** every sample to carry provable authorization from the person who appears in it
> **so that** the training dataset is legally usable and the project does not breach habeas data

```gherkin
Scenario 1: Sample with consent
  When  a sample is registered
  Then  the authorization timestamp and the version of the signed consent
        document are mandatory
  And   the sample cannot be stored without both

Scenario 2: Consent withdrawn
  Given a collaborator withdraws their authorization
  When  their capture sessions are identified
  Then  every sample of that collaborator can be removed
  And   the removal is recorded in the audit log
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 6 |
| Status | Backlog |
| Module | AI |

---

### HU-AI-003 — Sample validation {#HU-AI-003}

**Epic:** EP-007 · **FR:** FR-604

> **As** an LSC linguist
> **I want** to review and approve each sample before it enters training
> **so that** a badly executed sign does not teach the model something wrong

```gherkin
Scenario 1: Validation
  Given an unvalidated sample
  When  I approve it
  Then  it is marked as validated with my identity and the timestamp
  And   only then does it become eligible for training

Scenario 2: Training uses only validated samples
  When  a training run is launched
  Then  the dataset contains exclusively validated samples
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 6 |
| Status | Backlog |
| Dependencies | HU-AI-001 |
| Module | AI |

---

### HU-AI-004 — Model registry with metrics {#HU-AI-004}

**Epic:** EP-007 · **FR:** FR-605

> **As** an administrator
> **I want** each trained model recorded with its metrics
> **so that** I can compare versions and roll back if a new one turns out worse

```gherkin
Scenario 1: Model registered
  When  a training run finishes
  Then  the version, date, responsible administrator, sample count,
        recognized sign count and test-set accuracy are recorded
  And   the version is unique
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 6 |
| Status | Backlog |
| Dependencies | HU-AI-003 |
| Module | AI |

---

### HU-AI-005 — Publishing the active model {#HU-AI-005}

**Epic:** EP-007 · **FR:** FR-606

> **As** an administrator
> **I want** to designate exactly one model as active
> **so that** every device translates with the same version and the results are comparable

```gherkin
Scenario 1: Activation
  Given model 1.0.0 is active and 1.1.0 was just registered
  When  I activate 1.1.0
  Then  1.1.0 becomes the active model
  And   1.0.0 is deactivated automatically
  And   at no point are two models active at once

Scenario 2: Minimum accuracy
  Given a model with accuracy below 0.85
  When  I try to activate it
  Then  the activation is rejected     # NFR-002
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Dependencies | HU-AI-004 |
| Module | AI |

---

# EP-008 — Usage statistics

### HU-USG-001 — Usage event recording {#HU-USG-001}

**Epic:** EP-008 · **FR:** FR-701, FR-702

> **As** an administrator
> **I want** the app to record what users actually do
> **so that** decisions about what to improve are based on data and not on intuition

```gherkin
Scenario 1: Section entry
  When  a user enters the translation section
  Then  an event of type SECTION_VIEW is recorded with its section and session

Scenario 2: Functional events
  When  a user starts a translation, completes it, plays audio, consults a sign,
        searches, deletes a history entry, changes a preference or opens a notification
  Then  the corresponding event is recorded with its timestamp
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 4 |
| Status | Ready |
| Module | USG |

---

### HU-USG-002 — Most visited sections {#HU-USG-002}

**Epic:** EP-008 · **FR:** FR-703

> **As** an administrator
> **I want** to see which sections are used most over a date range
> **so that** I can invest effort where users actually are

```gherkin
Scenario 1: Section report
  Given there are events over the last 30 days
  When  I request the report for that range
  Then  I see the sections ordered by visit count
  And   I can change the range and the report recalculates
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 6 |
| Status | Backlog |
| Dependencies | HU-USG-001, HU-AUTHZ-002 |
| Module | USG |

---

### HU-USG-003 — Sessions and average duration {#HU-USG-003}

**Epic:** EP-008 · **FR:** FR-704

> **As** an administrator
> **I want** to know how many sessions there are and how long they last
> **so that** I can tell real engagement from users who open the app and leave

```gherkin
Scenario 1: Session report
  When  I request the session report for a range
  Then  I see the total number of sessions and the average duration in minutes
  And   sessions still open are excluded from the average
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 6 |
| Status | Backlog |
| Dependencies | HU-USG-001 |
| Module | USG |

---

### HU-USG-004 — Statistics survive account deletion {#HU-USG-004}

**Epic:** EP-008 · **FR:** FR-705

> **As** an administrator
> **I want** statistics not to collapse when a user deletes their account
> **so that** historical reports stay consistent over time

```gherkin
Scenario 1: Deletion without data loss
  Given a user with 200 usage events deletes their account
  When  the deletion completes
  Then  the 200 events remain, detached from their user identity
  And   the aggregate reports keep the same totals
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Dependencies | HU-USG-001 |
| Module | USG |

---

# EP-009 — Gamification ⚠️ pending RF8 approval

> ⚠️ **These four stories only enter the backlog if RF8 is approved and added to
> the SRS.** If it is not approved, this epic and the `achievements` /
> `user_achievements` tables are removed. See `traceability-matrix.md` § 6, GAP-01.

### HU-GAM-001 — Achievement catalog {#HU-GAM-001}

**Epic:** EP-009 · **FR:** FR-801

> **As** an administrator
> **I want** to define achievements with a target to reach
> **so that** I can motivate sustained practice without changing code for each new achievement

```gherkin
Scenario 1: Achievement created
  When  I create the achievement "First 10 translations" with a target of 10
  Then  it is stored and becomes available to every user
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Could Have |
| Target sprint | Sprint 7 |
| Status | Blocked — pending RF8 |
| Module | GAM |

---

### HU-GAM-002 — Progress and unlocking {#HU-GAM-002}

**Epic:** EP-009 · **FR:** FR-802, FR-803

> **As** a learner
> **I want** my progress towards an achievement to advance as I use the app
> **so that** I have a reason to come back and keep practicing

```gherkin
Scenario 1: Achievement unlocked
  Given the achievement "First 10 translations" with a target of 10
  And   I have completed 9 translations
  When  I complete the tenth
  Then  the achievement is unlocked with its timestamp
  And   it is unlocked only once, even if I keep translating
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Could Have |
| Target sprint | Sprint 7 |
| Status | Blocked — pending RF8 |
| Dependencies | HU-GAM-001, HU-USG-001 |
| Module | GAM |

---

### HU-GAM-003 — Achievement notification {#HU-GAM-003}

**Epic:** EP-009 · **FR:** FR-804

> **As** a learner
> **I want** to be told visually the moment I unlock an achievement
> **so that** the reward arrives when the effort is fresh

```gherkin
Scenario 1: Visual alert on unlock
  When  I unlock an achievement
  Then  an in-app notification is generated referencing that achievement
  And   it is visual, with no dependence on sound     # NFR-001
```

| Field | Value |
|-------|-------|
| Story Points | 2 |
| Priority | Could Have |
| Target sprint | Sprint 7 |
| Status | Blocked — pending RF8 |
| Dependencies | HU-GAM-002, HU-NOTIF-006 |
| Module | GAM |

---

### HU-GAM-004 — Consult my achievements {#HU-GAM-004}

**Epic:** EP-009 · **FR:** FR-805

> **As** a learner
> **I want** to see the achievements I obtained and how far I am from the rest
> **so that** I know what to aim for next

```gherkin
Scenario 1: Achievement list
  When  I open my achievements
  Then  I see the ones obtained with their date
  And   the pending ones with my progress towards each target
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Could Have |
| Target sprint | Sprint 7 |
| Status | Blocked — pending RF8 |
| Dependencies | HU-GAM-002 |
| Module | GAM |

---

### HU-GAM-005 — Daily challenge {#HU-GAM-005}

**Epic:** EP-009 · **FR:** FR-806, FR-807 · **Decision:** [ADR-009](../05-architecture/decisions/records/ADR-009-daily-challenges.md)

> **As** a learner
> **I want** a small goal each day that grows when I save translations
> **so that** I have a reason to practice every day

```gherkin
Scenario 1: Progress
  When  I save and confirm a translation
  Then  the progress of today's challenge goes up by one

Scenario 2: Completion
  When  I reach the goal of the challenge
  Then  I receive the reward points once
  And   I see a visual notice if my notifications are enabled
```

| Field | Value |
|-------|-------|
| Priority | Could Have |
| Status | Done (profile-service PR #67, app PR #85) |
| Dependencies | HU-GAM-002, HU-TRA-003 |
| Module | GAM |

---

### HU-GAM-006 — Medals for challenge points {#HU-GAM-006}

**Epic:** EP-009 · **FR:** FR-808 · **Decision:** [ADR-010](../05-architecture/decisions/records/ADR-010-challenge-points-medals.md)

> **As** a learner
> **I want** to see my total of challenge points and earn medals for it
> **so that** my effort over time is recognized

```gherkin
Scenario 1: Medal
  When  my accumulated challenge points reach 500, 1,000 or 3,000
  Then  the matching medal is unlocked once, with no extra points
```

| Field | Value |
|-------|-------|
| Priority | Could Have |
| Status | Done (profile-service PR #69, app PR #86) |
| Dependencies | HU-GAM-005 |
| Module | GAM |

---

# EP-010 — Audit and configuration

### HU-AUD-001 — Change audit trail {#HU-AUD-001}

**Epic:** EP-010 · **FR:** FR-901, FR-902

> **As** an administrator
> **I want** every change to a sensitive entity recorded with its before and after values
> **so that** when something looks wrong I can tell who changed it and what it looked like before

```gherkin
Scenario 1: Change recorded
  Given an administrator edits a sign
  When  the change is saved
  Then  an audit entry is recorded with the entity, the action,
        the previous values and the new ones
  And   the responsible identity and the IP address are recorded

Scenario 2: Trail survives deletion
  Given the account of an administrator who made changes is deleted
  Then  their audit entries survive, detached from that identity
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Module | AUD |

---

### HU-AUD-002 — Technical error log {#HU-AUD-002}

**Epic:** EP-010 · **FR:** FR-903, FR-904

> **As** a developer on the team
> **I want** every failure recorded and classified by type
> **so that** I can find the cause without asking the user to reproduce the bug

```gherkin
Scenario 1: Error recorded
  Given the AI model fails while processing
  When  the exception is raised
  Then  it is recorded as MODEL_INFERENCE_ERROR with its message,
        stack trace, endpoint and timestamp
  And   the correlation ID lets the whole request be traced

Scenario 2: Query by category
  When  I query the errors of the last 24 hours by type
  Then  I see them grouped by category with their counts
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Must Have |
| Target sprint | Sprint 5 |
| Status | Backlog |
| Module | AUD |

---

### HU-CFG-001 — Configurable password policy {#HU-CFG-001}

**Epic:** EP-010 · **FR:** FR-905, FR-906, FR-907

> **As** an administrator
> **I want** to configure the password requirements without a deploy
> **so that** I can tighten security when the institution requires it

```gherkin
Scenario 1: Policy applied
  Given the active policy requires 10 characters with a symbol
  When  a user tries to register with an 8-character password
  Then  the registration is rejected listing the unmet requirements

Scenario 2: Only one active policy
  When  I activate a new policy
  Then  the previous one is deactivated but preserved as a historical record
  And   at no point are two policies active at once
```

| Field | Value |
|-------|-------|
| Story Points | 3 |
| Priority | Should Have |
| Target sprint | Sprint 1 |
| Status | Ready |
| Module | CFG |

---

# EP-011 — Navigation

### HU-NAV-001 — Navigation between sections {#HU-NAV-001}

**Epic:** EP-011 · **FR:** FR-951, FR-952

> **As** a user of the app
> **I want** to move between the sections from anywhere
> **so that** I never get stuck on a screen with no way out

```gherkin
Scenario 1: Main navigation
  Given I am on any section
  Then  I can reach home, translation, alphabet, lexicon, history,
        profile, settings and notifications
  And   no screen is a dead end

Scenario 2: Navigation is recorded
  When  I enter a section
  Then  a SECTION_VIEW event is recorded    # RF6 depends on this
```

| Field | Value |
|-------|-------|
| Story Points | 5 |
| Priority | Must Have |
| Target sprint | Sprint 3 |
| Status | Ready |
| Dependencies | HU-USG-001 |
| Module | NAV |

---

## Rules for writing HUs

### 1. The role matters

Do not write "as a user". Use one of the four roles defined at the top of this
document: deaf or hard-of-hearing person, hearing learner, administrator, LSC
linguist.

### 2. The benefit justifies the work

The "so that" must describe real value, not restate the action:

```
✓ so that I can communicate with someone who does not know LSC without an interpreter
✗ so that I can see the translated text   (this only restates the action)
```

### 3. ACs are verifiable

Each acceptance criterion must be checkable manually or automatable as a test.

### 4. One HU = one unit of value

If an HU has 15 acceptance criteria it is probably three HUs. The team must be
able to complete it within one sprint.

### 5. Accessibility is not optional

Any HU that introduces a screen carries the NFR-001 accessibility checklist in
its Definition of Done. An inaccessible screen is not Done in this project.

---

## Change log

| Version | Date | Change | Author |
|---------|------|--------|--------|
| v0.1 | 2026-09-08 | Empty template replaced with the real backlog: 11 epics, 53 user stories with Gherkin acceptance criteria, derived from the FR catalog and the v8 data model. EP-009 (gamification) created blocked pending RF8 approval. | Juan Mauricio Suaza Solórzano |
| v0.2 | 2026-09-08 | HU-TRA-001 scenario 3 corrected: it asserted offline translation as a fact, but offline use is out of scope for v1 and where inference runs is an open decision. | Juan Mauricio Suaza Solórzano |

---

## Correlations

- Functional requirements these HUs implement → `functional.md`
- Quality requirements applying to every HU → `non-functional.md`
- Test coverage per HU → `traceability-matrix.md`
- Full HU template → `_template-hu.md`
