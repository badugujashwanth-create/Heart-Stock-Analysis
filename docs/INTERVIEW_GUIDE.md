# HeartAnalysis interview guide

## Tell me about this project.

HeartAnalysis is an educational Flutter and Flask application for exploring heart-risk inputs, explanations, history, and reports. It is not medical software or a diagnostic tool.

## Why did you build it?

The project explores how an applied model can be presented with context and disclaimers instead of displaying an unexplained score.

## What was your contribution?

Discuss the Flask API, Flutter client flows, SQLAlchemy persistence, tests, report/explanation UX, and portfolio claim corrections. Do not present the output as clinical advice.

## What was the hardest technical problem?

Keeping backend/model behavior and two Flutter package trees reproducible while avoiding misleading health claims.

## How does the architecture work?

Flutter clients call the Flask API; SQLAlchemy manages history/storage; provider modes are environment-controlled; reports and explanations are presented by the client.

## What would you improve?

Consolidate the Flutter package layout, add model-card/data provenance, accessibility review, calibration/evaluation evidence, and clinician-led validation before any medical use.

## How did you test it?

Eighteen backend tests, nine root Flutter tests, and one canonical frontend test pass. The canonical Flutter web build and package-scoped analyzers pass.

## What are its security limitations?

Health inputs can be sensitive. A real deployment would need consent, encryption, retention/deletion policy, access control, audit logging, and regulatory review.

## How would you scale it?

Use managed API/database services, separate model serving if needed, cache only non-sensitive assets, and add privacy-aware observability. Evaluation quality matters more than request volume.

## What did you learn?

Applied analytics must communicate uncertainty, provenance, and intended use; technically correct code can still be harmful if its product claims are careless.
