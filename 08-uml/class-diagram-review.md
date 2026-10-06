# Diagrama de clases del Backend: rehecho y comparado con el viejo

> **Fecha:** 2026-10-06 · **Commit de referencia:** `backendTS@497feef` (`origin/develop`, 2026-10-05, incluye `services/lexicon-service`).
> Escrito en español por la excepción de [ADR-001](../05-architecture/decisions/records/ADR-001-documentation-language.md) ("material dirigido a miembros del equipo").
> Sustituye a la versión del 2026-10-03, que se basaba en `backendTS@c142c80` (antes de `iam`, `analytics`, verificación de correo, estadísticas y `lexicon-service`).

## 1. Qué hay y de dónde sale

- **Diagrama viejo:** `Diagramas/DiagramaCL.puml` (y `Documentacion_DiagramaClases.md`) del repo `github.com/tadeo77789/TraduceSe-as`. Es un diseño en español con cinco paquetes: Singleton, Factory Method, Observer, Command y Dominio. No se importó a este repo.
- **Diagramas nuevos**, hechos leyendo el código con `git show 497feef:<ruta>`, no el working tree:

| Archivo (en `08-uml/diagrams/source/`) | Qué es |
|---|---|
| `class-backend-patterns.puml` (CL-01, principal) | Misma estructura de paquetes que el viejo. Lo que existe va `<<implementado>>`; lo que no, `<<propuesta>>` (gris, borde discontinuo) |
| `class-backend-overview.puml` | Un paquete por dominio y el microservicio `lexicon-service`, solo nombres |
| `class-backend-iam.puml`, `-auth`, `-users`, `-translations`, `-analytics`, `-ia`, `-shared` | Detalle por dominio del backend principal: atributos exactos, firmas, casos de uso, adaptadores, rutas |
| `class-lexicon-service.puml` | Detalle del microservicio `services/lexicon-service` (catálogo de señas, eventos, seguridad propia) |
| `class-backend-planned.puml` | Tablas del DBML sin código, todo `<<planned>>`, sin métodos |

Lo que **no** cubren: los commits que aún no están en `origin/develop` (por ejemplo, el arreglo de `main.ts` y el login con Google verificado en el servidor, que existen como commits locales sin subir) y los scripts de `src/domains/ia/training/`.

## 2. Cómo está hecho el código (y por qué el diagrama se ve así)

El backend principal es TypeScript **funcional**, no orientado a clases:

- Las entidades son `interface` (`User`, `Translation`, `Role`...).
- Los repositorios y adaptadores son **objetos literales** que cumplen una interface (`postgresUserRepository: UserRepository`).
- Los casos de uso son **funciones fábrica** `makeX(deps)` que devuelven una función.
- Cada dominio se arma en una función `makeXModule()`; `cmd/server/main.ts` los monta.
- Los servicios de dominio son objetos (`authDomainService`, `iamDomainService`...).
- Las `class` reales son los errores (`AuthError`, `AccountError`, `LexiconError` y sus hijas...).

`lexicon-service` sigue la misma forma, salvo los publicadores de eventos, que sí son clases (`RabbitMqEventPublisher`, `InMemoryEventPublisher`).

En PlantUML todo se dibuja como `class`, `interface` o `enum` con estereotipo. **Convención de estereotipos:**

| Estereotipo | Significa |
|---|---|
| `<<entity>>` | Tipo del dominio (en TS es `interface` o unión de literales) |
| `<<port in>>` / `<<port out>>` | Interface de entrada (servicio del dominio) / de salida (repositorio, hasher, mailer, token, permisos) |
| `<<use case>>` | Función `makeX(deps)`; las flechas van a los puertos de sus dependencias |
| `<<adapter in>>` | Controller, routes, middleware HTTP |
| `<<adapter out>>` | postgres, bcrypt, nodemailer, jwt, `pool`, RabbitMQ |
| `<<domain service>>` | Objeto o archivo de funciones con reglas del dominio |
| `<<module>>` | `makeXModule()` que cablea todo |
| `<<error>>` | Clase de error |
| `<<entrypoint>>` | `cmd/server/main.ts` o `services/lexicon-service/cmd/main.ts` |
| `<<implementado>>` / `<<propuesta>>` | Solo en CL-01: existe en `497feef` / patrón del diseño original sin código |
| `<<planned>>` | Solo en el diagrama planned: tabla del DBML sin código |

Los puertos de salida se **definen** casi siempre en `domain/repository.ts` y `ports/outbound/*.ts` los re-exporta. El diagrama usa el nombre del puerto y la nota dice dónde está el original.

## 3. Qué cambió desde la versión del 2026-10-03

| Tema | `c142c80` (antes) | `497feef` (ahora) |
|---|---|---|
| Dominios | auth, users, translations, ia | + `iam` (roles y permisos) y `analytics` (eventos de uso) |
| Microservicios | ninguno | `services/lexicon-service` (puerto 3003, base de datos propia, eventos a RabbitMQ) |
| Códigos de un solo uso | `PasswordResetToken`, `Math.random`, sin límite de intentos | `UserToken` (`EMAIL_VERIFICATION` / `PASSWORD_RESET`), `crypto.randomInt`, hash bcrypt, máximo 5 intentos, 60 s entre envíos y 5 por hora |
| Usuario | sin estado | `status` (`ACTIVE` / `INACTIVE` / `BLOCKED`) y `emailVerifiedAt`; registro crea la cuenta `INACTIVE` hasta verificar el correo |
| Rutas nuevas | — | `/api/iam/*`, `POST /auth/verify-email`, `POST /auth/resend-verification`, `GET /users/stats`, `DELETE /users/me`, `POST /users/me/password`, `GET /translations/stats`, `GET /translations/me/stats`, `/api/lexicon/*` |
| Control de acceso | `POST`/`DELETE /sign-templates` solo con JWT | Exigen el permiso `models.manage`; las estadísticas exigen `stats.read`; lexicon exige el rol `ADMIN` en el token |
| JWT | `{ user_id, email }` | `{ sub, user_id, email, roles }`; lexicon-service lo verifica con el mismo secreto (HS256) |
| Validación HTTP | DTO sin usar | zod en auth, users (cuenta), iam y analytics; translations e ia siguen sin zod |
| Patrones | ninguno real | Fábrica simple y publicador de eventos (lado "sujeto" del Observer) en lexicon-service |

## 4. Comparación con el diagrama viejo, elemento por elemento

Cada "existe" lleva ruta (relativa a `backendTS`).

| Viejo | En `497feef` | Estado en CL-01 |
|---|---|---|
| `DatabaseConnection` «Singleton» | `pool`, un `pg.Pool` creado una vez por módulo en `src/shared/database/postgres.ts`. Sin `getInstance`. lexicon-service crea su propio pool en `cmd/main.ts` | `pool` `<<implementado>>` |
| `ConfiguracionApp` «Singleton» | Otro concepto: `config` en `src/shared/config/config.ts` (puerto, BD, JWT, mailer). Idioma y tema no están en el código; son `user_preferences` en el DBML | `config` `<<implementado>>`; `ConfiguracionApp` se quita |
| `TraduccionFactory` + `TextoSena`/`SenaTexto`/`VozSena` | No existe la jerarquía. `makeCreateTranslation` valida e inserta sin ramificar por tipo. `texto_sena` y `voz_sena` están fuera del MVP pero el código y `migrations/001_translations.sql` los aceptan | `makeCreateTranslation` `<<implementado>>`; `TraduccionFactory` y `TraduccionSenaTextoFactory` `<<propuesta>>`; Texto/Voz se quitan |
| `NotificacionFactory`, `NotificacionPushFactory`, `INotificacion` | Sin código ni tabla. Solo el permiso `notifications.manage` (iam) y la sección `NOTIFICATIONS` (analytics). En el DBML hay `notifications` y `user_devices` | `<<propuesta>>` |
| `AlarmaFactory`, `AlarmaObserver` | No existe en código, Liquibase ni DBML | Se quitan |
| Observer: `IObserver`, `IObservable`, `GestorEventos` | `lexicon-service` publica `lexicon.SignPublished` y `lexicon.SignWithdrawn` por `EventPublisher` (RabbitMQ, exchange `traduce.events`, o en memoria). Es el lado "sujeto" vía broker; **ningún servicio se suscribe todavía** | `EventPublisher`, `RabbitMqEventPublisher`, `InMemoryEventPublisher` `<<implementado>>`; `IObserver` y `NotificacionObserver` `<<propuesta>>` |
| `EventoUsoObserver` | Lo sustituye el dominio `analytics`: `makeRecordUsageEvent` guarda en `public.usage_events` cuando el cliente llama `POST /events`. Es una llamada directa, no un observador, y en `497feef` el router de analytics no está montado | `makeRecordUsageEvent` `<<implementado>>` |
| Command: `ICommand`, `ComandoCambiarIdioma`, `ComandoCambiarTema`, `InvokerPerfil` | Sin código. Idioma y tema solo existen en Liquibase (`002_create_users.xml`) y en el DBML | `<<propuesta>>` |
| `ComandoCambiarPassword` | No es un comando: es el caso de uso `makeChangePassword` (`src/domains/users/application/change_password.ts`, `POST /api/users/me/password`), además de la recuperación forgot-password -> verify-code -> reset-password | Se quita |
| `Usuario` | `User` en `src/domains/users/domain/entity.ts`, ahora con `status` y `emailVerifiedAt`. Sin edad, tema ni idioma. `registrar` y `login` son casos de uso de auth; `logout` no existe | `User` `<<implementado>>`; sin métodos |
| `Traduccion` | `Translation` en `src/domains/translations/domain/entity.ts`, con borrado lógico | `<<implementado>>` |
| `LexicoSenas`, `RecursosMultimedia` | **Ahora existen** en `lexicon-service`: `Sign`, `Localization`, `MultimediaResource`, `Category` (`services/lexicon-service/src/domain/entity.ts`; tablas `sign_lexicon`, `sign_localizations`, `multimedia_resource`, `categories` en `db/003_lexicon.sql`). No confundir con `SignTemplate` (plantilla DTW del dominio `ia`) | `Sign` `<<implementado>>`; detalle en `class-lexicon-service.puml` |
| `SeccionUso` | Sin código. `analytics` guarda `session_id = null` a la espera de `user_sessions` (DBML) | Solo en planned |
| `PasswordResetToken` | Sustituido por `UserToken` (`src/domains/auth/domain/entity.ts`, tabla `user_tokens`) | `UserToken` `<<implementado>>` |
| `UsuarioAuth` (login social) | `makeGoogleLogin` está cableado en `AuthService.googleLogin` pero **ninguna ruta lo llama** y no se guarda el proveedor. Equivale a `user_auth_providers` del DBML | Solo en planned |
| `DispositivoUsuario`, `AuditoriaAccion`, `NotificacionPush` | Sin código. DBML: `user_devices`, `audit_logs`, `notifications` | Solo en planned |
| (no existía) roles y permisos | `Role` en `src/domains/iam/domain/entity.ts`; roles `USER`, `LINGUIST`, `ADMIN` y 13 permisos sembrados en `migrations/003_iam_roles_permissions.sql` | `Role` `<<implementado>>` |

**Añadido respecto al viejo:** el dominio `ia` (plantillas DTW), `iam`, `analytics`, `lexicon-service`, las entidades `New*`, los servicios de dominio, los errores, los puertos con sus firmas, los casos de uso, los adaptadores y las rutas HTTP.

**Importante: `<<propuesta>>` NO está implementado.** Son patrones del diseño original sin una línea de código. El diagrama no debe leerse como "el backend tiene Command" o "alguien escucha los eventos".

## 5. Problemas del código que los diagramas reflejan

1. **`main.ts` no pasa los adaptadores de iam a los módulos** (`cmd/server/main.ts` en `497feef`). Construye `roleReader`, `permissionChecker` y `adminGuard`, pero llama `makeAuthModule({ roleAssigner })` y `makeTranslationsModule/makeUsersModule/makeIaModule({ authMiddleware })`. Consecuencias: el login falla al leer los roles; `GET /users/stats`, `DELETE /users/me`, `GET /translations/stats` y `POST`/`DELETE /sign-templates` responderían 500. Además `makeAnalyticsModule` se importa pero **no se monta**. Hay un commit local sin subir que lo arregla (`8228aa1`).
2. **`postgresRoleChecker` usa tablas en singular** (`public.role`, `public.user_role`) y la migración crea `roles` y `user_roles`. Hoy nadie lo usa (`makeRequireRole` no está en ninguna ruta del backend principal).
3. **`translations` no valida con zod** y `resolveUserId` acepta `user_id` del body o de la query si falta el del token (fallback "para pruebas manuales").
4. **`makeGoogleLogin` no tiene ruta** y crea el usuario con `password: null` sin registrar el proveedor.
5. `SEQ_LEN = 16` está duplicado en `ia/domain/entity.ts` y `ia/domain/motion_template.ts`; `motion_template.ts` solo lo usan los scripts de `ia/training`.
6. `ia/ports/outbound/ai_service.ts` y `gesture_repository.ts` siguen siendo solo `export {}`.
7. Los DTO `*RequestDto` de auth y `CreateTranslationRequestDto` siguen definidos pero sin uso.
8. `lexicon-service` niega todas las operaciones de ADMIN por defecto (`ROLE_SOURCE=none`); para habilitarlas hay que configurar `ROLE_SOURCE=jwt` y el mismo `JWT_SECRET` (mínimo 32 caracteres) que el backend principal.

## 6. Cómo regenerar y validar

Con PlantUML instalado:

```bash
cd Docs/08-uml/diagrams
plantuml -checkonly source/class-*.puml
plantuml -tsvg -o ../exports source/class-*.puml
```

Con Docker (en Git Bash en Windows, `MSYS_NO_PATHCONV=1` evita que cambie las rutas):

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$PWD:/data" plantuml/plantuml -tsvg -o /data/exports /data/source/class-*.puml
```

Los 11 archivos se generaron sin errores con PlantUML 1.2026.8 (2026-10-06) y sus SVG están en `diagrams/exports/`. Si se exporta a PNG, PlantUML recorta a 4096 px de ancho; usar SVG.
