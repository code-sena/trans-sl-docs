# ADR-002: JWT Authentication

## Status

* Accepted

## Date

2026-09-08

## Context

Traduce Señas requires an authentication mechanism that allows users to be identified and protects functionalities that require authorized access.

The mobile application communicates with the backend through an API, so it is necessary to establish a mechanism that allows authentication to be maintained between requests made by the client and protected backend resources.

Additionally, the system considers different levels of access, especially between end users and administrators.

## Decision

It is decided to use **JSON Web Tokens (JWT)** as the authentication mechanism for protected requests to the Traduce Señas API.

After successfully authenticating, the user will receive a token that will be used to access resources that require authentication.

The backend must validate the token before allowing access to protected resources.

Authorization will be complemented by a **roles and permissions** system, allowing the available operations for end users and administrators to be differentiated.

## Alternatives considered

### Alternative 1 — Session-based authentication

Maintain sessions stored on the server to identify authenticated users.

**Advantages:**

* It is a known and widely used mechanism.
* Allows sessions to be invalidated directly from the server.
* Authentication state is maintained centrally.

**Disadvantages:**

* Requires maintaining session information on the server.
* May add complexity when the system evolves toward multiple services.
* Requires additional mechanisms to share or manage sessions between different components.

### Alternative 2 — JSON Web Token (JWT)

Use signed tokens to represent user authentication.

**Advantages:**

* Adapts to API-based communication.
* Allows authentication to be validated on each request.
* Facilitates future evolution toward a microservices-based architecture.
* Reduces the need to maintain traditional sessions on the server.

**Disadvantages:**

* Token expiration and renewal management requires planning.
* A compromised token can be used until it expires or is invalidated through additional mechanisms.

## Justification

JWT is selected because Traduce Señas uses a mobile application that communicates with a backend through an API.

This mechanism allows protected requests to include a token that can be validated by the backend before accessing the corresponding resources.

Additionally, the decision is compatible with the project's planned evolution toward a microservices-based architecture, where different services may need to validate request authentication.

## Consequences

### Positive

* Protection of API resources.
* Separation between authentication and business logic.
* Facilitates access control through roles.
* Supports future evolution toward microservices.
* Allows the mobile client to use the same authentication mechanism for different protected requests.

### Negative

* Token expiration must be managed correctly.
* Tokens stored on the client must be adequately protected.
* Tokens must be validated on protected backend resources.

## Impact on architecture

The decision mainly affects:

* Mobile application.
* Backend API.
* Authentication middleware.
* Roles and permissions system.
* Protected API resources.

The general flow will be:

```text
User
   │
   ▼
Mobile application
   │
   │ Credentials
   ▼
Backend
   │
   │ Successful authentication
   ▼
JWT
   │
   ▼
Mobile application
   │
   │ Request + JWT
   ▼
Authentication middleware
   │
   ├── Valid token ──► Protected resource
   │
   └── Invalid token ─► Access denied
```
