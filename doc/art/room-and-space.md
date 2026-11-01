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
