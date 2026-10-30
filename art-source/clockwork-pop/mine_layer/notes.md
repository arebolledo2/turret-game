# cp_mine_layer-v1 notes

Iterations used: 6 of 8 (final = iter06, contract passes).

## What failed and how it was fixed
- iter01: `origin_xy_centred` failed (the dish and the long barrel pushed the bounds off-centre); the hopper was also too squat and the body too wide. Re-proportioned: slimmer hex body, taller hopper, shorter barrel.
- iter02: passed, but the barrel was too thin and the mines sat too deep in the hopper to be seen. Raised the hopper floor and mines, enlarged the barrel, toned the brass down.
- iter03: lengthening the barrel broke the centring check again. Shifted the barrel back by 0.045 m and lengthened the rear stub (iter04).
- iter05: hopper made less flared (closer to the concept), larger hopper ports.
- iter06: mouth lip reduced so the coral band shows from the front.

## Remaining flaws vs the concept
- Barrel is shorter and chunkier than the concept (bounds-centre check caps how far it can stick out).
- The dish sits beside the body, not in front of the muzzle, for the same reason. The translucent light cone is omitted.
- The unseen sides are invented: three stub pipes and 6 feet.
- Body is not flared as strongly at the base as the concept. No texture or baked AO (flat colour materials only).
- 10.3k triangles, above the ~5k advisory, because of the 44 mine studs (11 per mine), chamfered feet and boxes, and smooth lathed rings and ports (24-32 segments). Kept for smooth silhouettes.

## Counts
Triangles 10348, mesh objects 17 (target 16: the separate prop parts for the dish), materials 8. Size 1.50 x 1.63 x 1.61 m (x, y, height). Lowest point z = 0.

Self-score: 7/10.
