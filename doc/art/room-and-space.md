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

The hull plating is `WorldGeometry.hull_material(theme)`: the floor theme's albedo, normal and roughness, world-triplanar and
darkened. Glow strips use the stage's rim material, so they carry the floor theme's colour.

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
