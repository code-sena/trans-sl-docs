# Git Conventions

> **Read this document before making your first commit on the project.**

## Branch strategy

```
main        ← Production. Merge from release only. Always stable.
  └── develop ← Continuous integration. Merge from features (Backend, Frontend).
        └── feat/[description]    ← One branch per feature/user story
        └── fix/[description]     ← One branch per bugfix
        └── chore/[description]   ← Infrastructure, docs, dependency changes
        └── hotfix/[description]  ← Urgent fixes directly to main
```

**Rules:**
- Nobody commits directly to `main` or `develop`
- Every task = one branch + one Pull Request
- One branch = one task (do not mix different features)
- Branches are deleted after merge

---

## Branch naming format

```
[type]/[description-in-kebab-case]

Examples:
feat/oauth2-login
fix/schedule-overlap-calculation
chore/update-spring-dependencies
hotfix/null-token-expiration
```

---

## Commit format (Conventional Commits)

```
[type]([scope]): [lowercase description, imperative mood, no trailing period]

[optional body — explain WHY, not what]

[optional footer — issue/user story references]
```

**Types:**
| Type | When to use |
|------|-------------|
| `feat` | New functionality |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, whitespace (no logic change) |
| `refactor` | Code refactoring without behavior change |
| `test` | Add or modify tests |
| `chore` | Tooling, dependencies, CI |
| `perf` | Performance improvement |

**Examples:**
```
feat(iam): implement JWT login

fix(scheduling): correct schedule overlap validation
Closes #42

docs(api): update actor service OpenAPI contract

chore(deps): upgrade Spring Boot to 3.2.0
```

---

## Pull Request policy

- **Size:** maximum 400 lines of code (excluding tests). If larger, split it.
- **Reviewers:** minimum 1 approval before merging
- **Review time:** reviewer has a maximum of 24 business hours
- **Template:** use the template at `.github/pull_request_template.md`
- **Green CI:** merge only proceeds if all pipeline checks pass

**Integration branch:** `develop` (Backend, Frontend). Docs: PRs go straight to `main`; the remote `dev` branch is stale and not used.

---

## Merge policy

- Use **Squash and Merge** for features (keeps `develop` history clean)
- Use **Merge Commit** for releases to `main` (preserves full history)
- **Do not** use Rebase & Merge (creates confusion in shared history)

---

## Tags and versioning

Follow [SemVer](https://semver.org/): `MAJOR.MINOR.PATCH`

```bash
# When releasing to production
git tag -a v1.2.0 -m "Release v1.2.0: add reports module"
git push origin v1.2.0
```

Backend and Frontend are versioned independently. The first release of both is `v1.0.0` (2026-10-19).

| Repo | Source of the version | Notes |
|------|-----------------------|-------|
| Backend | root `package.json` (`version`) | One version for all services. `GET /health` of the api-gateway reports it |
| Frontend | `app.json` (`expo.version`) | Shown in Profile and Admin. `expo.android.versionCode` goes up by 1 on every APK build |
| traducesenas-download | GitHub Release `vX.Y.Z` with the asset `traducesenas.apk` | Same version as the Frontend `expo.version` of that APK |

- `PATCH` for fixes, `MINOR` for new features, `MAJOR` for breaking API or app changes.
- Bump the version in a PR to `develop` before releasing; tag the commit on `main` after the release merge.
- Every tag gets a GitHub Release with generated notes: `gh release create v1.2.0 --generate-notes`.
- Docs and Evidencias are not versioned.
