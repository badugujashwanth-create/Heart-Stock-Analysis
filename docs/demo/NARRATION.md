# HeartAnalysis narration

HeartAnalysis is an educational engineering prototype built with Flutter and Flask. The most important statement appears before any input: this is an unvalidated, hand-coded heuristic, not a medical risk estimate, diagnosis, prognosis, or treatment recommendation. Every value in this walkthrough is synthetic.

The product starts with a deterministic example so a reviewer can reach the complete workflow without inventing data or using a provider credential. The long form is grouped into profile context, health indicators, and lifestyle context while preserving the existing Material design system. Reset returns the form to its neutral state.

Submitting the synthetic example calls the validated Flask endpoint. Pydantic enforces field bounds and allowed categories. The response retains the earlier risk-probability field name for compatibility, but machine-readable score metadata states that it is not a medical probability and is not calibrated.

The scorecard displays a zero-to-one-hundred educational profile score, a band, and the configured factors that contributed most strongly. Those contributions explain the code’s behavior; they do not prove causal importance or clinical validity. The model card says the heuristic was not trained or validated on a patient cohort.

The general guidance and structured plan use the deterministic rules provider in this release. Rules mode makes the demo repeatable and network-free. Optional llama.cpp and OpenAI-compatible adapters exist behind the same service boundary, but neither external profile is claimed as release-verified.

The what-if screen reuses the latest synthetic input. Changing exercise minutes and running the comparison produces a deterministic score movement and lists exactly which field changed. The result remains an interaction with configured weights, not evidence that an individual’s medical outcome will change by that amount.

History demonstrates the SQLAlchemy repository and trend UI. Persistence is disabled by default because this API does not include user authentication or tenant isolation. The local demo launcher explicitly enables persistence only for this isolated synthetic session. A public retained-history deployment is therefore a security gate, not a released capability.

The assistant receives the current synthetic profile and rules plan. It returns bounded educational language with a mandatory disclaimer. It must redirect diagnostic or treatment questions to a qualified clinician and cannot replace emergency care.

The release candidate is backed by nineteen API tests, two canonical Flutter widget tests, static analysis, a production web build, dependency audits, and two Chromium tests. The browser suite runs the same scorecard, what-if, history, and assistant path and checks that the mobile shell has no horizontal overflow at three hundred ninety pixels.

The audit also removed a real-looking password from the example environment file, upgraded the vulnerable Flask-CORS boundary, disabled automatic deployments, and made the local data-retention choice explicit. If the historical credential was ever real, the owner must rotate it and review access logs; removing it from the latest tree does not erase Git history.

What is intentionally not claimed matters as much as what works. There is no clinical accuracy, dataset provenance, calibration, fairness evaluation, patient use, public deployment, production security, or external-model performance claim. The older root-level prototype is also retained as documented technical debt outside the canonical frontend and backend packages.

HeartAnalysis now tells one defensible portfolio story: a broad full-stack MVP was transformed into an honest, deterministic, tested educational systems demonstration. The value is the engineering judgment visible in its validation, explainability, fallback, persistence, security, responsive UI, and release evidence.
