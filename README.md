# Traduce Señas — project documentation

Traduce Señas is a mobile and web app that recognizes Colombian Sign Language (LSC) through the camera and turns it into text or synthesized speech. The MVP is one-way (sign → text/voice); see [scope](./01-context/scope.md).

- **Production:** <https://traducesenas.tech>
- **Android APK:** <https://tadeo77789.github.io/traducesenas-download/>
- **Language:** English is the main language of this repository ([ADR-001](./05-architecture/decisions/records/ADR-001-documentation-language.md)).

---

## Repositories

| Repository | Content |
|------------|---------|
| [code-sena/trans-sl-docs](https://github.com/code-sena/trans-sl-docs) | This documentation |
| [mauro-1508/backendTS](https://github.com/mauro-1508/backendTS) | Backend: API gateway and five microservices (Node.js, Express, TypeScript) |
| [tadeo77789/frontendTS](https://github.com/tadeo77789/frontendTS) | Mobile and web app (Expo, React Native, react-native-web) |
| [mauro-1508/traduce-senas-evidencias](https://github.com/mauro-1508/traduce-senas-evidencias) | SENA deliverables (ES/EN); its `docs/` folder is a copy of this repository |
| [tadeo77789/traducesenas-download](https://github.com/tadeo77789/traducesenas-download) | APK download page |

---

## Where to start

| If you want to... | Read |
|-------------------|------|
| Understand the product | [overview](./01-context/overview.md), [scope](./01-context/scope.md), [glossary](./01-context/glossary.md) |
| See the architecture | [05-architecture](./05-architecture/README.md), [ADR index](./05-architecture/decisions/README.md) |
| Find a service, its data and its events | [service catalog](./09-microservices/service-catalog.md) |
| Call the API | [07-api](./07-api/README.md) (OpenAPI contracts per service) |
| Run the system locally | [local setup](./10-devops/local-setup.md) |
| Know how the system is tested | [testing strategy](./11-quality/testing-strategy.md) |
| Follow the team rules | [git conventions](./00-governance/git-conventions.md), [definition of done](./00-governance/definition-of-done.md) |

---

## Section index

"Project" means the section describes Traduce Señas. "Template" means it still holds the generic framework text and has not been filled in for this project.

| # | Folder | Content | State |
|---|--------|---------|-------|
| 00 | [00-governance](./00-governance/README.md) | Git, DoD/DoR, security and documentation rules | Mostly template |
| 01 | [01-context](./01-context/README.md) | Vision, scope, glossary | Project |
| 02 | [02-domain](./02-domain/README.md) | Bounded contexts, entities, domain events | Project |
| 03 | [03-product](./03-product/README.md) | PRD, product vision, backlog | Project |
| 04 | [04-requirements](./04-requirements/README.md) | User stories, functional and non-functional requirements, traceability | Project |
| 05 | [05-architecture](./05-architecture/README.md) | ADRs, deployment, cross-cutting concerns | Project (except `hexagonal-architecture.md`) |
| 06 | [06-data](./06-data/README.md) | Data model, DBML, constraints, open items | Project |
| 07 | [07-api](./07-api/README.md) | OpenAPI contracts per service | Project |
| 08 | [08-uml](./08-uml/README.md) | Class and use case diagrams | Project |
| 09 | [09-microservices](./09-microservices/README.md) | Service catalog | Project |
| 10 | [10-devops](./10-devops/README.md) | Local setup, environments | Mixed (`environments.md` is template) |
| 11 | [11-quality](./11-quality/README.md) | Testing strategy | Mixed (`tdd-guide.md` is template) |
| 12 | [12-ux-ui](./12-ux-ui/README.md) | Design system, navigation map | Mixed |
| 13 | [13-operations](./13-operations/README.md) | Observability, incidents | Mixed |
| 14 | [14-training](./14-training/README.md) | Manuals and onboarding | Project |
| 15 | [15-project-control](./15-project-control/README.md) | Risks, technical backlog | Project |
| 99 | [99-archive](./99-archive/README.md) | Superseded documents | — |

---

## Origin of the structure

The folder structure, the templates and the guides ([`00-sdd-guide.md`](./00-sdd-guide.md), [`_stacks/`](./_stacks/README.md) and the generic parts of `00-governance/`) come from the **Microservices Governance Framework** by Jesús Ariel González Bonilla, released under the MIT license. The team filled the sections with the project's own content; sections marked as template above still keep the framework text.

---

## License

MIT. See [LICENSE](./LICENSE).
