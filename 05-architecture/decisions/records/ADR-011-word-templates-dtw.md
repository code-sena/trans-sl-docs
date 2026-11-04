# ADR-011: Words Added by the Administrator as DTW Templates before the Model

## Status

* Accepted

## Date

2026-11-04

## Context

The on-device recognition model only knows the glosses it was trained with. A new word, such as *triste*, is classified as whichever known sign looks most similar, sometimes with high confidence. Retraining the model to add one word is slow and needs a new training run.

The code already contains a second path for words: the administrator records a few takes of the word with the same engine that translates, and the app compares live signs against those takes before it asks the model.

This ADR records what the code does. It was written from the code, not from an earlier decision document; the original author of the change is not identified in the repository.

## Decision

Words added in the administration screen are **sign templates of kind `word`**, stored by `recognition-service`:

1. **Format.** A `word` template is a sequence of 30 frames with 128 values each (hands and shoulders), the same features the translation engine produces (`services/recognition-service/src/ia/domain/entity.ts`, frontend `featureBuilder.ts`).
2. **Storage.** Table `public.sign_templates` in PostgreSQL `recognition`. Migration `db/004_sign_templates_word_kind.sql` extends the `kind` check to `('static', 'motion', 'word')`. The `features` column is `JSONB`.
3. **Access.** `GET /api/sign-templates` is public, so the translation screen can download the list before the user signs in. `POST` (import) and `DELETE /:id` require a JWT and the permission `models.manage` (`src/ia/adapters/inbound/http/routes.ts`).
4. **Matching in the app.** Before the model runs, the engine (`modelWordEngine.web.ts`) resamples the sign to 30 frames and compares it with every word template by DTW (`wordTemplateMatcher.ts`): banded DTW (band 4) normalised by the average length.
5. **Acceptance.** If the closest template is at distance `<= templateMaxDistance` (default **2.5**, adjustable with `lscTune({ templateMaxDistance })`), that label is returned with confidence `clamp(1 - 0.3 * d / 2.5, 0.5, 0.95)`, so a match exactly at the threshold scores 0.7. Otherwise the model decides.

The threshold was measured on 434 dataset samples with five takes per word as templates; the table is in the comment above `templateMaxDistance`. The aim is that a known sign is not stolen by a template.

`recognition-service` does not compare or infer. It stores and serves the templates (`src/README.md`).

## Alternatives considered

### Alternative 1: retrain the model with a new class

Accurate once trained, but it needs a training run for each word and does not fix the "I do not know this sign" problem: the model must still be taught a rejection class. Kept as the long-term fix; it is not blocked by this decision.

### Alternative 2: match the words on the server

Would move the DTW work into `recognition-service`. Rejected for now: the translation engine runs on the client, and the server would then need the live sequence on every request.

## Consequences

**Positive:**
- A new word can be added in minutes, without retraining the model.
- The administrator's takes come from the same engine that translates, so the features match.
- The list of words is shared between devices, because it lives in PostgreSQL and not in each browser.

**Negative / trade-offs:**
- The model and the template list are independent. If they were not trained together, outputs can carry the wrong label (the engine warns about this).
- Matching runs on the client, so the threshold is a client setting, not a server rule.
- Words in the list can take precedence over the model; a bad threshold steals known signs.

**Impact on the system:**
- `recognition-service`: migration `004_sign_templates_word_kind.sql` (applied by hand to existing volumes; also listed in `docker-compose.yml` for new volumes), `src/ia`.
- Frontend: `WordEngineView` (embeds the web engine in a WebView on mobile), `wordTemplateMatcher.ts`, `modelWordEngine.web.ts`, `wordTemplates.service.ts`.
- Requirement: FR-411 in `04-requirements/functional.md`.

## References

- [ADR-003](ADR-003-database-separation.md) — `sign_templates` lives in PostgreSQL as JSONB
- [ADR-008](ADR-008-database-per-service.md) — `recognition` database
- `04-requirements/functional.md` — FR-411
