# Test report

Audited on 2026-07-17 using the checked-out `portfolio-polish` branch on Windows.

| Command | Result | Evidence / notes |
|---|---|---|
| `backend: python -m ruff check .` | Pass | All checks passed after 7 safe autofixes |
| `backend: python -m pytest -q` | Pass | 18 tests passed |
| `root: flutter test` | Pass | 9 tests passed |
| `frontend: flutter analyze / flutter test` | Pass | No issues; 1 test passed |
| `root: flutter analyze` | Fail | Root analysis traverses the nested `frontend` package and reports 32 cross-package errors; run checks per package |
| `frontend: flutter build web --release` | Pass | Release web bundle generated for the canonical documented client |

## Overall status

Verified per package. Running `flutter analyze` from the outer package still traverses the nested package and produces misleading cross-package errors, so CI and development checks target `frontend` directly.

Warnings and missing checks remain limitations, even when another check passes.
