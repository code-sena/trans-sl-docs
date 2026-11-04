# Product Backlog

> Acceptance criteria are checked against the code on 2026-11-04. `[x]` means the repositories show the behaviour. `[ ]` means it is not confirmed, or it depends on a process or a visual judgement that the repositories cannot show.

## HU-AUTH-001: User Registration

**As** a new user  
**I want** to create an account  
**So that** I can access the application's features.

### Acceptance criteria
- [x] AC1: Given a user without an account, when they provide valid registration information, then the system creates the account.
- [x] AC2: Given invalid or incomplete information, when the user submits the registration form, then the system displays an appropriate validation message.
- [x] AC3: The user's password must be stored securely and must not be stored as plain text.

### Technical notes
- The user account must be stored in the application's database.
- Authentication must be handled through the backend.

**Estimation:** 5 SP  
**Priority:** High

---

## HU-AUTH-002: User Login

**As** a registered user  
**I want** to log in to the application  
**So that** I can access my account and personalized features.

### Acceptance criteria
- [x] AC1: Given valid credentials, when the user logs in, then the system grants access to the application.
- [x] AC2: Given invalid credentials, when the user attempts to log in, then the system rejects the authentication and displays an error message.
- [x] AC3: An authenticated user must be able to maintain an authenticated session.

### Technical notes
- Authentication is handled by the backend.
- Access tokens must be used to protect authenticated resources.

**Estimation:** 5 SP  
**Priority:** High

---

## HU-TRANS-001: Capture Sign Through Camera

**As** a sign language user  
**I want** to use my device's camera to capture my signs  
**So that** the application can analyze my movements.

### Acceptance criteria
- [x] AC1: Given camera permission is granted, when the user starts translation, then the application activates the camera.
- [x] AC2: Given camera permission is not granted, when the user starts translation, then the application requests the required permission.
- [x] AC3: The application must provide visual feedback while the camera is being used.

### Technical notes
- Camera access is implemented on the mobile application.
- The captured movement data is processed for sign recognition.

**Estimation:** 8 SP  
**Priority:** High

---

## HU-TRANS-002: Recognize Signs

**As** a sign language user  
**I want** the application to recognize my signs  
**So that** my movements can be converted into a meaningful result.

### Acceptance criteria
- [x] AC1: Given valid camera input, when the user performs a supported sign, then the system generates a prediction.
- [ ] AC2: The prediction must correspond to a sign included in the available recognition dataset.
- [x] AC3: If the system cannot confidently recognize a sign, it must indicate that the result could not be determined.

### Technical notes
- TensorFlow.js is used for the sign recognition model.
- Movement and landmark information can be processed before inference.
- The initial model will only support the signs included in the available dataset.

**Estimation:** 13 SP  
**Priority:** High

---

## HU-TRANS-003: Translate Sign Into Text

**As** a hearing person  
**I want** recognized signs to be displayed as text  
**So that** I can understand the message being communicated.

### Acceptance criteria
- [x] AC1: Given a recognized sign, when the prediction is generated, then the corresponding text must be displayed.
- [ ] AC2: The translated text must be clearly visible to the user.
- [x] AC3: If no valid sign is recognized, the application must not display an incorrect translation as a confirmed result.

### Technical notes
- Translation results are generated from the sign recognition model.
- The supported vocabulary depends on the available sign dataset.

**Estimation:** 8 SP  
**Priority:** High

---

## HU-TRANS-004: Translate Sign Into Audio

**As** a hearing person  
**I want** the translated sign to be converted into audio  
**So that** I can hear the communicated message.

### Acceptance criteria
- [x] AC1: Given a valid text translation, when the user requests audio output, then the application reproduces the translated message.
- [ ] AC2: The user must be able to identify when audio output is available.
- [ ] AC3: If there is no valid translation, the application must not generate an incorrect audio message.

### Technical notes
- Audio output is based on the generated text translation.
- The implementation must consider the selected application language.

**Estimation:** 5 SP  
**Priority:** High

---

## HU-ALPHABET-001: View Sign Language Alphabet

**As** a user  
**I want** to view the sign language alphabet  
**So that** I can learn and identify individual signs.

### Acceptance criteria
- [x] AC1: The user must be able to access the alphabet section.
- [x] AC2: The application must display the available letters and their corresponding signs.
- [ ] AC3: The information must be presented in an accessible and understandable way.

### Technical notes
- The available alphabet content depends on the project's validated resources.

**Estimation:** 5 SP  
**Priority:** Medium

---

## HU-HISTORY-001: Save Translation History

**As** an authenticated user  
**I want** my translations to be stored  
**So that** I can consult them later.

### Acceptance criteria
- [x] AC1: Given a completed translation, when the translation is finalized, then the result can be stored in the user's history.
- [x] AC2: Each history entry must be associated with the corresponding user.
- [x] AC3: The history must contain enough information to identify the translated result.

### Technical notes
- Structured history data is stored through the backend.
- User identification must be handled securely.

**Estimation:** 8 SP  
**Priority:** Medium

---

## HU-HISTORY-002: View Translation History

**As** an authenticated user  
**I want** to view my previous translations  
**So that** I can review information I have translated before.

### Acceptance criteria
- [x] AC1: The user must be able to access their translation history.
- [x] AC2: The system must only display history entries belonging to the authenticated user.
- [ ] AC3: If the user has no previous translations, the application must display an appropriate message.

### Technical notes
- History information is retrieved through the backend API.

**Estimation:** 5 SP  
**Priority:** Medium

---

## HU-PROFILE-001: Manage User Preferences

**As** a user  
**I want** to configure my application preferences  
**So that** I can use the application according to my needs.

### Acceptance criteria
- [x] AC1: The user must be able to select the available application language.
- [x] AC2: The user must be able to configure the available visual theme preferences.
- [ ] AC3: The selected preferences must be applied throughout the application.

### Technical notes
- The application currently supports multiple interface languages.
- Preferences must be associated with the corresponding user when applicable.

**Estimation:** 5 SP  
**Priority:** Medium

---

## HU-ADMIN-001: Manage Users

**As** an administrator  
**I want** to manage registered users  
**So that** I can supervise access to the system.

### Acceptance criteria
- [ ] AC1: The administrator must be able to access user management.
- [x] AC2: The system must restrict administrative functionality to authorized administrators.
- [ ] AC3: The administrator must be able to view relevant user information.

### Technical notes
- Administrative operations must be protected by authorization controls.

**Estimation:** 8 SP  
**Priority:** Medium

---

## HU-ADMIN-002: View System Usage Statistics

**As** an administrator  
**I want** to view system usage statistics  
**So that** I can monitor how the application is being used.

### Acceptance criteria
- [x] AC1: The administrator must be able to access the statistics section.
- [x] AC2: The system must display relevant usage information.
- [x] AC3: Regular users must not have access to administrative statistics.

### Technical notes
- Statistics are restricted to the administrator role.
- The information must be obtained from registered system activity.

**Estimation:** 8 SP  
**Priority:** Medium

---

## HU-TRANS-005: Store AI Recognition Data

**As** the system  
**I want** to store relevant sign recognition data  
**So that** the recognition model and its results can be analyzed and improved.

### Acceptance criteria
- [x] AC1: Relevant recognition data must be stored with the corresponding metadata.
- [ ] AC2: Recognition results must be associated with a model version when applicable.
- [x] AC3: Confidence information should be preserved when available.
- [x] AC4: AI-related data must be separated from structured application data.

### Technical notes
- MongoDB is used for AI and vision-related data.
- PostgreSQL is used for structured application data.
- The two databases are coordinated through the backend using logical identifiers rather than direct foreign keys.

**Estimation:** 13 SP  
**Priority:** Medium

---

## HU-MODEL-001: Improve Sign Recognition Model

**As** the project team  
**I want** to update and improve the recognition model  
**So that** the application can achieve better sign recognition accuracy.

### Acceptance criteria
- [x] AC1: New validated sign samples can be incorporated into the dataset.
- [ ] AC2: Model changes must be validated before being integrated into the application.
- [ ] AC3: Each released model must have an identifiable version.
- [ ] AC4: The system must be able to identify which model version generated a recognition result.

### Technical notes
- Training data is stored separately from transactional application data.
- TensorFlow.js is used for model inference in the application.
- Model versions should be managed to allow controlled updates.

**Estimation:** 13 SP  
**Priority:** Medium

---

# Backlog Prioritization

## High Priority

1. HU-AUTH-001 — User Registration
2. HU-AUTH-002 — User Login
3. HU-TRANS-001 — Capture Sign Through Camera
4. HU-TRANS-002 — Recognize Signs
5. HU-TRANS-003 — Translate Sign Into Text
6. HU-TRANS-004 — Translate Sign Into Audio

## Medium Priority

7. HU-HISTORY-001 — Save Translation History
8. HU-HISTORY-002 — View Translation History
9. HU-ALPHABET-001 — View Sign Language Alphabet
10. HU-PROFILE-001 — Manage User Preferences
11. HU-ADMIN-001 — Manage Users
12. HU-ADMIN-002 — View System Usage Statistics
13. HU-TRANS-005 — Store AI Recognition Data
14. HU-MODEL-001 — Improve Sign Recognition Model

## Product Backlog Principles

The backlog is prioritized according to the value that each functionality provides to the main objective of Traduce Señas.

The core translation functionality has the highest priority because it directly addresses the communication problem identified during product definition.

Features that support the main translation flow, such as authentication and camera access, are also prioritized before secondary functionality such as history, administration, and model improvement.
