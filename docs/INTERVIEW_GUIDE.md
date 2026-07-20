# Interview guide

## What is HeartAnalysis?

It is an educational Flutter/Flask systems demo for explainable scoring, validation, what-if interaction, and safe product boundaries. It is not medical software.

## What was the important engineering decision?

The original hand-coded heuristic was presented like a calibrated stroke-risk probability. I kept the compatibility field but changed the contract, UI, PDF, model card, and documentation to identify it as an unvalidated educational score. I also made persistence opt-in because the API has no user authentication.

## What does the architecture demonstrate?

Flutter state and responsive UI, Flask/Pydantic API contracts, SQLAlchemy persistence, deterministic rules fallback, optional provider adapters, request controls, PDF generation, and browser automation.

## How is it tested?

The release candidate has 19 API tests, 2 canonical Flutter widget tests, lint/analyze checks, a production web build, Python/Node dependency audits, and 2 Chromium tests covering the full synthetic workflow and mobile overflow.

## What remains?

Historical-package consolidation, credential rotation confirmation, authentication and tenant isolation for retained public history, provider-profile verification, physical-device accessibility, and every form of clinical validation.

## Safe résumé language

“Built and release-hardened a Flutter/Flask educational scoring system with deterministic what-if workflows, default-off persistence, dependency audits, and Chromium end-to-end verification.”
