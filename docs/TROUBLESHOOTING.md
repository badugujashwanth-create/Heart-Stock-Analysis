# Troubleshooting

## Installation fails

Use the package manager and lockfile already committed to this repository. Confirm the required runtime is installed, clear only generated caches, and retry the install command from [DEVELOPMENT.md](DEVELOPMENT.md).

## The application starts but a feature is unavailable

Check the browser or terminal error first, then verify the documented environment variables and dependent services. This is an educational prototype, not medical advice. The repository contains two Flutter package trees that must be checked independently.

## Tests and builds

Run checks from the component directory shown in [TEST_REPORT.md](TEST_REPORT.md). A successful dependency install is not evidence that a test or production build passed.

## Sensitive configuration

Never paste real credentials into an issue or screenshot. Replace local configuration values with placeholders before sharing diagnostic output.

