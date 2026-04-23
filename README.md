# Migflow

**Migration intelligence for Rails teams.**

Migflow is a Rails engine that mounts at `/migflow` and gives your team a visual timeline, schema diffs, and audit warnings — so you can understand migration impact before it reaches production.

[![CI](https://img.shields.io/github/actions/workflow/status/jv4lentim/migflow/ci.yml?branch=main&label=CI&style=flat)](https://github.com/jv4lentim/migflow/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE.txt)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.2-red)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-%3E%3D%207.0-cc0000)](https://rubyonrails.org/)

<img width="1281" height="484" alt="Kapture 2026-04-22 at 12 47 11" src="https://github.com/user-attachments/assets/25d10fb2-06c9-4476-92e8-bf77986948ed" />

---

## What it does

- **Timeline** — browse every migration in order, with version, name, and a one-line summary.
- **Detail view** — inspect raw migration content, schema snapshot, and audit warnings side by side.
- **Schema diff** — focused and full diff hunks powered by `schema.rb` patches between versions.
- **Compare mode** — pick any two migration versions and see exactly what changed.
- **Schema graph** — interactive ERD with tables, columns, foreign keys, and diff highlights.
- **CI report** — generate a Markdown or JSON report of all migrations and gate your pipeline on risk score.

## Requirements

- Ruby >= 3.2
- Rails 7.0 or newer
- A Rails app with migrations in `db/migrate` and a `db/schema.rb`

## Compatibility

Tested in CI against every combination below:

|            | Rails 7.0 | Rails 7.1 | Rails 7.2 | Rails 8.1 |
|------------|:---------:|:---------:|:---------:|:---------:|
| Ruby 3.2   | ✅        | ✅        | ✅        | ✅        |
| Ruby 3.3   | ✅        | ✅        | ✅        | ✅        |
| Ruby 3.4   | ✅        | ✅        | ✅        | ✅        |
| Ruby 4.0   | ✅        | ✅        | ✅        | ✅        |

## Installation

Add Migflow to your `Gemfile` (Git source until the first RubyGems release):

```ruby
gem "migflow", git: "https://github.com/jv4lentim/migflow"
```

```bash
bundle install
```

Mount the engine in your routes:

```ruby
# config/routes.rb
mount Migflow::Engine, at: "/migflow"
```

Start your app and open [http://localhost:3000/migflow](http://localhost:3000/migflow).

## Configuration

All options are set in an initializer:

```ruby
# config/initializers/migflow.rb
Migflow.configure do |config|
  # ...
end
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `migrations_path` | `db/migrate` | Path to the migrations directory |
| `schema_path` | `db/schema.rb` | Path to the schema file |
| `enabled_rules` | `:all` | Audit rules to run. Pass an array of rule name symbols to enable a subset, or `:all` to run every rule |
| `expose_raw_content` | `true` | Whether to include the migration source code in the API response. Set to `false` to hide it |
| `parent_controller` | `"ActionController::Base"` | Controller class Migflow inherits from. Set to your app's `ApplicationController` to inherit authentication helpers |
| `authentication_hook` | `nil` | A lambda run as a `before_action` on every Migflow request. Use it to enforce authentication |
| `unauthenticated_redirect` | `nil` | A lambda returning the path to redirect to when authentication fails. Required when `authentication_hook` is set, because host app route helpers must be accessed via `main_app.<helper>` inside a mounted engine |

### Authentication

Migflow has no authentication out of the box. To protect the dashboard, set `parent_controller` to inherit your app's auth helpers, provide an `authentication_hook` to enforce the check, and set `unauthenticated_redirect` to tell Migflow where to send unauthenticated requests.

**Rails 8 built-in Authentication**

```ruby
Migflow.configure do |config|
  config.parent_controller        = "ApplicationController"
  config.authentication_hook      = -> { require_authentication }
  config.unauthenticated_redirect = -> { main_app.new_session_path }
end
```

**Devise**

```ruby
Migflow.configure do |config|
  config.parent_controller        = "ApplicationController"
  config.authentication_hook      = -> { authenticate_admin! }
  config.unauthenticated_redirect = -> { main_app.new_admin_session_path }
end
```

## API

The frontend talks to these JSON endpoints under `/migflow/api`:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/migrations` | List all migrations for the timeline |
| `GET` | `/migrations/:version` | Migration detail — warnings and schema patch |
| `GET` | `/diff?from=:version&to=:version` | Schema diff between two versions |

## CI report

Run the analysis from the command line without starting a server:

```bash
# Markdown summary (default)
bundle exec rails migflow:report

# JSON output for downstream tooling
bundle exec rails migflow:report FORMAT=json

# Gate: exit 1 if any migration has risk level high or above
bundle exec rails migflow:report FAIL_ON=high

# Gate: exit 1 if any migration scores 40 or above
bundle exec rails migflow:report FAIL_ON=40

# Write to a file instead of stdout
bundle exec rails migflow:report FORMAT=json OUTPUT=migflow-report.json
```

`FAIL_ON` accepts a level name (`low`, `medium`, `high`) or any integer score. Level names map to their minimum boundary (`high` → 71, `medium` → 31, `low` → 1), so `FAIL_ON=medium` catches medium **and** high migrations.

### GitHub Actions

```yaml
- name: Migration analysis summary
  run: bundle exec rails migflow:report FORMAT=markdown >> $GITHUB_STEP_SUMMARY

- name: Gate on high risk
  run: bundle exec rails migflow:report FAIL_ON=high
```

A ready-made workflow that triggers on pull requests touching `db/migrate/` is included at `.github/workflows/ci-report.yml`.

## Development

**Prerequisites:** Ruby 3.3, Node 22.

```bash
git clone https://github.com/jv4lentim/migflow.git
cd migflow
bin/setup
```

`bin/setup` installs Ruby and frontend dependencies. After that:

```bash
# Run tests
bundle exec rake spec

# Run linter
bundle exec rubocop

# Build frontend assets
cd frontend && npm run build

# Frontend dev server with hot reload (http://localhost:5173)
cd frontend && npm run dev
```

After rebuilding frontend assets, restart your Rails server to pick up the changes.

**Testing against a local Rails app:**

```ruby
# In your app's Gemfile:
gem "migflow", path: "../migflow"
```

## Limitations

- **Read-only.** Migflow only reads `db/migrate/` and `db/schema.rb` — it never runs migrations or writes to the database.
- **`schema.rb` required.** Projects using `structure.sql` are not supported yet.
- **Regex-based DSL parsing.** `SnapshotBuilder` replays migration DSL calls with a regex scanner. Highly dynamic migrations (metaprogramming, loops, `execute` with raw SQL) may produce incomplete snapshots.
- **No authentication out of the box.** See [Authentication](#authentication) to protect the dashboard before deploying to a shared environment.
- **Single-app only.** There is no support for multi-database setups or comparing migrations across separate Rails apps.

## Roadmap

Planned in rough priority order:

- [ ] `structure.sql` support
- [ ] Baseline / waiver system — suppress known warnings explicitly and traceably
- [ ] Cross-branch comparison — diff migrations between two git branches without switching

Have an idea? [Open a feature request](https://github.com/jv4lentim/migflow/issues/new?template=feature_request.yml).

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full guide.

## Code of Conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md).

## License

Migflow is released under the [MIT License](./LICENSE.txt).
