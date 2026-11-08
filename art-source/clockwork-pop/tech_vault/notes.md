# Tech Vault - run tech_vault-v1

Script: `build_tech_vault.py`. It builds everything from scratch in bmesh, generates its textures with numpy and exports `tech_vault.glb`.
Helper scripts in `tools/` are for my own inspection only and are not part of the build: `inspect_glb.py`, `profile_tris.py`, `closeup.py` and `split_tris.py`.

## Iterations: 5 of 8 used. The contract passed on all 5 runs.

1. **iter01**: the first build passed the contract. It had five problems:
   - The metal looked cloudy and weathered because the low-frequency noise in base colour and roughness was too strong.
   - The gunmetal was too light and silvery.
   - The glass covered the interior in a milky veil. It was a double-sided slab at alpha 0.16.
   - The interior was too dark.
   - The whole layout was mirrored against the concept. Facing the window, the concept's door is on the viewer's left, which is +X, and the vents and server stack are on the right.
2. **iter02** fixed those problems:
   - Every assembly is mirrored in X at finish time, with face winding reversed.
   - The low-frequency noise was cut to about a quarter, keeping only fine speckle and pits.
   - The gunmetal tint is darker and metallic is lower (0.78).
   - The glass is now a single-sided plane at alpha 0.07 with backface culling.
   - The interior material got a faint cyan emissive factor.
   - The beam cone is fainter, and I cut down wasted triangles on rivets and washers and on tiny boxes, which now get a 1-segment bevel.
3. **iter03**: in the three-quarter view the core was hidden behind the frame, so I moved the core and pedestal 8 cm toward the glass. I made the vault wheel chunkier: a taller rim, a bigger hub and thicker spokes. The interior got brighter, and I added a glow strip on the inner sill.
4. **iter04**: added side-wall detail: two junction boxes with indicator and LED, triple conduits to the ceiling, and a cable bundle in the back corner. I also made the glass tint darker so it is less milky and the pits shallower.
5. **iter05**: made the interior tint more saturated cyan to get closer to the concept. This is the final iteration.

## Final counts (from validate.json for iter05)

- **Triangles: 73,006.** 41.5k are inside the window cavity, including the core and rings, and 31.5k are exterior.
- **Mesh objects: 14.** Static parts are merged into one object per material, all under `Body`:
  - `Vault_Gunmetal` 25.2k: shell, plates, frame, door wheel, brackets, feet, pedestal flanges and coil.
  - `Vault_Steel` 16.1k: hex bolts, rivets, slats, pipes, caps.
  - `Vault_Copper` 7.1k: helix windings on the pedestal and on four coil inductors.
  - `Vault_Brass` 4.9k: raised PCB traces, chip pins, wiring, pipes.
  - `Vault_Trim` 4.0k: cyan trim lines, window rim, capacitor bands.
  - `Vault_Interior` 4.0k: cavity lining, server stack, modules, capacitor sleeves.
  - `Vault_CoreGlow` 1.1k, `Vault_LED` 120, `Vault_Beam` 64, `Vault_Circuit` 56.
  - `Window_Glass` 42. It is a separate transparent mesh facing +Y.
- **Moving parts:** each sits under its own empty, and all three empties are at the core centre (0, 0.10, 0.575):
  - `Core_Sphere` 2.5k, under `Core`: core sphere plus a translucent halo.
  - `Ring_Outer_Mesh` 4.7k, under `Ring_Outer`: a horizontal ring that spins about Y.
  - `Ring_Inner_Mesh` 3.2k, under `Ring_Inner`: a ring in the XZ plane that spins about X.
  - The sweep spheres were checked so that they clear the pedestal and all interior parts.
- **Materials: 12.**
  - Textured metals: Gunmetal, Steel, Interior, Brass and Copper. They share one base-colour texture, multiplied by a per-material tint that exports as `baseColorFactor`, plus one ORM texture and one normal map.
  - Circuit: one texture drives both base colour and emission.
  - Emissive: Trim_Glow, Core_Glow and LED_Red. Core_Halo and Beam_Glow are emissive and alpha-blended.
  - Window_Glass is alpha-blended.
- **Textures: 4 at 1024x1024**, saved as PNGs in `textures/` and embedded in the GLB:
  - `vault_metal_base`: seamless FFT noise with fine mottling, machining streaks, pits and specks.
  - `vault_metal_orm`: the glTF metallic/roughness map (G = roughness, B = metallic).
  - `vault_metal_normal`: OpenGL convention, built from the pits, dings and grain height.
  - `vault_circuit`: dark teal board with cyan, gold and dim traces, pads and chips with pins.
- **Size:** 1.10 x 1.06 x 1.00 m, and the lowest point is z = 0.0 (the feet). GLB size is 6.8 MB, mostly the four PNGs.
- **Construction:**
  - Every mesh has one UV layer called `UVMap`, made by world-space box projection at 0.6 m per tile, which keeps texel density the same across parts. The circuit board is mapped one-to-one onto its texture.
  - Hard edges are bevelled: 1 to 3 segments limited by angle, plus a 6 cm chamfer on the shell. Shading is smooth, with sharp edges above 35 degrees.
  - The window cavity is cut with an exact boolean.

## Remaining flaws compared with the concept

- The cyan trims and the core read as pale white-cyan in the checker. The brief expects this for emissive materials, but the concept's saturated cyan glow and the light spilling onto the floor are lost.
- The interior is lit by a constant emissive tint, not by the core. Nothing bakes light from the core, so in-engine it needs an OmniLight to get the concept's glow.
- At the harness three-quarter angle (30 degrees elevation) the deep window recess still hides part of the core. The concept's camera sees the interior more head-on.
- The shell uses a hard 45-degree chamfer. The concept's armour edges are softer and more rounded.
- The gunmetal reads slightly lighter and cooler than the concept's charcoal under the harness's grey world.
- At 73k triangles the model is above the 30k-60k range the user suggested. The biggest costs are bolts and rivets (about 9k), the helix coils (about 7k) and the bevelled small boxes. If needed, it could get down to about 55k by thinning bolts and rivets and coil turns, without visible loss at game distance.
- Many vertex islands: loose components = 8.2k. This is because each part is merged rather than welded, and glTF splits vertices at hard edges. It is harmless.
- Housekeeping: an early close-up render used a relative output path and wrote `C:\renders\closeup_a\` (3 PNGs) outside the run folder. A safety check blocked my removal, so that folder needs to be deleted by hand.

## Self-score: 7.5 / 10

The silhouette, layout, materials and recognisable details all match: the window frame with bolts and latches, the vault wheel on the correct side, corner brackets, trim lines, top hatch and stubby feet. The interior is genuinely dense: a circuit backplane with chips and raised traces, the coiled pedestal, a capacitor bank, a coil bank, the server stack with vents and LEDs, a canister, pipes, conduits and junction boxes. What holds the score back is that the glow and luminous interior mood, which carry most of the concept's appeal, do not come through in the checker renders.
