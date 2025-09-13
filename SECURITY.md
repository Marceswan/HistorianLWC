# Security Policy

We take the security of HistorianLWC seriously.

## Reporting a Vulnerability
- Please do not file public GitHub issues for security reports.
- Instead, email the maintainers privately at security@example.com with details and reproduction steps.
- We will acknowledge receipt within 2 business days and provide status updates at least weekly until resolution.

## Scope & Assumptions
- No secrets should be committed to this repository.
- The package enforces CRUD/FLS checks in service layers; contributions must preserve these checks.
- Metadata API operations run in privileged contexts; ensure defensive validation and clear error handling.

## Responsible Disclosure
If you discover a vulnerability, please give us a reasonable time to investigate and remediate before public disclosure. We appreciate coordinated disclosure to protect our users.

