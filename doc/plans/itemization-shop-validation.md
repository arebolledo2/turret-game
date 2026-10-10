# Itemization and Shop validation

2026-10-10, Godot 4.7.1.

- Full GUT suite: **884 passed**, 64 scripts; no risky tests, unexpected errors or remaining orphans.
- New coverage includes overlapping-family modifiers applying once, additive stacking, physical/projectile versus Kinetic classification, supported capabilities, firing/sweep cadence, actual Shock hit boundaries and range display, family diversity/mastery, source-aware AoE procs and chain depth, purchase/preview equivalence, state/RNG preservation, runtime clamps and safe purchase penalties.
- Shop input tests dispatch controller events through Godot. They cover direct footer navigation, disabled/hidden repairs, purchase focus handoff, inspecting installed items (including after all stock is sold), pause/dev transitions and 3D rendering restoration.
- Engine import completed without script/resource errors. All 43 catalog item illustrations load; five model portraits were rendered with Forward+.
- Native visual captures inspected at 1920×1080, 1280×720, 1280×800 and 2560×1080. Also inspected long rare-item descriptions and a populated installed-item list at 1280×720. Arena/HUD are hidden; prices and footer remain visible.
- Seeded real-physics six-wave smoke runs: Ion route **victory, 346 kills, 25 hull**; mixed Plasma/Shock route **victory, 356 kills, 25 hull**. Both used gameplay seed 20260916 and shop seed 42. These spend different budgets and are regression smoke checks, not an equal-spend balance ranking.

## Reproduce

Run `pwsh -NoProfile -File run_tests.ps1 -KeepRuns 1000` from the game repository. For screenshots, launch `res://tools/preview_shop.tscn` with a rendering driver and `--resolution WIDTHxHEIGHT`; add `-- --rare` for longer descriptions and installed upgrades. Captures go to `.test-results/shop-WIDTHxHEIGHT[-rare].png`.

Run `res://tools/smoke_progression.tscn` headlessly with `-- --waves=6`, then with `-- --waves=6 --control`, to exercise the two purchase routes. Raw logs for this implementation are under the monorepo's ignored `3d-eval/reports/clockwork-carnival/shop-*.log`.

## Remaining playtest work

Human feel, physical-controller usability, equal-spend build comparisons and full-length balance tuning remain. Automated progression and core/convoy regression tests pass, but the smoke runs do not establish late-wave balance across every mode. No wave difficulty or economy scaling was changed to compensate for the new item pool.
