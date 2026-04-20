# Contributing to Migflow

Thank you for your interest in contributing. This document covers everything you need to get started.

---

## Table of Contents

- [Getting started](#getting-started)
- [Workflow](#workflow)
- [Commit conventions](#commit-conventions)
- [Validation](#validation)
- [Backend guidelines](#backend-guidelines)
- [Frontend guidelines](#frontend-guidelines)
- [Opening a pull request](#opening-a-pull-request)

---

## Getting started

**Prerequisites:** Ruby 3.3, Node 22.

```bash
git clone https://github.com/jv4lentim/migflow.git
cd migflow
bin/setup
```

`bin/setup` installs Ruby gems and frontend dependencies in one step.

---

## Workflow

1. **Open an issue first** for bugs or features — agree on the approach before writing code.
2. Fork the repo and create a branch from `main`:
  ```bash
   git checkout -b fix/missing-index-warning
  ```
3. Make your changes, keep commits focused (one logical change per commit).
4. Run the full validation suite locally before pushing (see [Validation](#validation)).
5. Open a pull request against `main`.

Branch naming conventions:


| Prefix      | Use for                              |
| ----------- | ------------------------------------ |
| `feat/`     | New features                         |
| `fix/`      | Bug fixes                            |
| `ci/`       | CI/CD changes                        |
| `docs/`     | Documentation only                   |
| `refactor/` | Refactoring without behavior change  |
| `chore/`    | Maintenance (deps, tooling, configs) |


---

## Commit conventions

Migflow follows [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```
<type>(<optional scope>): <short description>

<optional body — explain the WHY, not the what>
```

### Rules

- **Subject line:** 72 characters max, imperative mood, no period at the end.
- **Body:** use it when the why is not obvious. Separate from subject with a blank line.
- **Breaking changes:** add `!` after the type and a `BREAKING CHANGE:` footer.

### Types


| Type       | Use for                                              |
| ---------- | ---------------------------------------------------- |
| `feat`     | New user-facing feature                              |
| `fix`      | Bug fix                                              |
| `ci`       | CI/CD pipeline changes (workflows, scripts)          |
| `docs`     | Documentation only                                   |
| `refactor` | Code change with no behavior change                  |
| `test`     | Adding or fixing tests                               |
| `chore`    | Maintenance — deps, tooling, configs that are not CI |
| `perf`     | Performance improvement                              |


### Examples

```
feat(warnings): add null column without default rule

fix(parser): handle migrations with frozen string literal comment

ci: add Ruby/Rails compatibility matrix to backend job

docs: add compatibility table to README

chore: bump rubocop to 1.70
```

---

## Validation

Run these before opening a PR. All must pass.

```bash
# Backend tests
bundle exec rake spec

# Ruby linter
bundle exec rubocop

# Frontend — from the frontend/ directory
npm ci
npm run lint
npm test
npm run build
```

The CI pipeline runs the same steps across Ruby 3.2/3.3 × Rails 7.0/7.1/7.2. If your change is only backend, you do not need to rebuild frontend assets.

---

## Backend guidelines

- Logic lives in `lib/migflow/` — keep it framework-agnostic where possible.
- Controllers under `app/controllers/migflow/` should stay thin: delegate to services.
- New rules belong in `lib/migflow/analyzers/rules/`, inheriting from `BaseRule`.
- Write RSpec specs for every new class. Keep unit tests isolated from Rails when the class does not need it.
- Do not lower the SimpleCov threshold (currently 80%). New code must be covered.

---

## Frontend guidelines

- Components live in `frontend/src/components/`.
- Use TypeScript. Avoid `any`.
- New components need at least a render test with Vitest + Testing Library.
- Do not add new npm dependencies without discussing in the issue first.
- Keep the bundle size in mind — check `npm run build` output for size regressions.

---

## Opening a pull request

- Fill in the PR description with what changed and why.
- Link the related issue (`Closes #N`).
- Keep PRs focused — one concern per PR is easier to review and revert.
- A PR that only touches documentation does not need new tests.
- Maintainers may ask for changes; address them in new commits (do not force-push during review).

