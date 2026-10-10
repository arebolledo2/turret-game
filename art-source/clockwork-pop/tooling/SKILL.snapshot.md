---
name: 2d-to-3d-asset
description: Convert or polish a 2D concept image from image-gen-web into a Godot 3D candidate using scripted Blender geometry, textures and optional animation, then verify it in-engine. Use for concept-to-model work for turret-game.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent
---

# 2D concept -> 3D game model

Replaces the retired 2D sprite skills (`composer-to-game-assets`, `enemy-asset-pipeline`). The game is native 3D; 2D art is
concept reference only. Historical comparisons: [FINDINGS.md](FINDINGS.md); recommendations also reflect the user's workflow preferences.

## Recommended defaults (use unless the user says otherwise)

- **Codex: use Sol (`gpt-6.1-sol`) at high effort. Claude Code: use Sonnet (`claude-sonnet-5-5`) at high effort.** An explicit user model/effort choice overrides these defaults.
  The earlier Claude guidance still applies: avoid Haiku/medium for this workflow; reserve xhigh/Opus for hero assets.
  Historical Sonnet-high runs used roughly 120k tokens and seven minutes per asset; this is not a forecast for Codex.
- **Budgets are generation targets, not mandatory caps:** start around 5,000 triangles, 16 mesh objects and 8 materials.
  For polished crowd enemies, 5K–10K triangles is a provisional starting range, not a proven performance limit.
  Use judgment to exceed them when smoother silhouettes, richer materials or animation need it. Report actual counts and
  the reason for extra complexity; optimize performance after visual acceptance. Do not abort export or damage the model
  solely to hit a target. `new_task.py --budget soft` is the default; use `--budget standard` for explicitly requested hard
  caps, or `--budget none` for open-ended polish. Scale, orientation, pivots and a valid self-contained export remain required.
- **Use a contrasting screenshot background.** Pale/chrome/translucent assets usually need a dark desaturated backdrop;
  dark assets may need a light one. Keep useful studio reflections separate from the camera backdrop, and choose colour
  with `--background` when generating the task. Inspect silhouette, transparency and glow on that backdrop and in Godot.
- One agent per asset, 8 harness iterations max, one run folder per attempt.

## Workflow

1. **Pick the 2D image** and view it (Read tool). Note the key parts, colours, materials, and any parts that must move
   (legs, emitters, turrets, barrels). Decide the contract nodes: legged enemies keep `Leg_L/R_0..2`; turrets use `Aim` +
   `Muzzle`; a new articulated part set needs its own empty names. Hoverers: `--ground-gap 0,0.6`.
   When selecting concepts for a conversion batch, favor bold silhouettes, separated limbs and clear material regions that
   read at gameplay distance. Choose the 2D concepts before converting them; use the sibling `image-gen-api` skill for
   image-gen-web operations. Extra views may clarify hidden geometry but their benefit has not yet been tested here.
2. **Generate the task** (writes the reference copy, contract JSON and `3d-eval/briefs/BRIEF_<id>_<budget>.md`):
   `python -I 3d-eval/new_task.py --name <id> --image <png> --title "<Name>" --goal "<what you see>" --archetype legged|hover|turret`
   Archetypes prefill the contract: `legged` = `Leg_L/R_0..2` (ground-centred), `turret` = `Aim` + `Muzzle`, `hover` = no legs
   (pass `--nodes Emitter_0,...` for any articulated parts). Override any default (`--height`, `--max-width`, `--ground-gap=-0.02,0.1`,
   `--max-materials`, `--budget none`). Use `--platform codex` (default) or `--platform claude` so the generated prompt names
   the correct model. Write `--goal` yourself from the image; do not paste the generation prompt.
3. **Spawn the agent** with the platform's recommended model at high effort (or the user's override), and the prompt the script prints. Agents only write to
   `3d-eval/runs/<run>/` and must not read other runs. **Batches:** one task + one agent per asset, all spawned in the same message
   (four ran in parallel without trouble). Record each agent's completion token count; they are not stored in run folders.
4. **Summarise a batch**: `python -I 3d-eval/summarize.py <run> <run> ... [--ref <concept.png>]` prints a table (final iteration,
   triangles, objects, materials, size, contract, self-score) and writes a contact sheet to `3d-eval/reports/`.
   **Review the result yourself**: Read `3d-eval/runs/<run>/renders/iterNN/compare.png` (the last iteration) and the run's
   `notes.md`. The harness only checks the contract (nodes, size, budget); fidelity is a judgment call. Make a side-by-side
   with `magick montage` and show the user; ask for a blind ranking when comparing variants.
5. **Verify in Godot** (see below) before calling it done.
6. Report: iterations, triangles/objects/materials, textures/animations, visual limitations, and measured tokens if available.
   Include frame times only when performance testing was requested and the machine was available for a meaningful comparison.

## Turrets (Aim + Muzzle)

Turrets use `Aim` (rotating head, at the tower axis, identity rotation) with a bare `Muzzle` empty under it facing +Y. Generate
with `--nodes Aim,Muzzle --marker-nodes Muzzle --nested Muzzle:Aim --muzzle-forward --ground-gap=-0.02,0.1` and size limits that
suit the concept (the Clockwork tower used `--height 0.9,1.6 --max-width 1.1 --max-materials 10`). Note: use `--ground-gap=-0.02,0.1`
with an equals sign when the first value is negative. In-engine swap point: `model` path in `scripts/registries/turret_registry.gd`.
`turret_actor.gd` only yaws `Aim` and fires from `Muzzle.global_position`.

## Texturing pass (optional second step)

After a geometry model is accepted, a second run using the platform default can add UVs and procedural textures: generate with
`new_task.py ... --textures --start-from 3d-eval/runs/<geometry-run>/build_<id>.py`. Start around 4 images at 1024px, embedded in
the GLB; use judgment to exceed those targets in soft-budget mode. Match the actual concept's materials rather than applying
generic grime. Preserve value contrast; use roughness, normal and emissive detail where it improves the result. Result on the
Clockwork tower: ~144k tokens, 3 iterations, same 4.8k triangles, 4 x 1024px images (5.6 MB GLB, ~4.6 MB
compressed in Godot), no measurable frame-time change. It reads richer in game than in the checker (weathering, rune glyphs,
glowing lens) but in the checker it is muddier than the concept: contrast between bright metal and dark iron is weak, no
normal/roughness maps fit under the 4-image cap. Textures matter less than silhouette at game camera distance.
Concepts with chunkier, simpler shapes (chibi) are the better input; fine detail is invisible from far away.

## Animation and polish (when requested)

Use a new run with `--start-from`, `--textures` and `--animations` for a polish pass. Preserve the previous candidate until
the new one has been checked. Improve geometry when needed; the source is a starting point, not a restriction to surface edits.
Export named rigid-part clips (for example Idle, Swim and Attack) on the established pivots and confirm their duration,
looping and playback after Godot import. Avoid material-only keyframes that glTF does not carry; drive optional shader or
emission pulses in a candidate wrapper. Provide an animated preview on a contrasting backdrop, not just a still render.
Do not apply the game's leg posing to custom fins/tentacles. Use a self-contained candidate scene/controller for playback
and keep temporary game swaps separate from permanent enemy registration.

## Crowd complexity and optimization

Triangle count alone does not predict crowd performance. Track mesh objects, used materials, animated nodes/tracks,
transparent layers and controller work alongside triangles. Combine geometry that moves together, reuse materials,
and give independent motion to parts whose movement reads at the game camera distance. Prefer texture detail over tiny
decorative geometry when it preserves the look; texture costs still need measurement. Use overlapping transparency deliberately.

Accept the appearance first, then simplify selectively: spend tessellation on major silhouettes and reduce small rings,
hidden surfaces and fine curve cross sections before damaging recognizable shapes. The Zenith polish experiment retained
most of its look at 9,952 versus 87,516 triangles, but animated crowd frame times barely changed. See
[FINDINGS.md](FINDINGS.md#subject-4-zenith-hoverer-sol-high-polish-and-10k-variant) for measurements and limitations.

When performance work is requested, compare animated and stopped playback as well as the baseline, using the same scene,
camera, renderer and import/LOD settings. Verify that the stopped variant actually stops playback. Profile animation/controller
and scene structure before assuming further triangle cuts will help. Fewer animated parts, lower update frequency or
distance-based animation detail are experiments to test, not established fixes. Change one factor at a time where practical;
report confounds and do not add overlapping CPU/GPU timing metrics. Validate both an individual asset and a representative crowd.

## In-engine verification (candidate swap, never overwrite originals)

From `turret-game/`, PowerShell 7. Godot console binary: `$env:USERPROFILE/Godot/4.7/Godot_v4.7.1-stable_win64_console.exe`.

1. Copy the GLB to `assets/models/game/<id>_candidate.glb`. Copy `spider_drone.glb.import` to `<id>_candidate.glb.import`,
   replace `spider_drone` with the new name and delete the `uid=` line (keeps the `import_vertex_ao.gd` post-script).
2. `& $godot --headless --path . --import`.
3. Temporarily point the model at it: one line in `scripts/game/combat_actor.gd` (`_build_enemy_model`, spider branch),
   tagged `# TEMP-...`. Missing `Leg_*` nodes are tolerated by `_animate`.
4. Look at it: `godot --path . --resolution 1280x720 res://tools/capture_game.tscn -- --combat-demo` (not `--headless`);
   PNG lands in `.test-results/game-combat.png`. Crop and zoom to judge readability at game camera distance.
5. Performance is a later optimization step. Only benchmark when requested, with no competing GPU work. Compare two
   candidate and two baseline `--stress` runs, confirm the intended enemy count, and report median/p95 frame times.
   Ignore noisy draw calls and do not claim minimum-hardware performance. Skip benchmarks when the user excludes them.
6. `./run_tests.ps1`. Match articulation tests to the actual asset: the original basic enemy has six legs, while the
   Clockwork basic enemy is a `Body` hoverer. Preserve coverage for both supported model families.
7. Restore only the temporary swap, preserving any pre-existing user edits, unless the user wants it kept. Godot also drops stray
   `*.gd.uid` files on import; mention them.
   When a test is discarded, remove its game-only candidate files, extracted textures/imports, wrappers and preview scripts
   after checking references. Preserve the run's source/export and reports under `3d-eval/`; archive useful integration code
   there before removing it from the game. Verify the original assignments and clean game status without resetting unrelated work.

## Promotion into the game

- **Turrets are data-driven:** `scripts/registries/turret_registry.gd` entries have a `"model"` path; `get_model_path` falls back
  to `ion_turret.glb`. A new turret type needs a registry entry (stats, fire mode, price, ...) plus the GLB and its `.import`.
- **Clockwork collection:** `scripts/game/clockwork_models.gd` loads `assets/models/clockwork/cp_<key>.glb` and retains
  original models for `--legacy-assets` comparisons. Combat actors, turrets and tech drops select those models by role.
  `clockwork_motion.gd` poses cached rigid pivots; hoverers use Body, walkers use hip pivots, the hero aims its torso
  independently of root-level legs. Keep gameplay scale, hurtboxes, muzzle origins and attack radius aligned with the model.
- After visual acceptance and a frozen export, `python turret-game/tools/promote_clockwork_asset.py <key> --iteration N`
  copies the export, packed source, textures, contract and audit into the tracked game collection. Then import, review in
  Godot, and run relevant tests. Promotion itself does not prove animation or gameplay acceptance.
- **Manifest trap:** `tools/blender/build_assets.py` rewrites `assets/models/game/manifest.json` from its own `builders` list
  (`assets = [by_id[name] for name in builders ...]`), so hand-added records for generated models would be dropped the next
  time it runs. The Clockwork collection therefore uses its own manifest. `tools/audit_game_resources.py` checks both
  manifests, source/model/reference files and reviewed hashes when present.
- `tools/preview_clockwork_motion.tscn` renders actual imported pivots through the runtime controller; use
  `--fixed-fps 30` for its pose sequence. `capture_game.tscn -- --roster-demo` checks gameplay scale;
  `--mixed-stress --benchmark-seconds=10` measures the five-enemy roster with twelve turrets and a tech drop after a
  two-second warmup. Use `--legacy-assets` for baseline and `--reduced-motion` for the cosmetic-motion comparison.
  Verify logged model IDs and enemy counts; don't interpret visual-preview timings as performance evidence.

## Gotchas

- Blender procedural textures: set image colour space before assigning pixel buffers. Clear or reuse primitive UV maps
  before writing an atlas, and check the exported active UV layer; an unused correct layer can hide a broken export.
- Custom polar surfaces need consistent winding between centre triangles and surrounding ring quads. Opposite winding
  produced false ring-shaped highlights on wings and eyes even with clean textures; inspect normals before repainting maps.
- Name meshes distinctly from their required empty pivots. The validator tolerates `.001` suffixes, so a mesh named
  `Leg_L_0.001` can collide with the `Leg_L_0` empty in its lookup.
- For genuinely asymmetric turrets, configure `origin_node: "Aim"` to validate the central yaw pivot instead of forcing
  total bounds symmetry. Preserve the real base origin; don't add counterweight geometry just to centre the bounds.
- Judge emission and alpha surfaces in Godot as well as the checker. A contrasting backdrop is essential for pale fins.
- Inspect embedded image counts even on geometry passes; procedural iris/detail textures can exist without `--textures`.
- Agents sometimes burn an extra harness run for inspection (the cap is 8); tell them not to, as the brief does.
- Blender: `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`; the harness hardcodes it (`harness/run_eval.py`).
- `3d-eval/` is outside the nested `turret-game` git repo and not version controlled. Copy final scripts into
  `turret-game/art-source` or `tools/blender` only when promoting.
- No ambient-occlusion bake in generated models (the hand-built set has one via `bake_ambient_occlusion`), so they look a
  little flatter in game. A follow-up pass could add it.
- Concepts are single-view; unseen sides are invented. Multi-view concepts from image-gen-web would likely help (untested).
- One run per cell and a non-blind judge underlie the findings; re-test before treating them as settled.

## Files

- `3d-eval/new_task.py` - task generator. `3d-eval/harness/{run_eval,validate,render}.py` - build, check, render loop.
- `3d-eval/harness/subjects/*.json` - per-subject contracts. `3d-eval/briefs/` - briefs, `3d-eval/reports/` - comparison images, `3d-eval/summarize.py` - batch table. `3d-eval/runs/` - all results.
- Sibling skill `turret-game/.claude/skills/blender-assets` covers the hand-scripted original model family.
