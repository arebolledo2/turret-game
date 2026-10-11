# Clockwork Bowling Ball Projectile

Final candidate: `cp_bowling_ball.glb`; frozen iteration: **1**.

- Harness iterations used: **1 / 8**. Contract passed on the first build; no advisory targets exceeded.
- Final imported metrics: **4,788 triangles / 1 mesh object / 3 materials**. Exact bounds: **0.48 x 0.48 x 0.48 m**, bottom **z = -0.24 m**, origin **(0, 0, 0)**.
- Smooth centered sphere, three real blind bores with lightly rounded lips, and one narrow brass equatorial inlay flush to the spherical surface. No turret, ramp, pivots, skeleton, animation, or external assets.
- One script-generated **512 x 512** seamless plum resin colour texture, packed in the Blender file and embedded in GLB. Blue-black polished resin remains dominant; gentle warm-plum clouds supply restrained colour variation.
- Finger-hole floors are approximately **0.065 m** below the original spherical surface. The separate `audit_final.py` checks these depths by ray casting and checks source topology and origin.
- The GLB import validator reports 89 loose components because exported vertices split at material boundaries, UV seams, and boolean/cap normal discontinuities. The actual source is one connected surface, independently audited. One object carries the whole rigid projectile.
- Visual comparison: the source concept includes the launcher and shows only two holes clearly. This standalone interpretation exposes all three holes as requested. Its brass line is intentionally added for rotation readability, as requested. Fine plum variation is subtle in the bright neutral checker; real soft studio reflections would make the polish richer. The underside/back are sensibly completed as smooth resin with the continuing inlay.
- No failed harness checks. No changes to game resources; Godot integration belongs to the parent task.
- Honest self-score: **8.5 / 10**. Clean silhouette, correct scale/pivot, recognizable bowling grip and restrained materials. Tiny bore facets are visible only in close-up; no dense decorative details were added.

Frozen copies: `cp_bowling_ball_iter01.glb` and `build_cp_bowling_ball_iter01.py`. See `builder_metrics.json`, `final_audit.json`, and `renders/iter01/validate.json` for measured details.
