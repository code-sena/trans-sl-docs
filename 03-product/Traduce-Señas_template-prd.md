# Product Requirements Document — Traduce Señas

## 1. Product Overview

### Product Name

**Traduce Señas**

### Product Type

Mobile application for sign language recognition and translation.

### Product Summary

Traduce Señas is a mobile application designed to facilitate communication between deaf or hard-of-hearing people and hearing people who do not know sign language.

The application uses the device's camera to recognize supported signs and translate them into text or audio in real time.

---

## 2. Problem Statement

Deaf or hard-of-hearing people may experience communication barriers when interacting with hearing people who do not know sign language.

The limited availability of professional interpreters and the lack of general knowledge of sign language can make communication difficult in everyday situations, educational institutions, workplaces, healthcare services, public institutions, and commercial establishments.

Traduce Señas aims to provide an accessible technological alternative that can help reduce these communication barriers.

---

## 3. Product Vision

For deaf and hard-of-hearing people who need to communicate with hearing people who do not know sign language, **Traduce Señas** is a mobile sign language translation application that recognizes signs through the device's camera and translates them into text or audio in real time.

Unlike relying exclusively on professional interpreters or alternative communication methods, the product provides an accessible technological alternative designed to facilitate communication in everyday situations.

---

## 4. Target Users

### 4.1 Deaf or Hard-of-Hearing Users

Users who communicate through sign language and need to interact with hearing people.

### 4.2 Hearing Users

Users who do not know sign language but need to understand communication from a sign language user.

### 4.3 Administrators

Authorized users responsible for supervising and managing the system.

---

## 5. Product Goals

The main goals of Traduce Señas are:

- Reduce communication barriers between deaf and hearing people.
- Provide real-time sign recognition.
- Translate recognized signs into text.
- Provide audio output for translated messages.
- Provide an accessible and intuitive user experience.
- Support communication in everyday situations.
- Provide translation history for authenticated users.
- Allow administrators to monitor system usage.

---

## 6. Product Scope

### 6.1 Included in the Product

The current product includes:

- User registration and authentication.
- User profile management.
- Camera-based sign recognition.
- Real-time sign translation.
- Text translation output.
- Audio translation output.
- Translation history.
- Sign language alphabet.
- Language preferences.
- Theme preferences.
- Application notifications.
- Administrative user management.
- Administrative usage statistics.
- AI-related data management.
- Recognition model version management.

### 6.2 Out of Scope

The following features are outside the current product scope:

- Reverse translation from text or voice into signs.
- A 3D sign language avatar.
- Complete Colombian Sign Language vocabulary.
- Full offline functionality.
    
These features may be considered in future product iterations.

---

## 7. Functional Requirements

### FR-001 — User Registration

The system must allow new users to create an account using the required registration information.

### FR-002 — Authentication

The system must allow registered users to securely log in and access protected features.

### FR-003 — Sign Recognition

The application must use the device's camera to capture movement and recognize supported signs.

### FR-004 — Real-Time Translation

The application must provide a translation result when a supported sign is recognized.

### FR-005 — Text Output

The application must display the recognized sign as text.

### FR-006 — Audio Output

The application must provide an audio representation of the translated text.

### FR-007 — Translation History

The system must allow authenticated users to save and consult their previous translations.

### FR-008 — Sign Language Alphabet

The application must provide access to the available sign language alphabet.

### FR-009 — User Preferences

The system must allow users to configure available language and visual theme preferences.

### FR-010 — Administration

The system must provide authorized administrators with functionality for user management and system supervision.

### FR-011 — Usage Statistics

The system must provide administrators with relevant system usage statistics.

### FR-012 — AI Data Management

The system must support the storage and management of relevant sign recognition and AI-related data.

---

## 8. Non-Functional Requirements

### NFR-001 — Usability

The application should provide an intuitive interface that can be used without advanced technical knowledge.

### NFR-002 — Accessibility

The interface should use clear visual elements, understandable navigation, and accessible interaction patterns.

### NFR-003 — Performance

The application should process sign recognition and provide translation results with minimal delay during normal operation.

### NFR-004 — Security

User information and authentication data must be protected against unauthorized access.

Passwords must not be stored as plain text.

### NFR-005 — Privacy

Personal information must be handled according to applicable personal data protection requirements.

### NFR-006 — Availability

The application requires internet connectivity for its complete functionality.

### NFR-007 — Compatibility

The mobile application is intended to support Android and iOS devices compatible with the required camera and processing capabilities.

---

## 9. AI and Translation Requirements

The core translation functionality depends on a computer vision and machine learning process.

The general process is:

1. The user activates the camera.
2. The application captures movement.
3. Relevant landmark information is extracted.
4. The data is prepared for inference.
5. TensorFlow.js processes the information using the recognition model.
6. The model generates a prediction.
7. The application converts the prediction into a sign translation.
8. The result is displayed as text and can be reproduced as audio.
9. Relevant information may be registered for history or analysis.

The recognition model will initially support only the signs available in the validated dataset.

---

## 10. Data Requirements

### Structured Application Data

Structured application information includes:

- Users.
- Credentials.
- Roles.
- Permissions.
- User preferences.
- Translation history.
- Translation information.
- Administrative information.
- Audit-related information.

### AI and Vision Data

AI-related information may include:

- Movement samples.
- Landmark coordinates.
- X, Y, and Z coordinates.
- Sequences and frames.
- Sign labels.
- Training, validation, and testing data.
- Model metadata.
- Model versions.
- Inference results.
- Confidence values.
- Capture timestamps.

Structured application data and AI-related data are managed separately and coordinated through the backend.

---

## 11. User Experience Requirements

The application should provide:

- Clear navigation.
- Simple interaction flows.
- Large and understandable buttons.
- Clear iconography.
- Appropriate visual contrast.
- Camera feedback during recognition.
- Clearly visible translation results.
- Accessible audio controls.
- Appropriate feedback when recognition fails.
- Support for the available application languages.

---

## 12. Success Criteria

The product will be considered successful when:

- Users can register and authenticate successfully.
- Users can access the camera for sign recognition.
- Supported signs can be recognized by the system.
- Recognized signs can be translated into text.
- Translations can be reproduced as audio.
- Users can consult their translation history.
- The application provides an accessible and understandable interface.
- Administrators can supervise relevant system activity.
- Recognition results can be evaluated and improved through validated data.

---

## 13. Constraints

The product has the following known constraints:

- The initial sign recognition dataset is limited.
- Complete functionality requires internet connectivity.
- Recognition performance depends on the device's hardware capabilities.
- Real-time recognition must be validated in realistic usage scenarios.
- Translation accuracy depends on the quality and coverage of the available dataset.
- Certified sign language interpreters are required for validation of translations and sign data.

---

## 14. Dependencies

The product depends on:

- Mobile device camera capabilities.
- Internet connectivity.
- Backend services.
- PostgreSQL for structured application data.
- MongoDB for AI and vision-related data.
- TensorFlow.js for model inference.
- A validated sign language dataset.
- Certified sign language interpreters for validation.

---

## 15. Risks

### Risk 1 — Limited Dataset

A limited number of supported signs may reduce recognition coverage.

### Risk 2 — Recognition Accuracy

Incorrect predictions may affect the usefulness of the translation functionality.

### Risk 3 — Device Performance

Different device hardware may affect real-time recognition performance.

### Risk 4 — Internet Dependency

The requirement for connectivity may limit use in environments with poor or unavailable internet access.

### Risk 5 — User Adoption

Users may be reluctant to adopt the application if the interface is difficult to use or recognition accuracy is insufficient.

---

## 16. Future Considerations

Future iterations may consider:

- Expanding the supported sign vocabulary.
- Improving recognition accuracy.
- Adding additional validated datasets.
- Improving model versions.
- Supporting additional accessibility features.
- Evaluating offline capabilities.
- Evaluating reverse translation.
- Evaluating 3D or animated sign representations.

These features are not part of the current product scope and should only be considered after the core product has been validated.

---

## 17. References

The product requirements are based on the project's Software Requirements Specification (SRS), which defines the problem, users, scope, functional requirements, non-functional requirements, constraints, assumptions, and objectives of Traduce Señas.

The SRS references IEEE 830-1998 for software requirements specification practices and Colombian Law 1581 of 2012 regarding personal data protection.