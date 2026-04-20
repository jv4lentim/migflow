# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Backend (Ruby gem)

```bash
bundle exec rake          # run tests + lint (default)
bundle exec rake spec     # run RSpec tests only
bundle exec rspec spec/path/to/file_spec.rb          # run a single spec file
bundle exec rspec spec/path/to/file_spec.rb:42       # run a single example by line
bundle exec rubocop       # lint
bundle exec rubocop -a    # auto-correct safe offenses
```

### Frontend (React/TypeScript)

```bash
npm ci                    # install dependencies
npm test                  # run Vitest unit tests
npm run lint              # ESLint
npm run build             # build to app/assets/
npm run dev               # dev server (Vite)
```

### Environment matrix (CI)

Tests run across Ruby 3.2/3.3 × Rails 7.0/7.1/7.2. Set `RAILS_VERSION` env var when running locally against a specific version (see Gemfile).

## Architecture

Migflow is a **mountable Rails engine** that provides migration visualization, schema diffs, and audit warnings via a REST API consumed by a React SPA.

### Data flow

```
db/migrate/*.rb  →  MigrationParser   →  Array<MigrationSnapshot>
db/schema.rb     →  SchemaParser      →  Hash of tables/columns/indexes

MigrationSnapshot  →  MigrationDslScanner  →  SnapshotBuilder
                                              (replays DSL calls to reconstruct
                                               schema state at any point in history)

before_snapshot + after_snapshot  →  DiffBuilder  →  SchemaDiff
                                  →  SchemaPatchBuilder  →  unified diff hunks
                                  →  AuditAnalyzer + 6 rules  →  Array<Warning>
                                  →  MigrationSummaryBuilder  →  human summary
```

### Key layers

| Layer | Location | Purpose |
|---|---|---|
| Parsers | `lib/migflow/parsers/` | Extract raw metadata from files on disk |
| Models | `lib/migflow/models/` | Immutable `Data.define` value objects |
| Services | `lib/migflow/services/` | Business logic (snapshot, diff, patch, summary) |
| Analyzers | `lib/migflow/analyzers/` | Audit rules returning `Warning` objects |
| Controllers | `app/controllers/migflow/api/` | JSON REST API |
| Frontend | `frontend/src/` | React SPA (Timeline, ERD canvas, diff panel) |

### API endpoints (mounted at `/migflow`)

- `GET /api/migrations` — list all migrations with summaries
- `GET /api/migrations/:id` — detail: schema before/after, patch hunks, warnings
- `GET /api/diff?from=&to=` — compare two arbitrary migration versions

### `SnapshotBuilder` — the core engine

`SnapshotBuilder` is the most complex service. It replays migration DSL calls sequentially using `MigrationDslScanner` (regex-based parser for `create_table`, `add_column`, `add_index`, `add_foreign_key`, etc.) to reconstruct exact schema state at any historical point. Understanding this file is essential before touching snapshot or diff logic.

### Audit rules (`lib/migflow/analyzers/rules/`)

Six rule classes, each implementing `#check(migration_content, tables:) → Array<Warning>`:
- `MissingIndexRule` — unindexed foreign keys
- `MissingForeignKeyRule` — `_id` columns without DB constraints
- `StringWithoutLimitRule` — string columns without `:limit`
- `MissingTimestampsRule` — tables missing `created_at`/`updated_at`
- `DangerousMigrationRule` — destructive ops (`remove_column`, `drop_table`, `rename_column`)
- `NullColumnWithoutDefaultRule` — `null: false` column added without `:default`

### Frontend

State is managed with **Zustand** (`src/store/`) and server state with **@tanstack/react-query**. The ERD canvas uses **@xyflow/react**. Build output lands in `app/assets/` and is served by the engine's asset pipeline.

## Conventions

- Commits follow **Conventional Commits** (`feat:`, `fix:`, `chore:`, etc.)
- Code coverage minimum: **80%** (enforced by SimpleCov in CI)
- String literals use **double quotes** (RuboCop enforced)
- Models use `Data.define` (Ruby 3.2+), not plain structs or `Struct.new`
- RuboCop metrics are relaxed (AbcSize: 60, MethodLength: 55) — do not lower them without discussion

## Development guidelines

### After every change

Always run the relevant checks after writing or modifying code — do not report a task complete before doing this:

- **New feature / new files:** update `CLAUDE.md` (architecture section if the new layer/service/rule is non-trivial), `README.md` (if the feature is user-facing — new API endpoint, config option, or UI capability), and `CONTRIBUTING.md` (if the feature introduces a new pattern contributors must follow). Skip a file only when the change genuinely does not affect it.


- **Backend change:** `bundle exec rspec` then `bundle exec rubocop`
- **Frontend change:** `npm test` then `npm run lint`
- **Both touched:** run all four

If any check fails, fix it before finishing.

### Ruby / Rails

- **SRP:** one class, one reason to change. Controllers only serialize/delegate; services own business logic; parsers own I/O and extraction. Do not mix concerns.
- **No fat services:** if a service method exceeds ~15 lines or handles more than one distinct concern, extract a collaborator.
- **DRY:** extract shared logic to a private method or a dedicated class. Never duplicate non-trivial logic across files.
- **No code smells:** avoid long parameter lists (prefer keyword args), deep conditional nesting, feature envy, and primitive obsession (use value objects / `Data.define`).
- **Query objects / service objects over callbacks:** keep models as plain value objects; do not add ActiveRecord callbacks or business logic to them.
- **Explicit over magic:** prefer explicit method calls over `method_missing`, `define_method` loops, or `send` unless there is a strong justification.

### React / TypeScript

- **SRP for components:** one component, one visual responsibility. Extract sub-components when a component grows beyond ~80 lines or handles more than one distinct piece of UI.
- **No business logic in components:** keep components presentational. Data fetching belongs in hooks (`src/hooks/`) or query hooks (`@tanstack/react-query`); derived state belongs in utils (`src/utils/`).
- **DRY hooks:** shared stateful logic (e.g., selecting a migration, toggling a panel) belongs in a custom hook, not copy-pasted across components.
- **Type everything:** no implicit `any`. Define domain types in `src/types/` and reuse them.
