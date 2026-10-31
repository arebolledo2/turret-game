# cp_shock_dome3-v1 - Glass Dome Shock Turret, engine visibility pass

Continuation of `cp_shock_dome2-v1` (same glass-dome shock turret: brass ring + graphite saucer/feet + ivory disc + coral spring +
amber gem + teal dome with coral cap disc and gold finial). Script `build_cp_shock_dome3.py` -> `cp_shock_dome3.glb`
(+ the four atlas PNGs in `textures/`). This pass changes how the model reads in the Godot game (Filmic tonemap, glow threshold 1.0,
high camera 50-60 degrees, ~60 px tall), not the concept itself.

## Result
- Harness iterations used: **4 of 8**. The contract passed on every iteration (no failed checks); iter04 is the delivered build.
  Only advisory overrun: triangles 29,549 > 20,000 (intentional, quality first, no tessellation was cut).
- Final counts: **29,549 triangles, 18 mesh objects, 7 materials** (same 7 as v2), empties `TurretModel > Aim > Muzzle`
  (Muzzle is a bare empty, 0.20 m forward of the vertical axis at the gem height, forward = +Y).
- Size 0.72 x 0.736 x **1.240 m** (limit 1.25), lowest point z = 0.000.
- Textures: **4 images, all 1024 x 1024, embedded in the GLB** (2.1 MB): albedo(+alpha), ORM (AO / roughness / metallic), normal,
  emissive. One shared atlas, every mesh UV-mapped into its own region (shelf-packed small regions, 92 % of the atlas used).
  Emissive values > 1 are exported with `KHR_materials_emissive_strength` (core 3.6, flecks 3.6, shell 2.0, glow 2.5).

## What I changed for each of the four in-engine findings
**1. Glass jar nearly invisible, dome looked like it floated**
- Glass alpha raised from ~0.05-0.25 to ~0.41 per surface (0.35 around the gem so it stays vivid). Two culled surfaces are seen
  from outside (front outer + back inner), so a looking-through ray over empty jar sees about 65 % opacity.
- Thick, distinctly brighter pale-aqua rim bands baked into albedo + alpha: ~7 cm at the bottom and ~9 cm at the top (alpha up
  to ~0.85, near white-aqua), plus a crisp bright line just inside each collar and brighter vertical reflection streaks.
- Two new SOLID collars (new meshes): **Base_Collar** (ivory ceramic, static, jar meets the brass ring) and **Jar_Collar**
  (polished brass band wrapped around the dome lip, under Aim). The dome now sits on a brass band that sits on glass that stands
  in an ivory collar on the ring: the chain of supports is visible at every distance.
- Jar, dome, collars and cap disc raised to 64 radial segments (the big silhouettes).

**2. Crystal hidden under the cap, glow barely visible, nothing read at 60 px**
- Gem 1.4x bigger (shell r 0.115 -> 0.161, core r 0.080 -> 0.112); 72-facet shell (66 survive the hull) and 24-facet core so it is
  rounder; flecks, halo cards and sparks scaled with it.
- Jar made 0.195 m taller (top 0.835 -> 1.03) and the dome flatter (crown 0.160 -> 0.115) with a smaller finial, so the cap's front
  rim is 0.21 m higher (0.775 -> 0.987) while the whole model is still 1.24 m.
- Emission: core 3.6, flecks 3.6, shell 2.0, glow 2.5 (v2: 1.7 / 1.7 / 0.9 / 1.0), all far above the glow threshold; white-hot
  core facets over saturated amber; sparks are the brightest pixels (bloom stars). Halo is now a corona (faint over the gem, peak
  just outside its rim) so the stacked cards do not wash the facets out.
- Value contrast at 60 px: bright gem + pale glass bands + cream collar/disc against dark graphite and the saturated coral spring;
  warm baked light spill (emissive map, linear < 1 so no bloom) on the spring (stronger towards the top) and as a warm pool on the
  ivory disc around the spring base, so the lamp still reads where the opaque cap hides the gem itself. Spring is wider (0.112,
  concept: nearly as wide as the gem), 14-sided and thicker so it survives distance; the ivory disc was lowered 2.5 cm (top level
  with the ring) to give it room (2.65 turns).
- **Deliberate deviation from the brief ("raise the gem to the upper third")**: with an opaque cap and a camera 50-60 degrees
  above, anything whose screen position is above the cap's front rim is hidden, so a HIGHER gem is hidden MORE. I computed the
  visible share of the gem's diameter for a ray over the cap rim (front rim at s = 0.3175, z = 0.987; gem r 0.166):

  | camera elevation | v2 (gem z 0.61, rim z 0.775) | v3 as built (gem z 0.50) | v3 with gem raised to 0.61 | gem at upper third (0.75) |
  |---|---|---|---|---|
  | 50 deg | 0 % | 71 % | 50 % | 23 % |
  | 55 deg | 0 % | 56 % | 37 % | 13 % |
  | 60 deg | 0 % | 40 % | 24 % | 3 % |

  So the fix is the taller jar + flatter cap + bigger gem, with the gem kept in the lower-middle of the window (centre z 0.50,
  top of gem 0.67) and the spring below it stays visible. A private
  perspective render at 55 degrees with the real materials confirmed roughly the lower half of the gem and its bloom show under the
  cap. If a later pass wants the gem higher, the cap has to become see-through or smaller than the jar.

**3. Brass rendered dark olive instead of bright gold**
- Metallic 0.90 -> 0.68 (studs/finial 0.70, crevices slightly lower), roughness 0.27 -> ~0.38 (polished worn edges ~0.18, brushed
  flats ~0.38, crevices duller), so the teal sky is a minor part of the colour instead of the whole of it.
- Warm albedo ramp, shifted from lemon towards orange-gold (deep orange-brown shadows, (1.0, 0.65, 0.13) mid, (1.0, 0.91, 0.48)
  highlights) plus a small baked self-light (linear ~(0.3, 0.12, 0.01) x AO, far below the glow threshold) in the emissive map so
  even in shade the red channel dominates. The same trick (neutral warm, ~0.2) keeps the ivory cream instead of grey-green.
- In my teal-ambient test rig the brass ring median measured hue ~47 degrees (gold), not olive.

**4. Teal enamel too saturated / cyan**
- New ramp centred on **#2aa89a** (0.165, 0.659, 0.604): shadows (0.06, 0.38, 0.34) and highlights (0.33, 0.80, 0.73), top of
  the crown ~#2aa89a, skirt a deeper #239a8a; reflection overlays and lip highlights toned down (max 0.5, was 0.62). The same
  teal was used for the tinted glass at lower brightness. Test-rig median on the crown measured #319990 (hue 175 degrees).

## Judging it (important caveat)
I could not run Godot. I judged the engine look with private renders (not harness runs; scripts kept in the scratchpad, not in
this folder): a perspective camera at 50 / 55 / 60 degrees, a teal sky ambient, one warm sun, a dark floor, a Filmic
(Uncharted-style, white 6.0) tonemap and a crude threshold-1.0 multi-level glow applied to the linear render, viewed at about
60 px height. The checker (AgX, three suns, no bloom) renders the gem pale cream and the glass milky, and that is expected;
in the Godot-like rendering the gem is saturated amber with white-hot facets, an orange bloom and a copper-coral spring.

## What failed / how I fixed it
- First build (gem centre z 0.60, spring 4 turns): in the 55 degree test render only the very tip of the gem was visible (about
  a third of the diameter, mostly hidden by the cap), so I lowered the gem to 0.50 and moved the cap rim up (thin collar, flatter
  crown); first 50 degree test already showed a recognisable gem on a spring.
- That left a stubby 2-turn spring that disappeared behind the thick rim band in the front view: thinned the bottom band
  (10 cm -> 7 cm), lowered the ivory disc 2.5 cm and widened the spring, giving 2.65 turns with visible gaps.
- Ivory base collar and disc rendered tan then grey-green in shade (same mechanism as the olive brass): cream ramp + small
  baked self-light.
- Spring read as dusty pink-brown in the dome's shadow: more saturated coral ramp for the coil only (the cap disc keeps the
  concept's softer salmon) and a baked warm spill.
- Glints: first version scattered too many in the empty upper jar (confetti); trimmed.

## Remaining flaws / limitations vs the concept and the brief
- At 60 degrees only about 40 % of the gem's diameter shows under the cap (71 % at 50 degrees); the rest of the lamp read at
  that angle comes from bloom, the halo/glints, the light pool and the lit spring. Raising the gem as the brief suggested is
  not possible without making the cap see-through (see table).
- Gem is a ~66-facet polyhedron, not the concept's perfectly round sparkly sphere; its silhouette is faintly polygonal in close-ups.
- The model is taller and straighter than the concept (1.24 x 0.72 m, ratio 1.7 vs ~1.6), the dome is a low lid rather than a
  tall bullet, and the spring has 2.65 turns instead of ~5, all consequences of the taller jar and the lower gem.
- Alpha-blended parts (jar, shell, glow) are depth sorted per object in the engine; jar front wall and gem share nearly the same
  AABB centre, so which draws first can change with the camera. Either order is acceptable (the gem is merely tinted by the
  front wall, or not) but it is not perfect.
- Brass/ivory/coral rely on a small baked self-light to resist the teal environment; in a very differently lit scene they will
  look slightly flat (self-light is < 0.3 linear, so no bloom). The glass reads milky/foggy in the checker.
- Tessellation was not cut: 29.5k triangles (coil 5.3k, dome 4.4k, collars 4.0k together, ring 2.5k, feet/caps 3.7k, disc 2.0k,
  jar 2.2k, rest < 1.4k each; the whole gem incl. flecks and glow is 0.7k). Several of the rings (collars, studs, feet) are
  probably denser than 60 px play needs.
- Atlas gutter is 3 px; far mips can bleed slightly.

## Self-score: 7 / 10
Contract clean, all four findings addressed with measured/derived reasoning and a private Godot-like check, but the gem is still
only about half visible from the high camera, the spring is short, and I could not verify in the real engine.
