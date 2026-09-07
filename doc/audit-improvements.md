# Audit improvement implementation

Scope: implement the September 2026 testability and maintainability audit, preserving current gameplay unless correcting identified lifecycle defects.

- [x] Isolated runner storage, unique logs, strict structured result gate, pinned engine.
- [x] Assertion-free shop test, leaked economy test nodes, GUT startup compatibility.
- [x] State transition guards and shop/loot mode matrix; restart clears transient state.
- [x] One authoritative wave reward calculation and payout regression tests.
- [x] Shared isolated fixtures; deterministic gameplay RNG and fixed purchase offers.
- [x] Pure modifier calculation inputs and owned mutations; typed boundary records.
- [x] Separate combat decisions, spawning, visual effects, and elapsed cooldown time.
- [x] Separate asset persistence, resolution/merging, and validation; isolated storage tests.
- [x] Extract HUD damage-number presentation and screen coordination.
- [x] CI, updated canonical docs/test examples, complete validation and commit review.

## Toolchain

Godot is pinned in `.godot-version`; GUT is vendored at 9.5.1. The single local GUT compatibility patch reads the optional `exclude_addons` setting with a default, since it is absent in this engine. Preserve or replace this patch when updating GUT.

The PowerShell runner requires PowerShell 7 and sets APPDATA/XDG_DATA_HOME only in the child process. Each run retains stdout, stderr, JSON results, and isolated Godot user data under `.test-results/<id>/`. It is validated on Windows; CI targets Windows. Expected validation warnings remain visible and do not fail the gate.

Validation: full GUT run after lifecycle fixes and shared fixtures: 1,080 passing tests, no risky tests, errors, or remaining orphans. The shop/loot matrix covers all four combinations and duplicate notifications.

Run ownership now uses a RunSession node and shared RunSessionState bound at the composition root; standalone services keep private state. The full suite after this extraction passed 1,100 tests. Final verification includes CI-equivalent import/testing and review of pre-existing working-tree edits.

Final verification: checksum-verified Godot 4.7.1, clean import plus full suite: **1,101 passing tests, 3,584 assertions across 57 scripts**. No risky tests, unexpected engine errors or remaining orphans. Gate self-tests accept clean results and reject all nine invalid cases, including duplicate unasserted errors. CI workflow is configured but has not yet run on GitHub.

Existing UI edits are preserved. The HUD refactor overlaps those edits and remains uncommitted; other audit changes are committed separately. Interactive visual review remains advisable for damage-number and overlay presentation.
