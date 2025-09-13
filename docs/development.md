# Development Guide

This guide outlines environment setup, common commands, testing, and style guidelines for contributors.

## Prerequisites
- Salesforce CLI (`sf`) installed and authenticated
- Git, a code editor (VS Code recommended)
- Optional (LWC dev): Node 18+ and npm

## Quickstart (Scratch Org)
```bash
sf org create scratch -f config/project-scratch-def.json -a historian
sf project deploy start -o historian
sf org assign permset -o historian -n Historian_Admin
sf apex run test -o historian
```

Open the org and the Librarian app to configure tracking.
```bash
sf org open -o historian
```

## Deploy to Sandbox or Dev Org
```bash
sf org login web -a myOrg
sf project deploy start -o myOrg
sf org assign permset -o myOrg -n Historian_Admin
```

## Common Commands
- Run all Apex tests: `sf apex run test -o <alias>`
- List lwc tests (if configured): `npm test` (Jest)
- Open mdapi helper VF page: navigate to `remotesitepage` in the org (optional troubleshooting)

## Code Style
- Apex: keep services small and cohesive; validate CRUD/FLS; avoid SOQL/DML in loops; prefer descriptive method names.
- LWC: 2‑space indentation; pass data via @api properties; small focused components; ESLint + Prettier where configured.
- Max line length: ~100 characters.

## Testing
- Apex coverage ≥85% for changed classes.
- Cover error paths for mdapi interactions and permission checks.
- For LWC, prefer Jest tests for core logic where present.

## Documentation & Changelog
- Update `README.md` for any user‑facing changes.
- Maintain `CHANGELOG.md` using Keep a Changelog format under the Unreleased section.

## Packaging Notes
- Ensure permissions (e.g., `Historian_Admin` permset) are included and minimal.
- Consider excluding admin VF tooling from managed packages or gating via Custom Permission.

