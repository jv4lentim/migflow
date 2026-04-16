# Migflow

Migration intelligence for Rails teams.

Migflow is a Rails engine that mounts at `/migflow` and gives you a visual timeline, schema diffs, and migration warnings so you can understand migration impact before shipping.

[![CI](https://github.com/joaovalentim/migflow/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/joaovalentim/migflow/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE.txt)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.1-red)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-%3E%3D%207.0-cc0000)](https://rubyonrails.org/)

## Table of contents

- [Why Migflow](#why-migflow)
- [Features](#features)
- [Requirements](#requirements)
- [Install in a Rails app](#install-in-a-rails-app)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [API surface](#api-surface)
- [Demo and screenshots](#demo-and-screenshots)
- [Development](#development)
- [Limitations](#limitations)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Code of conduct](#code-of-conduct)
- [License](#license)

## Why Migflow

- Prevent schema regressions by making migration impact visible.
- Compare versions to understand exactly what changed in `schema.rb`.
- Audit migration history with warnings for common risky patterns.

## Features

- Timeline of migrations with version, name, and short summary.
- Detail view for a migration with schema snapshot and warnings.
- Schema patch view (focused and full views) powered by diff hunks.
- Compare mode between two migration versions.
- Graph-like schema visualization mode and side detail panel.

## Requirements

- Ruby `>= 3.1`
- Rails `>= 7.0`
- A Rails app with migration files in `db/migrate`
- A schema file in `db/schema.rb`

## Install in a Rails app

Add Migflow to your app `Gemfile` (Git source for now):

```ruby
gem "migflow", git: "https://github.com/jv4lentim/migflow"
```

Then install:

```bash
bundle install
```

Mount the engine in your app routes:

```ruby
# config/routes.rb
mount Migflow::Engine, at: "/migflow"
```

Open:

```text
http://localhost:3000/migflow
```

## Quick start

1. Add and mount Migflow in your Rails app.
2. Boot your app (`bin/dev` or `bin/rails server`).
3. Navigate to `/migflow`.
4. Done!

## Configuration

By default Migflow reads from:

- `db/migrate`
- `db/schema.rb`

You can override this in an initializer:

```ruby
# config/initializers/migflow.rb
Migflow.configure do |config|
  config.migrations_path = Rails.root.join("db/migrate")
  config.schema_path = Rails.root.join("db/schema.rb")
  config.enabled_rules = :all
end
```

## API surface

Migflow's frontend consumes these endpoints under `/migflow/api`:

- `GET /migrations` - list migrations for the timeline
- `GET /migrations/:version` - migration detail with warnings and schema patch
- `GET /diff?from=:version&to=:version` - comparison diff between two migrations

## Demo and screenshots

Visual demo assets are being prepared as part of the open source roadmap.

Planned demo flow:

- Timeline selection
- Migration detail with warnings
- Compare mode
- Schema diff expansion/collapse

## Development

Clone and setup:

```bash
git clone https://github.com/jv4lentim/migflow.git
cd migflow
bin/setup
```

Run quality checks:

```bash
bundle exec rake test
bundle exec rubocop
```

Frontend workspace (`frontend/`) is Vite + React + TypeScript:

```bash
cd frontend
yarn install
yarn run build
```

## Limitations

- Current docs are still evolving toward a full OSS onboarding experience.
- Gem version badge on RubyGems after the first public release.
- Demo GIF/screenshots are not yet included in the repository.

## Roadmap


Highlights:

- Complete OSS documentation set (`README`, `CONTRIBUTING`, `SECURITY`)
- Required CI pipeline for backend and frontend
- Better developer setup and compatibility matrix
- Product differentiators (risk score, waivers, CI report output)

## Contributing

Issues and pull requests are welcome.

For now:

1. Open an issue describing the bug/feature.
2. Fork the repository and create a branch.
3. Run local checks before opening your PR.

Formal contribution guidelines will be published in `CONTRIBUTING.md`.

## Code of conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md).

## License

Migflow is licensed under the [MIT License](./LICENSE.txt).
