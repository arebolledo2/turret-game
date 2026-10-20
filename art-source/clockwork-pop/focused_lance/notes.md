# cp_focused_lance-v1 notes

Built inline (no sub-agent) from the favorited concept `ComfyUI_00341_.png` (batch 7b28a18c, "Shock Lance Level 5"), reusing the Resonance Bell texture atlas and helpers from `cp_shock`.

- Iterations used: 3 of 8, contract passes on all three.
- Static: plinth, three cream feet with brass tips, flared bell body, coral hoops, brass shoulder ring. Aim carries the teal head drum, crystal socket, amber crystal, lance barrel, rear stub, brass rings and ivory tip. Muzzle at (0, .92, .90) world.
- Iter 1 to 2: barrel too short/thin, plinth inset turned ivory because material slot 5 was repurposed from "dark cavity" to ivory (fixed to slate), feet hidden under the skirt (raised the skirt, moved feet outward), crystal emission lowered 2.0 to 1.2.
- Iter 3: narrowed the bell body and thickened coral hoops.
- Counts: 10,764 triangles, 14 mesh objects, 8 materials, 4 textures at 1024.
- Remaining flaws: bell is still a wider cone than the concept's taller near-cylindrical body; crystal reads pale in the checker (emissive); no vertex-colour AO; the concept's tiny side bolt is omitted.
- Self-score: 7/10.
