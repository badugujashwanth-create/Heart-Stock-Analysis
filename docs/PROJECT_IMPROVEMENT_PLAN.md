# Project Improvement Plan

## Current state

Heart Analysis has a meaningful analysis workflow, 28 tests, a reproducible web build, and a verified demo. It is not a medical device and must not imply diagnosis.

## Findings

- **Works:** validated analysis paths, test suite, web UI/build, evidence documentation, and demo.
- **Does not / missing:** clinical validation, broad dataset generalization, and a single unambiguous Flutter package structure.
- **UX / architecture:** duplicate/overlapping mobile layout increases maintenance cost. Results need consistently prominent non-diagnostic language and recovery states.
- **Testing / security:** core tests pass; accessibility/device tests and a deployment data-retention threat model are missing.
- **Performance / docs / demo:** no serious measured web blocker; model/data performance across devices is not benchmarked.

## Recommendations

### Critical

- Preserve non-diagnostic wording and avoid storing sensitive inputs by default.
- Keep 28 core tests and the production web build green.

### High value

- Consolidate or explicitly designate the canonical Flutter package.
- Add browser accessibility and invalid-input workflow coverage.

### Optional

- Measure inference/render latency on a documented reference device.

## Delivery constraints

- **Priority:** safety language and canonical structure; **complexity:** medium; **dependencies:** existing web/mobile toolchains.
- **Acceptance:** reproducible start/build, tests pass, invalid inputs recover cleanly, and data/medical limits are visible.
- **Excluded:** clinical claims, real patient deployment, and unverified model-accuracy claims.
