# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Infinite "Loading schemas…" spinner in Flow and Schema views caused by `loadingBasePrevious` blocking rendering even when the previous-migration query was disabled or optional ([#schema-loading])

## [0.2.0] - 2026-04-22

### Added
- **Risk score** — every migration receives a numeric score (0–100) and a level (safe / low / medium / high) derived from six audit rules, displayed in the detail panel and exposed in the API
- **CI report** — `bundle exec rails migflow:report` generates a Markdown or JSON audit report without starting a server; supports `FORMAT`, `FAIL_ON`, `FAIL_ON_SCORE`, and `OUTPUT` options
- **GitHub Actions workflow** — `.github/workflows/ci-report.yml` triggers on pull requests touching `db/migrate/` and posts a Markdown summary to the step summary
- `JsonReporter` and `MarkdownReporter` classes for structured report output
- `ReportGenerator` service orchestrating parser → snapshot → diff → risk scoring pipeline

### Changed
- Minimum Ruby version raised to 3.2 (`Data.define` is not available in 3.1)
- CI matrix extended to Ruby 3.2 and 3.3 across Rails 7.0, 7.1, and 7.2
- RuboCop `TargetRubyVersion` aligned to 3.2

## [0.1.0] - 2026-02-28

### Added
- Rails engine mounting at a configurable path (default `/migflow`)
- Migration timeline — ordered list of all migrations with version, name, and one-line summary
- Detail view — raw migration source, schema snapshot (`schema_after`), and audit warnings
- Schema diff — focused and full unified diff of `schema.rb` between any two versions
- Compare mode — pick any two migration versions to see a side-by-side schema delta
- Schema graph (ERD) — interactive canvas with tables, columns, foreign-key edges, and diff highlights (added/removed coloring)
- Audit rules: `MissingIndexRule`, `MissingForeignKeyRule`, `StringWithoutLimitRule`, `MissingTimestampsRule`, `DangerousMigrationRule`, `NullColumnWithoutDefaultRule`
- REST API (`GET /api/migrations`, `GET /api/migrations/:version`, `GET /api/diff`)
- Authentication hooks — `parent_controller`, `authentication_hook`, `unauthenticated_redirect`
- `bin/setup` for one-command development setup
- CI pipeline with RSpec, RuboCop, Vitest, ESLint, and frontend build
- SimpleCov coverage enforcement (80% minimum)

[Unreleased]: https://github.com/jv4lentim/migflow/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/jv4lentim/migflow/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jv4lentim/migflow/releases/tag/v0.1.0
