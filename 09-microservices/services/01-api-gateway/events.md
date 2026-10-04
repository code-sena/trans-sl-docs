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

These are logs and headers, not domain events.

| Signal | Where | Purpose |
|--------|-------|---------|
| `X-Correlation-Id` | Request header, generated if missing and forwarded to the upstream | Becomes `metadata.correlationId` of the events the upstream publishes |
| Access log line | Standard output | method, path, status, latency, `sub`, correlation id |
| `401`, `429` responses | HTTP | Invalid / missing JWT, rate limit exceeded |
