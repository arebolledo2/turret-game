# Room and space backdrop

The arena is a room aboard a ship. `ArenaRoom` builds its walls just outside `WorldGeometry.HALF_ARENA` (a `GAP` of 0.12 m from the
bounds); nothing in the room is collidable, the walls are scenery and the playfield clamp is unchanged. Beyond the walls is space:
`SpaceBackdrop` is one huge plane 30 m under the floor painted by `assets/shaders/space_backdrop.gdshader`.

## Why the walls differ per side

The camera is orthographic and looks down about 52 degrees from the south, so a raised point appears 0.765 m per metre of height
further up the screen than its foot.

| Wall | Height | Why |
|------|--------|-----|
| Back (north) | 2.62 m | Faces the camera, so its inner face shows: plinth, sloped sill, open window bays onto the starfield, a lintel and a brass coping. |
| Sides | 1.6 m | Seen edge-on, so they are profiled: a brass kick, a riveted slope leaning back about 58 degrees (the face the camera sees), and a brass coping. |
| Front (south) | 0.5 m | Would hide 0.77 m of floor per metre of height, so it is a parapet with a chamfered brass cap; its outer hull face and portholes show below it. |

`CAMERA_EDGE_MARGIN` / `_BACK` / `_FRONT` in `GameConstants` set how far past the arena bounds the view may reach on each side so
those walls come into frame; `CameraRig.clamp_focus` is asymmetric for that reason. A view larger than the room centres between
the front and back limits (so the overview focus is not exactly the origin).


## Space themes

`SpaceThemes` (`scripts/registries/space_themes.gd`) holds the display data and shader settings: `deep_space`, `nebula`,
`asteroid_belt`, `gas_giant`, `warp`. `heading` (degrees, 0 = up the screen) and `speed` (m/s) give the direction and rate the ship
travels. Choose one per layout with the `space` key in `ArenaLayouts`, or per run with `RunConfig.space_theme` (`--space=<id>`).
Zoneless runs take the space theme of the layout that uses their floor theme.

The camera is orthographic, so depth gives no parallax; the shader moves each layer with the camera by a fraction of its movement
and scrolls it by `drift * k`. To add a theme: add an entry to `SpaceThemes.INFO` (params must be uniforms of the shader;
`test_arena_room.gd` checks) and use it from a layout.

## Materials and light

Walls are profiles extruded by `ArenaRoom._extrude` (draw the visible side of a polyline on its left). Hull plating is
`assets/shaders/hull_plating.gdshader` (world-space riveted panels, base colour per floor theme in `WorldGeometry.HULL_COLORS`);
copings, kicks and caps are muted brass. Corner towers hide the joins between walls of different heights. The floor rim is the
only continuous light line; wall lamps (pillar pips, front portholes) glow at `LAMP_ENERGY` and everything stays under the bloom
threshold of 1.0 so nothing blooms into a white outline. Camera margins (`CAMERA_EDGE_MARGIN*`) leave room for each wall's
full footprint and, at the back, the top HUD bar (`ArenaRoom.HUD_TOP_ALLOWANCE`).

## Detail pass

- **Hull shader** (`hull_plating.gdshader`): a height field (bevelled seams, rivet domes, recessed inset panels, louvre vents) is
  differentiated into a normal; panels vary in tone, roughness and metal; seams show brass edge wear; grime pools at the base.
  The pattern follows the floor theme (`WorldGeometry.HULL_MOTIFS`): plates, hex cells (hexworks), planks (marquetry) and rimed
  plates (frost). The front hull uses panels twice the size so it does not read as brickwork.
- **Brass** (`brass_trim.gdshader`): brushed along the wall, with a little patina. Copings are profiles with rounded noses and a
  raised rail; `ArenaRoom._extrude` smooths joints gentler than 40 degrees so arcs look round.
- **Kit pieces** in `arena_room.gd`: fluted pillars with plinths and corbelled capitals, window mullions and transoms, a dentil
  row, lamp posts on the side copings, buttress ribs, portholes, a rub-rail and a pipe on the front hull, stepped corner towers.
  Everything is merged into one mesh per material; only the towers carry real lights (four shadowless omni lights).
- **Light**: lamps glow below the bloom threshold, and soft additive pools (a `Glow` child) sit on the slopes and the floor. The sun
  leaves the left slopes in shadow, so the stage adds a cool fill light that only lights `ArenaRoom.LAYER`.
- **Sky** (`arena_sky.gdshader`): the old gradient plus sparse stars, rendered once, so brass has something to reflect.
- **Backdrop**: star trails (`streak`) have a round head, a fading tail that cools towards `trail_tint`, and a length per star;
  a dark gantry layer with blinking nav lights (`hull_density`) passes between far and near stars; warp adds an engine glow
  (`engine_amount`). The nebula uses 2 to 3 noise octaves instead of 5 and is skipped when `nebula_amount` is near zero.

## Backdrop pass 3

- **Stars** are sized in screen pixels (from the plane's screen derivatives), not metres: dust 0.6 px (70%), common 1.0 px,
  bright 1.6 px, hero 2.2 px with a faint four-point spike (1%); four colour classes tinted by `star_tint`; 20% twinkle.
  Keep `star_brightness` at 1.2 or less so only hero stars bloom. `star_dust` adds faint unresolved points.
- **Gas giant**: about 11 m, tilted (`planet_tilt`), bands in `planet_dark` / `planet_color` / `planet_light`, limb darkening,
  a soft terminator, `planet_storm`, `planet_ring` (planet and rings shadow each other), a lit-side rim, and a phased moon
  (`moon_radius`, `moon_position`). It holds still; its limb crosses the top strip at zoom 0.6.
- **Sky**: nebula density ramp `nebula_a` -> `nebula_b` -> `nebula_core` with domain warp, `nebula_filaments` and `dust_lanes`
  (which also dim the far stars); a Milky Way (`band_amount`, `band_angle`), spiral galaxies (`galaxy_amount`) and a soft
  `hull_shadow` around the room's silhouette on the plane. Debris rocks are now solid and lit from `light_direction`.
- Every feature uniform defaults to 0 and skips its work when off; `test_space_backdrop.gd` checks this.

## Wall bays and exterior

- **`RoomMeshKit`** (`scripts/game/room_mesh_kit.gd`) batches boxes, oriented boxes, cylinders, extruded profiles and glow quads per material, then `flush` emits one mesh per material (vertex colours carry the per-part tint). The room stays at 15 meshes or fewer; `test_arena_room.gd` checks it.
- **Side walls**: the sloped face is divided by brass ribs into bays; each bay carries one of five modules (vent, panel, stencilled digits, gauge, hatch) chosen from the bay index, so no two neighbours repeat. Lamp posts with glow pools, bolts and copestone joints sit on the moulded coping, which has an enamel inlay in the theme `accent` colour (`WorldGeometry.HULL_MOTIFS`).
- **Front hull**: quarter-round cap, ribs, five module kinds, rub-rail, pipe and clamps; it stays at or below 0.5 m so it never hides the playfield.
- **Back wall**: bulkhead door at bay `count / 2`; lit alcoves with slowly rotating flywheels at bays 1 and `count - 2` (turned in `_process`).
- **Floor shade**: `_build_shade()` adds multiply strips along the wall bases (child node `Shade`) so the floor darkens where the walls meet it.
- **`ShipExterior`** (`scripts/game/ship_exterior.gd`): side decks with brass rail, port (coral) and starboard (teal) running lights, pipe bundles, and every 6.4 m a solar wing, antenna mast or radar dish; engine nacelles with exhaust glow; a back deck with vents, crates, domes and masts; a docked pod. All shadowless, built under an `Exterior` child.
- At the default zoom only about 0.28 m of exterior shows at the sides (`CAMERA_EDGE_MARGIN` is unchanged); most of it appears when the camera is pulled back or the window is wide.

## Lighting pass

All of it lives in `ArenaStage._build_lighting` plus two small shaders; look at it with `tools/preview_floor_theme.tscn` (it builds the real stage, so the grade and vignette show).

- **Ambient**: a flat cool colour (`AMBIENT_COLOR` 46568a, energy 0.6, sky contribution 0.3) instead of the sky, so faces away from the sun keep form. Sun shadows are lighter (`SUN_SHADOW_OPACITY` 0.72, was 0.9). Bloom threshold stays 1.0. The floor albedo gain that lifts the floor itself belongs to `WorldGeometry.floor_material`, not here.
- **Studio sky** (`arena_sky.gdshader`): the old dark gradient and stars plus (a) a warm-white softbox at (0, 0.88, -0.47) (`soft_*`, energy 0.8), which is where the orthographic camera's mirror direction lands for any upward-facing surface, so flat copings catch it and rounded noses sweep through it; (b) a weaker southern fill (`fill_*`, 0.35) that gives the front cap's quarter-round a highlight band as it turns; (c) a lower-hemisphere bounce (`bounce_color`, `bounce_level` 0.16 luminance) for slopes and hull faces, which mirror downwards. `set_floor_theme` passes the theme's `RIM_COLORS` entry as `bounce_color` (the shader normalises its luminance, so every theme gets equal light). Uniform changes re-render the sky (checked), and it has no `TIME`. Each light's radiance stays at 0.8 or less (metal only dims it), so bloom is untouched. Low east/west strip lights were tried and did nothing for side copings, so they are not there.
- **Grade**: `Environment.adjustment_*` after tone mapping: contrast 1.08, saturation 1.1 and a 1D lookup table (`GRADE_STOPS`) that cools shadows (about +8 blue at 20% grey, near-black stays near black) and warms highlights. The advisor's first suggestion (#0a1226 -> #7f8aa0 -> #fff0dc) lifted blacks and mids so far the picture went milky and navy; the five-stop table keeps luminance and only shifts hue.
- **Vignette** (`ArenaVignette`, `vignette.gdshader`): a full-screen `ColorRect` that ignores the mouse, 40% blue-black at the corners (`strength`, `inner_radius` 0.55 to `outer_radius` 1.05, `roundness` 0.6 blends circle and ellipse). It sits on canvas layer 0, not -1: `PlayfieldView` (the 3D picture) is layer -1 and would tie, and `GameHud` is the default layer 1, so layer 0 dims the arena and never the HUD. `ArenaStage.vignette` owns it; `test_arena_lighting.gd` covers the layer order, mouse filter and uniform names.

## Exterior pass

`ShipExterior` was rebuilt so no prop reads as another object (the old dish read as a table, the wings as paper, the pipes as a ladder). Check it with `tools/preview_exterior.tscn` (flags in its header: `--shot=name,tx,tz,size[,ox,oy,oz]` close-ups from the game's camera angle, `--zoom`, `--player` for the default view, a wide-window resolution to see the side decks).

- **What you see where**: the camera sees only tops and south faces, so detail goes there. At 16:9 and default zoom only the pipe run shows at the sides; a 21:9 window at zoom 0.6 shows whole decks. Over the back coping only the top 3 to 4 m of the back deck clears the wall (cargo stacks are 3 to 4 containers high, comms towers carry dishes at that height, a portal crane stands behind), and the pod hangs below, visible mostly when zoomed out.
- **Side decks** now run north to the back deck's far edge (the old flat gap at the top corners is gone), with a brass and steel rail on posts and port/starboard lights. Five modules per deck, different order each side (`MODULES_LEFT` / `MODULES_RIGHT`) with small fittings between them: radar dish (paraboloid on a pedestal, feed horn on three struts), solar wing (boom, gimbal, two columns of four hinged panels, 4 x 4 cells each with per-cell tone jitter, silver busbars), cargo stack, radiator roof (two tilted panels with coolant tubes and a hot ridge), fuel tank, comms mast with three small dishes; fittings are a hatch with a vent, bollards with a locker, ventilators with a cable reel.
- **Pipes**: a cream main with colour bands, a dark steel line and a copper line on low saddles at uneven spacing, flanges every 3.2 m, an expansion loop, a handwheel valve and a junction box in the gaps between modules.
- **Materials** (7 meshes, so room + exterior stays well under 15): the room's hull, brass, frame and paint, an unshaded lamp (albedo 0.85), a new glossy `_cell` (metallic 0.7, roughness 0.25) for the solar cells, silver and radiator fins so they pick up the studio sky, and a multiply `_shade` for contact shade. Painted parts use very low albedos (a lit 0.3 reads as near white under the 1.8 sun), see the constants at the top of the file.
- **Contact shade**: `_blob` adds a 30-triangle fan (dark centre, white rim) under every module and tall prop; the material multiplies and never brightens.
- **Back deck**: 14 slots (`BACK_KINDS`) of cargo towers, comms towers, ventilators, domes, vent blocks and a gantry crane, four light masts, and a pod with ribs, canopy, thrusters and a ribbed gangway. Nacelles are lathe bodies with brass bands, vents, top fins and a dark bell round a blue throat.
- **Kit helpers** (`RoomMeshKit`): `add_lathe` (solid of revolution; trace outward faces from the high end down, a concave bowl from the vertex out; optional per-point colours), `add_torus`, `add_tube` (swept pipe for bends), `add_quad` and `triangle_colored`. `test_ship_exterior.gd` covers them and the exterior's budgets (mesh count, about 29k triangles, shadowless, bloom-safe lamps, decks meeting the back deck).
