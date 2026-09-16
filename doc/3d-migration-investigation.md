# 3D migration and AI asset investigation

Investigated 2026-09-16. This is a proposal, not an implemented migration. Source inspection and local hardware checks were performed; no 3D generation service, Blender model-building workflow, or game benchmark was run.

Implementation follow-up: two playable slices now include ion/plasma turrets, chasing/charging drones, a player bot, five scripted Blender assets, native 3D combat contracts, and crowd separation. See [3D proving ground](3d-slice.md) for implemented scope and verification; the broader migration below remains a proposal.

## Recommendation

Keep Godot/GDScript. Replace the existing game's world with native 3D scenes and physics, initially constrained to an XZ ground plane with a fixed elevated orthographic camera. Preserve the survival loop, turret placement, progression, and UI. Retire the 2D implementation after the 3D slice passes; do not build a permanent compatibility layer.

Keep image-gen-web as the concept art, style exploration, icon, and reference-image application. Start 3D production with AI-authored Blender Python for mechanical assets and a small image-to-3D comparison. Standardize approved assets through Blender and export GLB into Godot.

Assumptions: desktop first, fixed camera, flat arena, stylized mechanical art, current game rules. Vertical combat, free camera, terrain traversal, mobile/web targets, or realistic characters require revisiting the scope.

## Repository evidence

The workspace contains separate game and web Git repositories. Both were clean when inspected. Root guidance says Godot 4.6, but `project.godot` declares 4.7 and Forward Plus; game-local docs also say 4.7. Treat the project config as authoritative rather than combining this migration with an engine change.

| Area | Evidence | Migration implication |
|---|---|---|
| Run/progression | `scripts/systems/run_session.gd`, `run_session_state.gd`, autoload services | Preserve lifecycle, economy, modifier calculations, inventory, and tech progression; update scene references and bindings where required. |
| Actors | `scripts/components/player_movement.gd`, `enemy_movement.gd`, actor scenes | Movement and scene types are explicitly 2D. Rebuild world actors and adapt behavior components. |
| Targeting/events | `scripts/systems/target_selection.gd`, `scripts/autoload/events.gd` | Even the separated targeting helper accepts Vector2/Node2D. Combat and world event payloads require deliberate conversion. |
| Projectiles | `scripts/projectile.gd` | Area2D, swept CapsuleShape2D collision, Line2D trails, sprite glow, and pool reset contracts must be ported. Preserve anti-tunneling behavior. |
| Arena/camera | `arena_bounds_service.gd`, `enemy_spawner.gd`, `camera_setup.gd` | Rect2 spawn zones and planar geometry can be retained as XZ calculations. Camera projection and visibility logic must change. |
| Assets | `asset_visual_config.gd`, `components/collision_profile.gd`, enemy registry | Sprite modes, texture directions, pixel scaling, and Shape2D factories must become model/animation/collision definitions. |
| Web generation | `image-gen-web/lib/providers/types.ts`, `lib/db/schema.ts` | Image providers return image arrays; image metadata and transformations are image-specific. Add a separate 3D domain instead of putting GLBs in image records. |
| Web jobs/storage | `image-gen-web/lib/queue/functions.ts`, `lib/storage/local-storage.ts` | Reuse orchestration patterns, but add durable external task IDs, model artifacts, and a local Blender worker. Existing local file paths cannot be sent directly to cloud providers. |

A lexical scan found explicit 2D engine types in 57 of 140 game scripts. This is evidence of breadth, not a percentage estimate of reusable code or engineering effort.

## World design

- Use CharacterBody3D for moving actors, Area3D for hurtboxes and pickups, Node3D for scene roots, and Camera3D for the view. Keep Control/CanvasLayer UI.
- Gameplay positions live in XZ. Y is height. Visual bobbing, recoil, and death motion occur under a visual child so they do not move authoritative hitboxes.
- Calculate range, splash, placement spacing, and knockback on the ground plane. Cosmetic height must not change target eligibility.
- Keep one native 3D physics world. A 2D simulation driving 3D visuals is feasible, but introduces mapping and synchronization obligations; it is unnecessary for this replacement unless a performance prototype demonstrates a strong benefit.
- Keep open-arena chase/separation logic initially. Add navigation only when blocking obstacles demand it.
- Camera-relative movement and cursor-to-ground ray intersection replace screen-coordinate assumptions. Project world labels and offscreen indicators through Camera3D.
- Replace the current screen-space diamond arena option with an explicit design decision: preserve a real diamond footprint, or retire it as a background-art workaround. Orthographic projection does not require a diamond collision boundary.

Choose a unit conversion once. An initial proposal is 100 existing pixels = 1 metre: the 1920 x 1080 arena becomes 19.2 x 10.8 m, player speed 250 becomes 2.5 m/s, and normal turret range 240 becomes 2.4 m. Convert acceleration, radii, projectile speed, spawn margins, pickup distances, and velocity-based knockback consistently. Health, damage, percentages, and timers do not scale. Tune the camera independently after preserving these ratios.

## Migration stages and exit conditions

1. **Preserve the baseline and establish contracts.** Tag the current game, record representative runs and existing test results, then migrate on a branch in the same game repository. Choose camera, units, target hardware, peak entity load, and frame-time budget. Inventory persistent settings so old sprite presets can be reset or versioned without corrupting unrelated preferences.
2. **Build one playable 3D loop with primitives.** One arena, player, chasing enemy, basic turret, projectile, scrap pickup, wave transition, shop purchase, and restart. Keep existing progression services. Gate: damage, movement, placement, pause, wave/shop transitions, and teardown work without 2D world dependencies in this slice.
3. **Prove one asset family and crowded combat.** Import one finished turret and one animated enemy. Verify muzzle position, rotation, collision footprint, camera readability, and export/reimport. Profile the expected peak enemies/projectiles/turrets plus headroom before producing all content.
4. **Port remaining gameplay and presentation.** All turret attack styles, enemy behaviors, status effects, ranks, game-mode objectives, indicators, VFX, and audio positioning. Migrate world integration tests; retain calculation tests. Gate: agreed feature parity across supported modes and complete runs.
5. **Cut over and retire 2D.** Make the 3D scene the entry point. Remove unused 2D world scenes, sprite-only configuration/editor controls, obsolete tests and flags, and abandoned asset imports. Keep useful UI images, concept references, audio, and Git history. Update docs and validate a packaged build on target hardware.

Do not estimate the full migration from the type scan. Use the first complete loop and one production asset to measure actual porting and cleanup effort.

## AI-assisted Blender versus image-to-3D

### AI-authored Blender Python

An agent can interpret a reference, write `bpy` code, run Blender in background mode, render views, inspect those images, and revise the script. Blender supports executing Python from the command line ([official testing documentation](https://developer.blender.org/docs/handbook/testing/python/)).

Best initial candidates here: turret bases and barrels, robots, articulated spider legs, mines, scrap, crates, and modular arena pieces. This is an engineering recommendation based on their separable geometry, not a measured comparison of generated output. Parameterized scripts make proportions, colors, pivots, and variants reproducible. Organic detail and polished character animation are harder and need evaluation.

The community [MCP for Blender](https://github.com/ahujasid/mcp-for-blender), formerly blender-mcp, supports live scene manipulation and Python execution. It also integrates external assets and generation services such as Rodin and Hunyuan3D. A demonstration made through this add-on may include externally generated or downloaded geometry, so assess the complete workflow. MCP is useful for interactive work; checked-in scripts are preferable for repeatable production builds. Compatibility with the installed Blender version has not been tested.

### Image-to-3D candidates

| Candidate | Verified capability | Suggested role |
|---|---|---|
| [Meshy](https://docs.meshy.ai/en/api/image-to-3d) | Image-to-3D API, textures, remeshing and polygon controls | First hosted comparison against Blender scripting. |
| [Meshy multiple views](https://docs.meshy.ai/en/api/multi-image-to-3d) | Accepts 1–4 images of the same object from different angles | Use only consistent approved views; do not submit an animation sheet as one reference. |
| [Tripo](https://platform.tripo3d.ai/docs/generation) | Text, image, and multiview model generation API | A second hosted candidate if first results need comparison. No quality ranking established. |
| [TRELLIS.2](https://github.com/microsoft/TRELLIS.2) | Local image-to-3D; upstream lists Linux and at least 24 GB NVIDIA VRAM | Local trial after the export pipeline works. Windows/WSL compatibility and usable headroom remain unverified. |
| [Hunyuan3D 2.1](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1) | Shape and PBR texture generation; upstream lists 10 GB shape, 21 GB texture, 29 GB combined VRAM | Secondary local experiment; do not assume the combined pipeline fits a 24 GB card. |

Local checks confirmed Blender **5.2.1 LTS** and an **RTX 4090, 24 GB VRAM**. No model weights were installed. TRELLIS.2 describes its model/code as MIT with separately licensed dependencies; Hunyuan uses a community license. Preserve provider/model/version and applicable terms with asset provenance; this investigation does not establish blanket commercial clearance.

Generation is not the end of asset preparation. Evaluate hidden surfaces, disconnected pieces, silhouette, UVs, materials, triangle count after export, separable joints, pivots, and animation deformation. Decimation can reduce geometry but does not establish animation-ready topology.

[Meshy's rigging API](https://docs.meshy.ai/en/api/rigging) explicitly focuses on recognizable humanoid bipeds and excludes non-humanoid assets. Do not assume it will rig spider drones or turrets. Use mechanical part hierarchies or deliberately authored rigs for these; bake supported animation into the export when appropriate.

## Concept-to-game asset pipeline

1. Use the existing web app to approve silhouette, palette, proportions, and material style. Generate a clean single-object three-quarter view with neutral lighting, no lettering, no cast shadow, and a simple background. Avoid reusing the magenta sprite-sheet prompt unchanged.
2. For complex shapes, create matching front/side/back views through edits of the approved design and inspect consistency. Multiple contradictory AI views can be worse than one clear view.
3. Build with a Blender script or use an image-to-3D provider, then bring the candidate into Blender for normalization and cleanup.
4. Apply a shared asset contract: scale, ground-contact origin, defined forward axis, material palette, required named parts/sockets, collision footprint, and animation names. Confirm Blender-to-glTF-to-Godot axis conversion using a test arrow and a muzzle marker.
5. Export GLB and place it under a Godot wrapper scene that owns collision, scripts, and gameplay sockets. Do not attach game logic inside generated mesh hierarchies that may change on reimport.
6. Review from the actual gameplay camera in a crowded arena. Archive the source reference, script or provider parameters, editable blend file, approved GLB, preview renders, validation results, and asset version.

Godot recommends [glTF 2.0 and supports GLB](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html). Direct blend import invokes Blender to convert to glTF; explicit GLB delivery gives a reproducible game import without requiring Blender in every game build environment. Use glTF-compatible materials; bake or recreate Blender-specific procedural effects rather than expecting arbitrary shader graphs to transfer ([Blender export documentation](https://docs.blender.org/manual/en/3.6/addons/import_export/scene_gltf2.html)).

Suggested initial budgets, to validate rather than treat as requirements: common enemies 1–3k triangles; turrets 1–5k; player 3–10k; usually 1–2 materials per common actor, shared palettes, and 512–1024 textures where needed. Count actual exported triangles, not a provider's requested face count. Rig complexity, draw calls, shadows, physics, and targeting cost matter as well as triangles.

Preserve pooling. Start with simple collision shapes, bounded shadow casting, restrained transparency, and shared materials. The existing EnemyQuery cache avoids repeated group-array allocation but does not remove repeated linear target scans. Profile targeting and introduce spatial indexing if it becomes a bottleneck. [MultiMesh](https://docs.godotengine.org/en/latest/tutorials/performance/using_multimesh.html) can help repeated props/projectiles; it does not automatically optimize independent skeleton animation or actor physics.

## Web app evolution

Initially change only prompting/reference conventions and use exported images. Avoid building a full 3D orchestration UI until the trial shows which workflow works.

If justified, add a separate model-generation domain alongside images/audio:

- `ModelProvider` operations for submit, inspect status, fetch artifacts, and optional cancellation where supported.
- Model jobs, asset versions, and reference-image links; record provider task ID, model version, parameters, retry status, cost metadata, and provenance.
- Inngest stages for submission, durable waiting/polling or webhook completion, download, Blender processing, validation, and review. Reconcile uncertain submissions rather than blindly retrying paid generation.
- A dedicated local Blender worker using vetted processing scripts. Run long generation/rendering/export work outside Next.js request handlers; begin with one GPU job at a time.
- A model viewer and side-by-side reference preview, with triangle/material counts, animation preview, and explicit draft/approved/rejected state.
- Immutable approved asset packages containing GLB, manifest, previews, and source references. Promote approved versions into the game; avoid automatically overwriting live game assets with each generation.

Hosted services need uploaded images, supported data URIs, or accessible URLs, not a Windows file path. Meshy's documented data-URI input is compatible with the app reading local images and submitting their bytes.

## Small trial before committing to tools

Use the same approved references for a basic turret, spider drone, and player bot. Start with Blender scripting and one hosted image-to-3D service; add TRELLIS.2 only if local generation remains attractive.

Record time and total cost per *accepted game asset*, including failed candidates and cleanup. Score style consistency, silhouette at gameplay distance, articulated parts, animation effort, exported triangle/material count, reimport stability, and frame time at crowd scale. A beautiful still render is insufficient.

The first implementation should combine the primitive 3D gameplay loop with one scripted turret and one articulated enemy. This answers the two biggest uncertainties—game feel and usable AI asset production—before full content conversion or web-platform expansion.
