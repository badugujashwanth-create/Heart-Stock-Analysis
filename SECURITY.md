# Security policy

HeartAnalysis is a portfolio prototype, not a medical device or production health-data service.

## Data and deployment rules

- Use synthetic inputs only.
- Prediction persistence is off by default and must remain off on unauthenticated public infrastructure.
- Do not publicly deploy retained history without authentication, authorization, tenant isolation, encryption, retention controls, and a privacy review.
- Keep rules mode as the credential-free default. Do not enable external AI providers without explicit authorization and secret management.
- Production requires a strong secret and an explicit CORS origin.
- The historical password formerly present in `backend/.env.example` must be rotated if it was ever used.
- Two historical Google API keys in the initial commit's Android configuration must be restricted or rotated in the provider console.
- Current-tree removal does not erase Git history; the full history is intentionally reported as not clean until those provider actions are confirmed.

Report vulnerabilities through GitHub private vulnerability reporting when available. Never place credentials, personal data, private URLs, or patient information in a public issue.

No security response-time commitment is implied.
