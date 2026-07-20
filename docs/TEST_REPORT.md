# Test report

Audited on 20 July 2026 from `product-completion-2026` on Windows.

| Check | Result |
| --- | --- |
| Backend Ruff | Pass |
| Backend pytest | 19 tests pass |
| Canonical Flutter analyze | Pass, no issues |
| Canonical Flutter widget tests | 2 pass |
| Flutter release web build | Pass |
| Playwright synthetic workflow | 2 pass: full five-tab flow and 390px overflow |
| Python dependency audit | No known vulnerabilities after Flask-CORS upgrade |
| Node dependency audit | 0 vulnerabilities |

The browser workflow uses Playwright’s bundled Chromium, loads the built-in synthetic profile, generates the scorecard, changes the exercise slider, runs the what-if comparison, opens history, and checks the assistant boundary. It performs no provider requests.

Local release verification includes a clean current-tree secret scan, final Markdown-link scan, and video probe/checksum. GitHub Actions must be green on the release commit before publication.

The staged release diff is Gitleaks-clean. Full-history scanning intentionally remains non-clean because the initial commit contains two redacted Google API keys; console restriction/rotation is a human checkpoint and history was not rewritten.

The accepted walkthrough is 257.488 seconds at 1280×720 with VP9 video, Opus narration, captions, thumbnail, and ten inspected frames. SHA-256: `27f2efc1dfb0abc5da6955cb0fbf1ecfc996720db740df5201beae83398d6dfe`.
