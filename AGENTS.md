# Repository Guidelines

This repository is currently a minimal scaffold. The conventions below define how we organize code, run tasks, and collaborate as the project grows. Adjust paths and commands as the stack is finalized.

## Project Structure & Module Organization

- `src/`: application source (group by domain or feature).
- `tests/`: mirrors `src/` structure for unit/integration tests.
- `assets/` or `public/`: static files (images, styles, mock data).
- `scripts/`: automation (setup, build, test, release).
- `docs/`: architecture notes and ADRs.
- `.github/`: workflows and PR templates.
- Example pattern: `src/<feature>/index.*`, `tests/<feature>/*`.

## Build, Test, and Development Commands

- Setup: `./scripts/setup.sh` — install toolchains/deps (create venv, run `npm ci`, etc.).
- Develop: `./scripts/dev.sh` — start local dev server or watcher.
- Build: `./scripts/build.sh` — produce distributable artifacts to `dist/`.
- Test: `./scripts/test.sh` — run unit tests with coverage.
- Lint/Format: `./scripts/lint.sh`, `./scripts/format.sh` — enforce style.

Examples (if using Node.js): `npm ci`, `npm run dev`, `npm test -- --coverage`, `npm run build`.

## Coding Style & Naming Conventions

- Indentation: 2 spaces for JS/TS; 4 spaces for Python. Max line length 100.
- Naming: files kebab-case (`user-profile.ts`), classes PascalCase, variables camelCase, constants UPPER_SNAKE_CASE.
- Tools (recommend): Prettier + ESLint (JS/TS) or Black + Ruff (Python). Run formatters before commit.

## Testing Guidelines

- Place tests in `tests/`, co-located by feature. Name as `*.spec.ts` or `test_*.py` depending on stack.
- Aim for coverage on core logic and edge cases; avoid brittle UI-only tests.
- Run locally via `./scripts/test.sh` before pushing; include fixtures in `tests/fixtures/`.

## Commit & Pull Request Guidelines

- Commits: use Conventional Commits (e.g., `feat: add timeline filter`, `fix: correct date parsing`). Keep changes focused.
- PRs: clear description, linked issue (e.g., `Closes #123`), screenshots or logs when UI/CLI changes, and checklist of impacts (tests, docs, breaking changes).
- Require passing CI, lint, and tests. Request review from code owners for touched areas.

## Security & Configuration

- Do not commit secrets. Use `.env.local` (gitignored) and document required variables in `.env.example`.
- Pin dependencies and update regularly. Review third-party licenses.
- Prefer local config over global machine state; scripts should be reproducible.

## Project Plan Reference

- Full plan: `PROJECT_PLAN.md` — objectives, architecture, CMDT model, mdapi integration, milestones, and testing strategy for HistorianLWC.
- mdapi usage: `docs/mdapi_instructions.md` — step-by-step setup and patterns for MetadataService.
- mdapi assets: `docs/mdapi_assets.md` — overview of vendored Visualforce pages, components, and static resources.

## Maintenance Instructions

- README upkeep: When adding features, commands, or files, update `README.md` in the same change. Treat README as source of truth for install, setup (Remote Site Setting), and usage.
- Changelog: Maintain `CHANGELOG.md` following Keep a Changelog style. For every user-facing change, add entries under Unreleased with Added/Changed/Fixed.
