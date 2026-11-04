# Cross-Cutting Concerns

## 1. Objective

Cross-cutting concerns are aspects that affect different components of the Traduce Señas system and that must be maintained consistently throughout development.

These concerns seek to ensure the security, maintainability, traceability, and proper functioning of the application.

---

## 2. Authentication and authorization

The system must control user access through authentication and authorization mechanisms.

Authentication allows verifying the user's identity before accessing protected functionalities.

Authorization allows controlling the functionalities available according to the type of user.

The main identified roles are:

* **User:** uses the main translation, history, profile, and alphabet functionalities.
* **Administrator:** supervises the system and has access to administrative functionalities, such as usage statistics.

The backend must centralize access validation to protected resources.

---

## 3. Error handling

Errors must be managed in a controlled manner to prevent an exception or failure in one component from causing the complete interruption of the application.

Errors related to the following must be considered:

* Authentication.
* Communication with the backend.
* Access to PostgreSQL.
* Access to MongoDB.
* Camera processing.
* Sign language recognition.
* Translations.
* Data validation.

Errors must provide useful information for diagnosis without exposing sensitive information to the user.

---

## 4. Logging and traceability

The system must maintain logging mechanisms that allow important events to be identified during its operation.

Relevant events include:

* Login.
* User registration.
* Important profile changes.
* Translations performed.
* Administrative operations.
* System errors.
* Events related to translation processing.

Logs must facilitate problem diagnosis and the tracking of important operations.

---

## 5. Auditing

Operations that require traceability must be able to be recorded through auditing mechanisms.

Auditing can be mainly used to:

* Record administrative actions.
* Record important changes to information.
* Identify operations performed on the system.
* Facilitate the investigation of errors or unexpected behavior.

Audit information must be managed independently from the main logic of the functionalities.

---

## 6. Configuration

System configurations must be kept separate from business logic.

Configurations related to the following must be considered:

* Database connections.
* Backend configuration.
* Service addresses.
* Execution parameters.
* Application configuration.
* Global preferences.

Sensitive configurations, such as database access credentials, must not be stored directly in the source code.

---

## 7. Data validation

Data received by the backend must be validated before being processed or stored.

Validation must be applied especially to:

* Registration data.
* Credentials.
* Profile information.
* Translation requests.
* Parameters received through the API.
* Information sent to the persistence systems.

Validation must be performed at the application's input boundaries to reduce errors and prevent invalid information.

---

## 8. Security

Security must be considered transversally across all Traduce Señas components.

The main measures include:

* Secure authentication.
* Role-based access control.
* Personal data protection.
* Input validation.
* Credential protection.
* Secure handling of authentication tokens.
* Avoiding the exposure of sensitive information through error messages.

The system must comply with the provisions related to the protection of personal data applicable to the project.

---

## 9. Performance

Performance is a cross-cutting concern because one of the main functionalities of the system is real-time translation.

The following must be considered especially:

* Camera processing.
* Recognition data processing.
* Inference using TensorFlow.js.
* Communication with the backend.
* Database access.
* Loading and querying history.

Operations must be designed to maintain appropriate response times for the user experience.

---

## 10. Retry and recovery handling

Operations that depend on external services or network communication must consider possible temporary failures.

When appropriate, controlled retry mechanisms may be used for operations that fail due to temporary causes.

Retries should be avoided when they may cause duplicate operations or data inconsistencies.

Current state: domain-event consumers retry through a shared helper (`subscribeWithRetry` in `packages/shared`), and messages that still fail go to a `<queue>.dead` queue. The iam outbox keeps events that are not yet published and retries them until they are. Email delivery is not retried automatically (see [ADR-007](./decisions/records/ADR-007-email-notifications.md)).

---

## 11. Observability

Observability must allow the general state of the system components to be known and facilitate the identification of problems.

The following must be considered:

* Event logs.
* Error logging.
* Backend status.
* Database status.
* Tracking of important operations.
* Information related to translation processing.

Current state: each service writes unstructured logs to the console, exposes `GET /health` (the gateway aggregates the services at `/health` and `/api/health`), and the Docker healthchecks use that endpoint. There is no metrics, distributed tracing or central log tool yet. See [13-operations/observability.md](../13-operations/observability.md).

---

## 12. Internationalization

The application supports different languages through a translation system.

The following are currently considered:

* Spanish.
* English.
* French.
* Portuguese.

Internationalization must be maintained as a cross-cutting concern so that the different application modules can use the same translation resources.

---

## 13. Accessibility

Accessibility is a cross-cutting concern due to the purpose of Traduce Señas.

The interface must prioritize:

* Clear visual elements.
* Intuitive navigation.
* Easy-to-identify buttons and controls.
* Visual feedback.
* Clear presentation of translation results.

These characteristics must be maintained consistently across the different application modules.

---

## 14. Cross-cutting concerns status

Cross-cutting concerns are part of the general system architecture and must be maintained throughout its evolution.

Some capabilities are conceptually defined, while others will need to be detailed through technical decisions and during implementation.

Event-based communication is in place: RabbitMQ carries the domain events (topic exchange `traduce.events`). No tool is in place yet for centralized logging, distributed traceability or centralized configuration; each service reads its configuration from environment variables.

These decisions may be formalized later through ADRs when a technical need arises from the evolution toward microservices.
