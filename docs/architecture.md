# Architecture

Migflow is a mountable Rails engine. The backend parses migration files and `schema.rb` on each request — no database tables, no background jobs. The frontend is a React SPA served as static assets from the engine's asset pipeline.

## High-level structure

```
Host Rails app
└── Migflow::Engine (mounted at /migflow)
    ├── app/controllers/migflow/api/   # JSON REST API
    ├── app/assets/migflow/            # Compiled frontend (React SPA)
    └── lib/migflow/
        ├── parsers/                   # File I/O and extraction
        ├── models/                    # Immutable value objects (Data.define)
        ├── services/                  # Business logic
        ├── analyzers/rules/           # Audit rules
        └── reporters/                 # CI report output formats
```

## Data flow

```
db/migrate/*.rb ──► MigrationParser ──► Array<MigrationSnapshot>
db/schema.rb    ──► SchemaParser    ──► Hash<table, columns+indexes>

MigrationSnapshot
  └──► MigrationDslScanner ──► SnapshotBuilder
                                (replays DSL calls to reconstruct
                                 schema state at each point in history)

before_snapshot + after_snapshot
  ├──► DiffBuilder         ──► SchemaDiff      (added/removed tables, columns, indexes)
  ├──► SchemaPatchBuilder  ──► unified diff hunks (schema.rb format)
  ├──► AuditAnalyzer       ──► Array<Warning>
  ├──► RiskScorer          ──► score (0–100) + level
  └──► MigrationSummaryBuilder ──► human-readable one-liner
```

## Layers

### Parsers (`lib/migflow/parsers/`)

Read files on disk and return structured data. No business logic.

| Class | Input | Output |
|---|---|---|
| `MigrationParser` | `db/migrate/*.rb` | `Array<MigrationSnapshot>` |
| `SchemaParser` | `db/schema.rb` | `Hash` of tables → columns + indexes |

### Models (`lib/migflow/models/`)

Immutable value objects using `Data.define` (Ruby 3.2+). No methods beyond accessors. Never subclass or add callbacks.

Key types: `MigrationSnapshot`, `SchemaDiff`, `Warning`, `MigrationDetail`.

### Services (`lib/migflow/services/`)

One class, one concern. Each takes plain Ruby values in and returns plain Ruby values out.

| Class | Responsibility |
|---|---|
| `SnapshotBuilder` | Replays DSL calls via `MigrationDslScanner` to reconstruct schema at any historical point. The most complex class in the codebase — read it first before touching snapshot or diff logic. |
| `DiffBuilder` | Compares two schema snapshots and produces a `SchemaDiff` |
| `SchemaPatchBuilder` | Generates unified diff hunks in `schema.rb` format |
| `MigrationSummaryBuilder` | Produces a one-line human summary from a `SchemaDiff` |
| `ReportGenerator` | Orchestrates the full pipeline for CI report output |

### Analyzers (`lib/migflow/analyzers/rules/`)

Six rule classes, each implementing `#check(migration_content, tables:) → Array<Warning>`.

| Rule | What it catches |
|---|---|
| `MissingIndexRule` | Foreign-key columns without an index |
| `MissingForeignKeyRule` | `_id` columns without a DB-level foreign key constraint |
| `StringWithoutLimitRule` | String columns declared without `:limit` |
| `MissingTimestampsRule` | Tables missing `created_at` / `updated_at` |
| `DangerousMigrationRule` | Destructive operations: `remove_column`, `drop_table`, `rename_column` |
| `NullColumnWithoutDefaultRule` | `null: false` column added without a `:default` |

Adding a new rule: create a class in `lib/migflow/analyzers/rules/`, inherit from `BaseRule`, implement `#check`, and register it in `AuditAnalyzer`.

### Controllers (`app/controllers/migflow/api/`)

Thin. Deserialize params, delegate to services, serialize JSON. No business logic lives here.

| Endpoint | Controller |
|---|---|
| `GET /api/migrations` | `MigrationsController#index` |
| `GET /api/migrations/:version` | `MigrationsController#show` |
| `GET /api/diff` | `DiffController#show` |

### Reporters (`lib/migflow/reporters/`)

Consumed by the `migflow:report` Rake task. Each reporter receives a `ReportGenerator` result and renders it to a string.

| Class | Format |
|---|---|
| `MarkdownReporter` | Human-readable table for terminal / GitHub Step Summary |
| `JsonReporter` | Machine-readable JSON for downstream tooling |

## Frontend

Built with React + TypeScript, bundled by Vite into `app/assets/migflow/`.

```
frontend/src/
├── api/client.ts          # fetch wrappers for the three REST endpoints
├── store/useSchemaStore.ts # Zustand store — selected version, compare target, view mode
├── hooks/
│   └── useSchemaComparisonData.ts  # central data hook — all React Query subscriptions
├── components/
│   ├── Timeline.tsx        # left-side migration list
│   ├── CompareBar.tsx      # base/target selectors and view mode switch
│   ├── SchemaCanvas.tsx    # ERD canvas (ReactFlow / @xyflow/react)
│   ├── SchemaDiffView.tsx  # unified diff panel (react-diff-view)
│   └── DetailPanel.tsx     # right-side code + warnings panel
└── types/migration.ts      # domain types shared across components
```

**State management:** Zustand for UI state (selected version, compare target, view mode, collapsed tables). React Query (`@tanstack/react-query`) for server state with a 30-second stale time.

**`useSchemaComparisonData`** is the single hook that all canvas/diff components consume. It derives `comparePairValid`, fetches the three or four queries needed, and returns ready-to-use data plus loading flags. Avoid duplicating query logic in individual components — extend this hook instead.

## Key design decisions

- **No database.** Everything is derived from files on disk. This means zero setup beyond mounting the engine and zero schema migrations to run in the host app.
- **Immutable models.** `Data.define` value objects keep services easy to test in isolation — pass data in, get data out, no shared mutable state.
- **`SnapshotBuilder` replays history.** Rather than storing pre-computed snapshots, the engine replays migration DSL calls in order using `MigrationDslScanner`. This trades CPU for simplicity — no persistence layer, no cache invalidation problem.
- **Asset pipeline over CDN.** The frontend is served as compiled static files by the engine's asset pipeline. No CDN dependency, works in air-gapped environments.
