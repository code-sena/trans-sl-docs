# Deployment

## 1. Objective

The deployment of Traduce Señas must allow the main components of the system to be executed in an organized manner, maintaining the separation between the mobile application, the backend, and the persistence systems.

The deployment strategy must consider the performance, scalability, compatibility, and fault tolerance needs defined for the project.

---

## 2. Deployment components

The solution is mainly composed of the following components:

| Component           | Technology                     | Responsibility                                                     |
| ------------------- | ------------------------------ | ------------------------------------------------------------------ |
| Mobile application  | React Native + TypeScript      | User interface and interaction                                     |
| Backend             | Node.js + Express + TypeScript | REST API and application logic                                     |
| Structured database | PostgreSQL                     | Storage of structured information                                  |
| AI database         | MongoDB                        | Storage of data related to recognition and artificial intelligence |
| Recognition engine  | TensorFlow.js                  | Sign language processing and recognition                           |

---

## 3. Development environment

During development, the system components can be executed in a local environment to facilitate implementation, integration, and testing.

The mobile application runs using React Native, while the backend runs as a Node.js service with Express.

The PostgreSQL and MongoDB databases provide the persistence services required by the backend.

```text
┌──────────────────────┐
│    Mobile application│
│     React Native     │
└──────────┬───────────┘
           │
           │ HTTP / REST
           ▼
┌──────────────────────┐
│       Backend        │
│ Node.js + Express    │
└──────────┬───────────┘
           │
      ┌────┴─────┐
      ▼          ▼
┌──────────┐ ┌──────────┐
│PostgreSQL│ │ MongoDB  │
└──────────┘ └──────────┘
```
