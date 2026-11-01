# Room and space backdrop

The arena is a room aboard a ship. `ArenaRoom` builds its walls just outside `WorldGeometry.HALF_ARENA` (a `GAP` of 0.12 m from the
bounds); nothing in the room is collidable, the walls are scenery and the playfield clamp is unchanged. Beyond the walls is space:
`SpaceBackdrop` is one huge plane 30 m under the floor painted by `assets/shaders/space_backdrop.gdshader`.

## Why the walls differ per side

The camera is orthographic and looks down about 52 degrees from the south, so a raised point appears 0.765 m per metre of height
further up the screen than its foot.

| Wall | Height | Why |
|------|--------|-----|
| Back (north) | 2.5 m | Faces the camera, so its inner face shows in full: a wall of pillars and open window bays through which the starfield is seen. |
| Sides | 1.6 m | Seen edge-on; only their coping (a glow strip) is visible. |
| Front (south) | 0.5 m | Would hide 0.77 m of floor per metre of height, so it is a parapet; its outer face (portholes) shows below it. |

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
