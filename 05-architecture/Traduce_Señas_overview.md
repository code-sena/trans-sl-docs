# 05 — Architecture

# Architecture Overview

## 1. Architectural style

Traduce Señas uses an architecture oriented toward the separation of responsibilities and based on the principles of **Hexagonal Architecture (Ports and Adapters)**.

The system is designed to allow progressive evolution toward a microservices architecture. The separation of responsibilities aims to reduce coupling between the different components and facilitate their maintenance and evolution.

Currently, the system includes a mobile frontend developed with React Native and a backend developed with Node.js, Express, and TypeScript. The backend acts as an intermediary between the application and the persistence systems.

The architecture also includes the use of two storage technologies with different responsibilities:

* **PostgreSQL:** structured and transactional application information.
* **MongoDB:** information related to artificial intelligence, computer vision, and sign language recognition.

Communication between these components is coordinated by the backend through logical identifiers. PostgreSQL and MongoDB do not maintain relationships through direct foreign keys.

---

## 2. Architecture diagram

The general architecture of Traduce Señas can be represented as follows:

```text
┌──────────────────────────────┐
│            User              │
│                              │
│  Deaf / hearing person       │
└──────────────┬───────────────┘
               │
               │ Interaction
               ▼
┌──────────────────────────────┐
│        Mobile application    │
│        React Native          │
│                              │
│ ┌──────────────────────────┐ │
│ │ Camera                   │ │
│ │ Sign language recognition│ │
│ │ TensorFlow.js            │ │
│ │ User interface           │ │
│ └──────────────────────────┘ │
└──────────────┬───────────────┘
               │
               │ HTTP / REST
               ▼
┌──────────────────────────────┐
│         Backend API          │
│ Node.js + Express + TypeScript│
│                              │
│ ┌──────────────────────────┐ │
│ │ Use cases               │ │
│ │ Ports                   │ │
│ │ Adapters                │ │
│ │ Authentication          │ │
│ │ Application logic       │ │
│ └──────────────────────────┘ │
└───────┬──────────────┬───────┘
        │              │
        │              │
        ▼              ▼
┌───────────────┐  ┌────────────────┐
│  PostgreSQL   │  │    MongoDB     │
│               │  │                │
│ Structured    │  │ AI and         │
│ data          │  │ computer vision│
│               │  │ data           │
└───────────────┘  └────────────────┘
```
