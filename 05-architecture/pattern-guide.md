# Pattern Guide

## 1. Objective

This document describes the design patterns used or defined for the Traduce Señas project.

The patterns allow the system's responsibilities to be organized, reduce coupling, and facilitate software maintenance and evolution.

The patterns defined for the project are:

* Singleton

* Factory Method

* Observer

* Command

---

## 2. Singleton

### Description

The **Singleton** pattern guarantees that a given class has a single instance throughout the application's execution cycle and provides a controlled access point to that instance.

### When to use it

In Traduce Señas, it is used for components that must maintain a single shared instance.

The main identified cases are:

* Global application configuration.

* Database connection management.

### Example in the project

```text
ConfiguracionApp

       │

       └──► A single instance
```

The global configuration can centralize information such as the application's language and theme.

Similarly, `DatabaseConnection` helps avoid the unnecessary creation of multiple connections.

### When NOT to use it

**Singleton** should not be used for classes that require multiple independent instances.

For example, translations should not be converted into Singletons because each translation represents an independent operation.

### Benefits

* Avoids duplicate instances.

* Centralizes shared resources.

* Reduces unnecessary resource consumption.

* Maintains a consistent global configuration.

---

## 3. Factory Method

### Description

The **Factory Method** pattern allows object creation to be encapsulated and delegates to specific classes the decision about which type of object should be created.

### When to use it

In Traduce Señas, it is used to manage different types of translations and the creation of certain types of notifications.

The types of translation considered are:

* Sign → Text.

* Text → Sign.

* Voice → Sign.

### Example in the project

```text
              TraduccionFactory

                    │

         ┌──────────┼──────────┐

         ▼          ▼          ▼

     SenaTexto    TextoSena    VozSena
```

The factory allows the creation logic to be separated from the main application logic.

### When NOT to use it

Factory Method should not be used when object creation is simple and there is no real need to abstract the creation process.

### Benefits

* Reduces conditionals related to object creation.

* Makes it easier to add new translation types.

* Separates object creation from business logic.

* Promotes the Open/Closed Principle.

---

## 4. Observer

### Description

The **Observer** pattern allows an object to automatically notify other objects when an event or state change occurs.

### When to use it

In Traduce Señas, it is used to manage events that can generate different actions within the system.

For example, when a translation is saved, different responses can be generated:

```text
              EventManager

                   │

          TRANSLATION_SAVED

                   │

         ┌─────────┴─────────┐

         ▼                   ▼

UsageEventObserver    NotificationObserver

         │                   │

         ▼                   ▼

   Record usage       Evaluate notification
```

### Example in the project

When a translation is saved, the system can emit an event:

`TRANSLATION_SAVED`

The interested components receive the event and execute their respective actions.

### When NOT to use it

Observer should not be used when there is a simple and direct relationship between two components and there is no need to notify multiple objects.

### Benefits

* Reduces coupling between components.

* Allows the system to react to events.

* Makes it easier to add new observers.

* Allows different functionalities to be updated in response to the same event.

---

## 5. Command

### Description

The **Command** pattern encapsulates an action as an independent object.

This allows different actions to be executed, stored, and controlled in an organized manner.

### When to use it

In Traduce Señas, it is mainly used for actions related to profile configuration.

The identified actions include:

* Change language.

* Change theme.

* Change password.

### Example in the project

```text
             ProfileInvoker

                   │

         ┌─────────┼─────────┐

         ▼         ▼         ▼

      Change     Change     Change

      language    theme     password
```

Each action can be represented through an independent command.

### When NOT to use it

Command should not be used for extremely simple operations when encapsulating them as objects adds unnecessary complexity.

### Benefits

* Encapsulates actions.

* Makes it easier to maintain an operation history.

* Allows undo operations to be implemented when necessary.

* Separates the requester of an action from its executor.

---

## 6. Pattern summary

| Pattern        | Category   | Application in Traduce Señas                                  |
| -------------- | ---------- | ------------------------------------------------------------- |
| Singleton      | Creational | Global configuration and database connection                  |
| Factory Method | Creational | Creation of different types of translations and notifications |
| Observer       | Behavioral | Event and notification management                             |
| Command        | Behavioral | Profile-related actions                                       |

---

## 7. General usage criteria

Design patterns should not be used simply to add a known structure to the project.

Each pattern should be used when there is a specific design need that justifies its application.

In Traduce Señas, the following are intended to be maintained:

* Separation of responsibilities.

* Low coupling.

* High cohesion.

* Maintainable code.

* Component reuse.

* Ease of system evolution.

The application of patterns must remain aligned with the architecture defined for the project.
