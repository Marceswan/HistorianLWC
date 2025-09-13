# Contributing to HistorianLWC

Thanks for your interest in contributing! This document summarizes how to set up your environment, coding standards, commit/PR guidelines, and expectations for tests and docs.

## Development Setup
- Install Salesforce CLI (`sf`) and authenticate to an org.
- Optional for LWC development: Node 18+ and npm for linting/Jest.
- Create a scratch org for iterative work:
  ```bash
  sf org create scratch -f config/project-scratch-def.json -a historian
  sf project deploy start -o historian
  sf org assign permset -o historian -n Historian_Admin
  ```
- Run tests:
  ```bash
  sf apex run test -o historian
  ```

More details: `docs/development.md`.

## Code Style
- Apex: keep classes cohesive; prefer services over fat controllers; guard CRUD/FLS.
- LWC: 2‑space indent, ESLint + Prettier where configured; avoid large components.
- Naming: classes PascalCase, variables camelCase; files kebab‑case for JS/HTML.
- Max line length: ~100 characters.

## Tests
- Apex coverage ≥85% across changed classes.
- Include negative paths (mdapi errors, permission denials) and edge cases.
- For LWC, prefer Jest for component logic where applicable.

## Commits & PRs
- Use Conventional Commits (e.g., `feat: add timeline filter`, `fix: correct date parsing`).
- Keep commits focused; prefer small, logical patches.
- Update `README.md` and `CHANGELOG.md` for user‑facing changes.
- PRs should include:
  - Summary of changes and motivation
  - Linked issue (e.g., `Closes #123`)
  - Screenshots/logs for UI or CLI changes
  - Checklist of impacts (tests, docs, breaking changes)
- CI (when enabled) must pass, including lint and tests.

## Security
- Do not include secrets in the repo.
- Validate CRUD/FLS before DML and SOQL.
- See `SECURITY.md` for reporting instructions.

## Documentation
- Keep feature docs up to date under `docs/`.
- Treat `README.md` as the source of truth for install/usage.

