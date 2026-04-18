# Migflow

**Migration intelligence for Rails teams.**

Migflow is a Rails engine that mounts at `/migflow` and gives your team a visual timeline, schema diffs, and audit warnings — so you can understand migration impact before it reaches production.

[![CI](https://img.shields.io/github/actions/workflow/status/jv4lentim/migflow/ci.yml?branch=main&label=CI&style=flat)](https://github.com/jv4lentim/migflow/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE.txt)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.2-red)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-%3E%3D%207.0-cc0000)](https://rubyonrails.org/)

---

## What it does

- **Timeline** — browse every migration in order, with version, name, and a one-line summary.
- **Detail view** — inspect raw migration content, schema snapshot, and audit warnings side by side.
- **Schema diff** — focused and full diff hunks powered by `schema.rb` patches between versions.
- **Compare mode** — pick any two migration versions and see exactly what changed.
- **Schema graph** — interactive ERD with tables, columns, foreign keys, and diff highlights.

## Requirements

- Ruby >= 3.2
- Rails 7.0 or newer
- A Rails app with migrations in `db/migrate` and a `db/schema.rb`

## Compatibility

Tested in CI against every combination below:

|            | Rails 7.0 | Rails 7.1 | Rails 7.2 |
|------------|:---------:|:---------:|:---------:|
| Ruby 3.2   | ✅        | ✅        | ✅        |
| Ruby 3.3   | ✅        | ✅        | ✅        |

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

Migflow works out of the box with the Rails conventions (`db/migrate`, `db/schema.rb`). Override either path in an initializer if needed:

```ruby
# config/initializers/migflow.rb
Migflow.configure do |config|
  config.migrations_path = Rails.root.join("db/migrate")
  config.schema_path     = Rails.root.join("db/schema.rb")
  config.enabled_rules   = :all
end
```

## API

The frontend talks to these JSON endpoints under `/migflow/api`:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/migrations` | List all migrations for the timeline |
| `GET` | `/migrations/:version` | Migration detail — warnings and schema patch |
| `GET` | `/diff?from=:version&to=:version` | Schema diff between two versions |

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

## Contributing

Issues and pull requests are welcome. To contribute:

1. Open an issue describing the bug or feature.
2. Fork the repo and create a branch.
3. Run `bundle exec rake spec` and `bundle exec rubocop` before opening a PR.

Full contribution guidelines are coming in `CONTRIBUTING.md`.

## Code of Conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md).

## License

Migflow is released under the [MIT License](./LICENSE.txt).
