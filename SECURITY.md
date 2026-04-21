# Security Policy

## Supported versions

Only the latest released version of Migflow receives security fixes.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Send a report to **joaovictorvalentim@gmail.com** with:

- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept
- Any suggested fix, if you have one

You can expect an acknowledgement within **72 hours** and a resolution timeline within **14 days** of the initial report, depending on severity.

## Scope

Migflow is a Rails engine mounted inside a host application. Reports are in scope if they affect:

- The engine's REST API endpoints (`/migflow/api/*`)
- The Rake task (`migflow:report`) and its output
- Any data exposure through migration content or schema information

Issues in the host Rails application, its database, or third-party dependencies are generally out of scope unless Migflow directly introduces the vulnerability.
