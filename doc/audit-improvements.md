# Audit improvement implementation

Scope: implement the September 2026 testability and maintainability audit, preserving current gameplay unless correcting identified lifecycle defects.

- [x] Isolated runner storage, unique logs, strict structured result gate, pinned engine.
- [x] Assertion-free shop test, leaked economy test nodes, GUT startup compatibility.
- [x] State transition guards and shop/loot mode matrix; restart clears transient state.
- [x] One authoritative wave reward calculation and payout regression tests.
- [ ] Shared isolated fixtures; deterministic gameplay RNG and fixed purchase offers.
- [ ] Pure modifier calculation inputs and owned mutations; typed boundary records.
- [ ] Separate combat decisions, spawning, visual effects, and elapsed cooldown time.
- [ ] Separate asset persistence, resolution/merging, and validation; isolated storage tests.
- [ ] Extract HUD damage-number presentation and screen coordination.
- [ ] CI, updated canonical docs/templates, complete validation and commit review.

## Toolchain

Godot is pinned in `.godot-version`; GUT is vendored at 9.5.1. The single local GUT compatibility patch reads the optional `exclude_addons` setting with a default, since it is absent in this engine. Preserve or replace this patch when updating GUT.

The PowerShell runner requires PowerShell 7 and sets APPDATA/XDG_DATA_HOME only in the child process. Each run retains stdout, stderr, JSON results, and isolated Godot user data under `.test-results/<id>/`. It is validated on Windows; CI targets Windows. Expected validation warnings remain visible and do not fail the gate.

Validation: full GUT run after lifecycle fixes and shared fixtures: 1,080 passing tests, no risky tests, errors, or remaining orphans. The shop/loot matrix covers all four combinations and duplicate notifications.
