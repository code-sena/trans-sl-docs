# Security Threat Model

## 1. Objective

This document identifies the main security threats considered for the Traduce Señas project.

The analysis uses the **STRIDE** model to identify possible risks related to:

* Identity spoofing.
* Information tampering.
* Repudiation of actions.
* Information disclosure.
* Denial of service.
* Elevation of privileges.

The objective is to establish mitigation measures that allow user information to be protected and application security to be maintained.

---

## 2. Scope

The analysis mainly covers:

* Mobile application.
* Backend API.
* Authentication and authorization.
* PostgreSQL database.
* MongoDB database.
* User information.
* Translation history.
* Data used for sign language recognition.
* Administrative functionalities.

---

## 3. STRIDE Model

| Threat                     | Description                        | Example in Traduce Señas                                                          | Mitigation                                                                            |
| -------------------------- | ---------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Spoofing**               | Identity impersonation             | An attacker attempts to access the system using another user's credentials.       | Secure authentication, passwords stored using hashing, and authentication tokens.     |
| **Tampering**              | Data manipulation                  | An attacker modifies translation information or data sent to the backend.         | Input validation, authorization, and communication protection.                        |
| **Repudiation**            | Denial of an action performed      | A user or administrator denies having performed a particular operation.           | Event logging and auditing of relevant actions.                                       |
| **Information Disclosure** | Exposure of information            | Personal information or translation data becomes available to unauthorized users. | Access control, data protection, and application of the principle of least privilege. |
| **Denial of Service**      | Service interruption or saturation | An attacker makes numerous requests to the backend to affect its availability.    | Request validation, usage limits, and recovery mechanisms.                            |
| **Elevation of Privilege** | Obtaining higher permissions       | A user attempts to access functionalities exclusive to administrators.            | Role and permission control in the backend.                                           |

---

## 4. Spoofing — Identity impersonation

### Threat

An attacker could attempt to access a user's account using credentials obtained illegitimately.

### Potential impact

* Unauthorized access to the account.
* Access to translation history.
* Modification of profile information.
* Misuse of system functionalities.

### Mitigation

* Authentication using credentials.
* Secure password storage using hashing algorithms.
* Use of authentication tokens.
* Identity validation in protected requests.
* Role-based access control.

---

## 5. Tampering — Information manipulation

### Threat

An attacker could attempt to modify information sent between the mobile application and the backend or alter stored data.

### Potential impact

* Alteration of translation history.
* Modification of user information.
* Manipulation of data used by the system.
* Generation of incorrect information.

### Mitigation

* Validation of data received by the backend.
* Validation of types and formats.
* Authorization of operations.
* Protection of communications.
* Restriction of direct access to databases.

---

## 6. Repudiation — Repudiation

### Threat

A user or administrator could deny having performed an action within the system.

### Potential impact

The absence of records could make it difficult to determine who performed a specific operation.

### Mitigation

* Logging of relevant events.
* Logging of administrative actions.
* Auditing of important operations.
* Retention of basic information about the date and operation performed.

---

## 7. Information Disclosure — Information disclosure

### Threat

Information belonging to users could be exposed to people who do not have authorization.

### Information that must be protected

* User data.
* Credentials.
* Translation history.
* Preferences.
* Information related to application usage.
* Data used for sign language recognition.

### Potential impact

* Loss of privacy.
* Misuse of personal information.
* Unauthorized access to system information.

### Mitigation

* Access control.
* Authentication and authorization.
* Secure credential storage.
* Application of the principle of least privilege.
* Protection of communications.
* Separation of responsibilities between PostgreSQL and MongoDB.

---

## 8. Denial of Service — Denial of service

### Threat

An attacker could make an excessive number of requests to the backend with the objective of affecting system availability.

### Potential impact

* Application slowdown.
* Inability to perform translations.
* Resource saturation.
* Temporary service interruption.

### Mitigation

* Request validation.
* Request rate control.
* Usage limits when necessary.
* Proper error handling.
* Resource consumption monitoring.
* Failure recovery mechanisms.

---

## 9. Elevation of Privilege — Privilege escalation

### Threat

A user with normal permissions could attempt to access functionalities intended exclusively for administrators.

### Potential impact

* Unauthorized user administration.
* Access to administrative statistics.
* Modification of system information.
* Access to restricted functionalities.

### Mitigation

* Role implementation.
* Permission validation in the backend.
* Protection of administrative routes.
* Authorization verification before executing sensitive operations.
* Application of the principle of least privilege.

---

## 10. Authentication security

Authentication must allow the user's identity to be verified before granting access to protected functionalities.

Credentials must not be stored as plain text.

The backend must validate the tokens received in requests that require authentication.

Access to administrative functionalities must require specific permissions.

---

## 11. Data security

Traduce Señas uses different types of information that must be kept protected.

### PostgreSQL

It is used for structured information related to:

* Users.
* Roles.
* Permissions.
* Preferences.
* History.
* Translations.
* Audit trail: planned (TD-005), not implemented.

### MongoDB

It is used for information related to artificial intelligence processing, such as:

* Gesture samples in the `gesture_samples` collection: landmark sequences and their metadata (`sign_code`, `capture_session_id`, `recorded_by`).

Translation results and their confidence are stored in PostgreSQL (`recognition` database), not in MongoDB.

Access to both databases must be performed through the authorized backend components.

---

## 12. Administrator security

Administrative functionalities must be protected through authentication and authorization.

A regular user must not be able to directly access functionalities such as:

* User management.
* Consultation of administrative statistics.
* Management of system information.
* Operations reserved for administrators.

---

## 13. Principle of least privilege

Each user, service, or component must have only the permissions necessary to perform its functions.

This helps reduce the potential impact of a compromised account or component.

---

## 14. Error handling

Error messages must not reveal unnecessary internal information.

For example, the following must not be exposed:

* Passwords.
* Tokens.
* Database credentials.
* Internal structures.
* Sensitive system information.

Errors must be controlled and presented through appropriate responses for the client.

---

## 15. Threat model status

The STRIDE model presented establishes the main threats considered for the Traduce Señas architecture.

These measures must be reviewed and updated as the architecture evolves, especially during a future migration toward a microservices-based architecture.

New architectural decisions must reassess risks related to:

* Communication between services.
* Authentication between components.
* Authorization.
* API protection.
* Data management.
* Observability and auditing.

---

## 16. Controls in place

This section lists what the code and the compose files implement against the threats above (checked on 2026-11-04). Gaps are marked as such.

* **Spoofing:** passwords are hashed with bcrypt in `iam-service`. Tokens are HS256 JWTs signed with `JWT_SECRET`; every service refuses to start with a secret shorter than 32 characters. Access tokens last one day (`JWT_EXPIRES_IN`, default `1d`). There are no refresh tokens. Google and Facebook sign-in verify the token with the provider.
* **Tampering:** request bodies are validated. For example, a malformed login body returns `400 INVALID_BODY`.
* **Repudiation:** gap. There is no audit trail yet (TD-005). Event logs are unstructured console output.
* **Information disclosure:** in the base compose file only the gateway is published on the host. PostgreSQL, MongoDB and the RabbitMQ panel are bound to `127.0.0.1`. Services and AMQP are not published. In production, Caddy terminates HTTPS.
* **Denial of service:** the gateway applies a per-IP rate limit (default 300 requests per minute) and a stricter one (default 10 per minute) on `/api/auth` endpoints such as login, register, verification, password reset and social login. There is no progressive lockout (TD-006 is partly open).
* **Elevation of privilege:** services check permissions and roles (`requirePermission` and `requireRole`). The administrative statistics endpoints require the statistics permission.
