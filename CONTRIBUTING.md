# Contributing

Keep changes educational, synthetic, and evidence-backed.

1. Work in the canonical `backend/` and `frontend/` packages.
2. Do not add clinical, accuracy, outcome, or production-user claims without appropriate evidence and review.
3. Preserve `PERSIST_PREDICTIONS=false` as the default.
4. Add or update the smallest relevant test before running the full suite.
5. Run the commands in [docs/TEST_REPORT.md](docs/TEST_REPORT.md).
6. Update architecture, limitations, and demo evidence when behavior changes.

Never commit secrets, real health information, `.env` files, databases, generated dependencies, or unreviewed recordings. Follow [SECURITY.md](SECURITY.md) for sensitive reports.
