# Security policy

## Supported status

HeartAnalysis is maintained as a portfolio project and This is an educational prototype, not medical advice. The repository contains two Flutter package trees that must be checked independently.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting feature when it is enabled. Otherwise, contact the repository owner through an existing verified GitHub contact channel. Do not include secrets, access tokens, private URLs, or personal data in a public issue.

## Configuration rules

- Keep real credentials in local environment files or an external secret manager.
- Commit only placeholder values in `.env.example` files.
- Rotate any credential that was previously committed; deleting it from the current branch does not remove Git history.
- Use synthetic or public sample data for tests, screenshots, and recordings.

No response-time or production support commitment is implied.

