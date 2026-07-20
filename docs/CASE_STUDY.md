# Case study

## Problem

The project already had a broad Flutter/Flask workflow, but its presentation overstated an arbitrary heuristic as a stroke-risk probability and made a public deployment look closer to ready than its unauthenticated persistence allowed.

## Intervention

The v1.0 cycle preserved the existing Material visual system while changing the product contract. The API now identifies the result as uncalibrated and non-medical, the UI and PDF call it an educational score, and the default storage behavior is no retention. A built-in synthetic profile makes the intended path immediate and reproducible.

The audit also upgraded vulnerable Flask dependencies, removed a real-looking example password, converted deployment to an explicit human gate, and added a real Chromium test across scorecard, what-if, history, and assistant states.

Frame inspection of the first full recording exposed a sign error: increasing exercise raised the heuristic score. The normalization was corrected, a regression assertion now requires the synthetic improvement bundle to lower the score, the demo history was reset, and the entire walkthrough was recorded again.

## Result

Recruiters can now see the engineering value—validation, explainability, fallback behavior, persistence boundaries, responsive Flutter UI, API tests, and browser automation—without an unsupported clinical claim. The product remains intentionally local and synthetic.
