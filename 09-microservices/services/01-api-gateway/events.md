# Events — API Gateway

> The gateway is an infrastructure component. It does **not publish or consume domain events** and does not connect to
> RabbitMQ. Domain events travel between the domain services only (exchange `traduce.events`, routing key
> `<service>.<event>`). The catalog of events is in `02-domain/domain-events.md` and per service in `../0N-*/events.md`.

## Events this service PUBLISHES

None.

## Events this service CONSUMES

None.

## Why

An event is a business fact. The gateway knows no business facts: it only sees HTTP requests. If a business fact must be
recorded because a request arrived (for example a section view for analytics), the domain service that handles the
request emits it, not the gateway.

## Request-level signals it does produce

These are HTTP answers and error logs, not domain events.

| Signal | Where | Purpose |
|--------|-------|---------|
| `401 UNAUTHORIZED` | HTTP | A request carries a token that is invalid or expired |
| `404 NOT_FOUND` | HTTP | The path is outside the routing table |
| `429 RATE_LIMITED` | HTTP | Rate limit exceeded |
| `502 BAD_GATEWAY` | HTTP | The upstream service does not answer |
| `[gateway] <service>: <message>` | Standard error output | Proxy error when an upstream fails (the gateway writes no access log) |
