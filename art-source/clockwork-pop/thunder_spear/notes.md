# cp_thunder_spear-v1: notes

## Iterations used: 6 of 8 (final iteration 6 passes the contract)

1. First full build: bmesh geometry with 3-4 segment bevels, a 4-image procedural atlas (base colour, ORM, normal, emission at 1024 px, 4x4 tiles of 256 px, one tile per surface) and vertex-colour AO. **Failed `origin_xy_centred`**: the validator measures the bounding-box centre, and the long forward lance put it at y = 0.47.
2. Fixed: the script now slides the whole turret back along Y so the bbox centre sits at y = 0.12. Aim keeps identity rotation on the pedestal axis. The contract passed. Also shortened the lance (it was about 2x too long against the box) and enlarged the box.
3. Mint dome jewel was too small and dull: made it bigger and gave the jewels brighter cores. Brass is now more saturated. Added a coral front lip so the top plate wraps over the front edge. Made the tip and rear ring bigger.
4. Jewels had washed out to pastel. Brought back saturated gem colours and lowered the emission. Made coral redder. Scaled up the box, collar, shaft, coils and tip to match the concept's chunkier proportions. Moved the pedestal jewel and button so they match the concept's left/right order.
5. Final polish: warmer ivory, slightly brighter teal, crisper brass roughness.
6. Coordinator feedback (the harness now validates centring on the `Aim` pivot via `origin_node`):
   - Removed the slide-back. The pedestal and Aim axis now sit at world (0, 0), and the lance extends forward along +Y.
   - Cut the budget from 51,610 tris / 79 objects to 17,066 tris / 17 objects:
     - parts are joined per material into one static `Base_<mat>` object and one `Aim_<mat>` object, each under Aim
     - lower tessellation: cylinders 24 sides (big rings 36, coils 28), 2-segment bevels, 6x3 rivets, lighter jewel and bezel meshes
   - The renders look the same as iteration 5.

## Construction
- Static parts: three coral feet with brass rims and rivets, teal foot struts, a hex brass base trim, a tapered hex teal pedestal (mint jewel in a brass bezel, cream button, vent insets), a riveted brass hex top plate, and the lower coral swivel ring.
- `Aim` (empty, identity rotation, z = 0.50) carries:
  - the upper coral swivel, dark neck and coral knob
  - the teal capacitor box with a rear brass strap
  - two coral top plates, a teal knob, and the mint dome jewel on a brass seat and bezel
  - violet jewels with coral bezels on both cheeks, plus rivets
  - the rear coil housing (invented): big brass ring, a vented cap with coral hub and rivets, and coral clamps
  - a double brass front collar with a dark coil gap
  - the teal lance shaft, three brass coil rings with dark cores, a brass tip collar with two mint jewels, and the ivory 6-facet spear head
- `Muzzle` is a bare empty under Aim at the spear point, forward +Y.
- Textures: everything comes from one shared 4-image atlas. Brass has lathe-brushed streaks and polish bands. Teal, coral and cream have a satin cloud and orange-peel normal. The jewels have a radial core, darker rim, facet sectors, a specular dot and a mild emissive core. A clear coat on the jewels and ivory adds the glossy finish. Vertex-colour AO uses floor 0.55.

## Remaining flaws vs concept
- **Texel density:** it is uniform within each surface, but not between surfaces. Each surface's largest part fills its tile. The swatches are low-frequency, so this does not show.
- **Box shape:** the concept's box is more barrel-like toward the rear, while mine is a bevelled cube plus a cylindrical housing.
- **Swivel and feet:** the coral swivel collar is a little shorter, and the feet a little smaller, than in the concept.
- **Back view:** the vents on the rear pedestal faces read as flat inset panels.

## Final counts
- Triangles: 17,066
- Mesh objects: 17 (8 static, 9 under Aim)
- Materials: 10, all sharing the same 4 textures at 1024x1024

## Self-score: 7.5 / 10
