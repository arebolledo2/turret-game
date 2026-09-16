# 3D cutover — 2026-09-16

The successful six-wave playtest approved the third slice. `3d-slice-03` records that pre-cutover version at `3207fbf`; `prototype-2d-final` preserves the retired 2D game. The default `scenes/main.tscn` now opens the native 3D app shell.

## Changes

- Added Play/Settings/Quit, persistent fullscreen/VSync/reduced motion, and return-to-menu from pause/end states.
- Promoted `scripts/three_d/` to `scripts/game/`, the proving-ground scene to `scenes/game/arena.tscn`, models to `assets/models/game/`, and asset/capture/smoke tools to permanent names.
- Retired 242 tracked files belonging to the 2D runtime and its fixtures/tests (the old main scene path was reused for the new app). Removed 2D actors, components, scenes, shop/HUD/Asset Studio, world coordinators and runtime-only services.
- Preserved shared state, economy, registries, modifiers, data/storage tests, reference art and editable Blender sources. Unsupported catalog entries remain hidden from normal play through explicit allowlists.
- Updated canonical documentation and added resource auditing and full-run smoke checks to CI.

## Validation

The post-cutover full import/GUT gate passes **784 tests / 3,139 assertions**, with no risky tests, unexpected errors or remaining orphans. The previous total of 1,142 included 365 tests for retired 2D runtime behavior; seven new cutover/settings tests were added. Shared logic tests remain.

New coverage dispatches keyboard/controller input, checks settings persistence/type validation and reduced motion, tests repeated menu/Play cycles and service teardown, and exercises pause, death, victory and restart. Controller checks use injected input events, not a physical-device playtest.

The literal-resource/model audit passes. Native Vulkan/Forward+ captures of start, settings, pause, defeat, victory and returned menu were inspected at 1280×720 with clean stdout/stderr. Seeded real-physics ion and plasma/shock progression runs both complete all six waves with real earned budgets. These automated runs supplement the user's successful gameplay playtest.

Next work should target native audio, combat feedback and a measured performance budget before expanding the catalog or the asset-generation web app. See [gameplay](gameplay.md) for current limitations and prior performance samples.
