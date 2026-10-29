class_name TurretForms
extends RefCounted

## The form table: one row per evolution form, and the only place a form's facts are written down.
## `TurretEvolution` reads these rows (options, names, models, descriptions, stats, shot shapes, which forms are built),
## `TurretForm.create` takes the behaviour from the row and `TurretActor` takes the visual builder from it. Nothing else
## lists forms: the order of the rows is the order of the paths (an upgrade row, then its two final rows, per base).
##
## ## Row keys
## Required:
##   base         the base turret id (`TurretRegistry.TYPES`) that owns the form
##   kind         `UPGRADE` (taken at level 5, no choice) or `FINAL` (level 10, pick one of two)
##   name         player-facing name
##   model        the authored chassis (`ClockworkModels.KEYS`); several forms may share one
##   description  player-facing text; numbers typed into it must match `stats` and `params`
##   stats        overrides applied on top of `TurretRegistry.get_base_stats(base)` (damage, fire_rate, range, pierce, ...)
##   implemented  true once the form has a working attack and its art; false rows are registered but gated off in the shop
## Optional:
##   behaviour    class name of the `TurretForm` subclass that runs the attack (omit when `TurretActor`'s default attack is right)
##   visual       class name of the `*EvolutionVisual` whose `static func build(model, form_id)` adds this form's hardware to the
##                chassis (names, not class references: this table is read by the very classes it names, and GDScript cannot
##                compile a cycle of constants; `TurretEvolution` resolves the names when it needs them)
##   shot         `CombatShot3D` fields set after the shot is built (visual_key, radius, lifetime, ricochets); a
##                `visual_scale` also scales the radius
##   params       numbers the behaviour or visual reads through `TurretEvolution.param(form_id, key, default)`:
##                  volley      arrows loosed per draw (Repeater Bow, Arrowstorm)
##                  blades      held blades (Orbit Saber)
##                  spool       Gatling rotor spool ceiling
##                  barrel      stats of the Stormblade's rotating barrel; barrel_burst its rounds per burst
##                  echo_delays seconds after a Resonator pulse that each echo lands; alternating_rings the Engine's ring pairs
##                  slam_every, slam_damage, slam_radius, slam_stagger  Pile Driver's slam: every Nth pulse, its damage and radius
##                              multipliers and its stagger seconds
##                  ranged_taunt, hooks, hook_share  Maelstrom: the taunt also draws ranged enemies, the most hooks it holds
##                              at once, and the damage of a hook tick as a share of the pulse damage
##                  deposit_share, interest_per, interest_cap  Scrap Press: the share of each drop sent straight to the wallet,
##                              and the Treasury's wave-end interest (one scrap per `interest_per` held, at most `interest_cap`)
##                  xp_radius   Academy: metres around the press whose turrets gain each drop's value as XP
##                  layers, burner_pairs, burner_fan, lance_segments, braces, bumpers, housing_pairs, barrel_bands
##                              hardware counts and angles for the visual builders
## `BASES` holds the same kind of facts for a base turret that has not evolved yet (and for what all its forms share).
##
## ## Adding a turret (the touch-points that remain)
## 1. `TurretRegistry`: a `TYPES` entry (stats, fire mode, model), a `BASE_PRICES` price and a `FAMILIES` family.
## 2. `ShopCatalog.DEFAULT_ENTRIES`: append the id (never insert; seeded shop rolls follow catalog order).
## 3. Here: three rows (upgrade, final, final) in path order. Set `implemented` to false until the art and attack exist.
## 4. If the attack is new: a `<line>_form.gd` subclass of `TurretForm` (and a new `FIRE_*` branch in `TurretActor` only
##    when the attack shape itself is new). Point the rows' `behaviour` at it.
## 5. If the chassis needs hardware: a `<line>_evolution_visual.gd` with `static func build(model, form_id)`. Point `visual` at it.
## 6. Art: the chassis `.glb` in `assets/models/clockwork/` and its key in `ClockworkModels.KEYS` plus the manifest, the
##    portraits `assets/ui/turrets/<id>.png` for the base and each form, and the `turret_<id>` icon in `UiIconData`.
## 7. Docs and tools that list turrets by hand: `doc/index.md` counts, the bench, showcase and preview tools, and a
##    per-turret integration test. No test count needs editing: the roster contract tests derive from these rows.
## Which forms exist, which are built, which model a form uses and what a path offers are all answered from the rows, so
## there is no list of forms to keep in step.

const UPGRADE: String = "upgrade"
const FINAL: String = "final"

## Stat values the rows share with the code that reads them back (`TurretEvolution` re-exports them). They live here
## because the table is evaluated first: it must not depend on `TurretEvolution`, which depends on it.
const SNIPER_PIERCER_PIERCE: int = 2
const SNIPER_UNLIMITED_PIERCE: int = 99
const CATACLYSM_STAGGER: float = 1.0

## What an unevolved base turret (and every form of it) shares.
const BASES: Dictionary = {
	"bow": {"shot": {"visual_key": "arrow"}},
	"bowling": {"shot": {"visual_key": "bowling_ball", "radius": .24, "lifetime": 4.0}},
	# The unevolved Quake stomps through the same behaviour as its forms.
	"quake": {"behaviour": "QuakeForm"},
	"melee": {"behaviour": "SweepForm"},
	# The unevolved Decoy already taunts and pulses through the same behaviour as its forms.
	"decoy": {"behaviour": "DecoyForm"},
	# The unevolved Scrap Press already makes its drops through the same behaviour as its forms.
	"scrap_press": {"behaviour": "ScrapPressForm"},
}

const FORMS: Dictionary = {
	# --- Ion ---
	"machine_gun": {
		"base": "normal", "kind": UPGRADE, "name": "Machine Gun", "model": "machine_gun", "implemented": true,
		"description": "Rapid aimed fire.",
		"stats": {"damage": 6.5, "fire_rate": 3.2, "projectile_speed": 1000.0, "pierce": 0},
		"behaviour": "MachineGunForm",
	},
	"cyclone_gatling": {
		"base": "normal", "kind": FINAL, "name": "Cyclone Gatling", "model": "gatling", "implemented": true,
		"description": "Piercing rotary fire accelerates to 2.5 times its resting rate.",
		"stats": {"damage": 6.5, "fire_rate": 4.8, "projectile_speed": 1000.0, "pierce": 1},
		"behaviour": "MachineGunForm", "visual": "GatlingEvolutionVisual",
		"params": {"spool": 1.5},
	},
	"omnifire": {
		"base": "normal", "kind": FINAL, "name": "Omnifire", "model": "crossfire", "implemented": true,
		"description": "Twelve shots cover a full circle in evenly spaced directions.",
		"stats": {"damage": 10.0, "fire_rate": 1.25, "range": 220.0},
		"behaviour": "ScatterForm", "visual": "CrossfireEvolutionVisual",
	},
	# --- Melee ---
	"saber": {
		"base": "melee", "kind": UPGRADE, "name": "Saber", "model": "saber", "implemented": true,
		"description": "A longer, faster energy-blade sweep.",
		"stats": {"damage": 11.0, "rotation_rate": 420.0, "range": 145.0},
		"behaviour": "SweepForm",
	},
	"orbit_saber": {
		"base": "melee", "kind": FINAL, "name": "Orbit Saber", "model": "saber", "implemented": true,
		"description": "Three held energy blades sweep evenly around the turret.",
		"stats": {"damage": 14.0, "rotation_rate": 480.0, "range": 170.0},
		"behaviour": "SweepForm",
		"params": {"blades": 3},
	},
	"stormblade": {
		"base": "melee", "kind": FINAL, "name": "Stormblade", "model": "gunblade", "implemented": true,
		"description": "Three-shot piercing bursts accompany a longer, faster blade sweep.",
		"stats": {"damage": 12.0, "rotation_rate": 360.0, "range": 170.0},
		"behaviour": "GunbladeForm", "visual": "GunbladeEvolutionVisual",
		"params": {"barrel": {"damage": 9.0, "fire_rate": 2.4, "range": 300.0, "pierce": 1}, "barrel_burst": 3},
	},
	# --- Bow ---
	"repeater_bow": {
		"base": "bow", "kind": UPGRADE, "name": "Repeater Bow", "model": "bow", "implemented": true,
		"description": "Fires a quick burst of 2 piercing arrows.",
		"stats": {"damage": 12.0, "fire_rate": .9, "projectile_speed": 1050.0, "pierce": 1},
		"behaviour": "RepeaterBowForm", "visual": "BowEvolutionVisual",
		"params": {"volley": 2},
	},
	"arrowstorm": {
		"base": "bow", "kind": FINAL, "name": "Arrowstorm", "model": "bow", "implemented": true,
		"description": "Fires a quick burst of 5 piercing arrows.",
		"stats": {"damage": 14.0, "fire_rate": 1.1, "projectile_speed": 1050.0, "pierce": 2},
		"behaviour": "RepeaterBowForm", "visual": "BowEvolutionVisual",
		"params": {"volley": 5},
	},
	"titan_bow": {
		"base": "bow", "kind": FINAL, "name": "Titan Bow", "model": "bow", "implemented": true,
		"description": "Heavy arrows pierce 9 enemies and knock them back.",
		"stats": {"damage": 66.0, "fire_rate": .8, "range": 470.0, "projectile_speed": 1100.0, "pierce": 8, "knockback_force": 240.0},
		"visual": "BowEvolutionVisual",
		"shot": {"visual_scale": 1.9},
		"params": {"layers": 3},
	},
	# --- Flamethrower ---
	"wide_flame": {
		"base": "flamethrower", "kind": UPGRADE, "name": "Wide Flame", "model": "flamethrower", "implemented": true,
		"description": "A 60-degree fan blankets a crowd and leaves enemies burning.",
		"stats": {"damage": 3.2, "cone_degrees": 60.0, "burn_duration": 2.2},
		"visual": "FlameEvolutionVisual",
		"params": {"burner_pairs": 1, "burner_fan": 22.0},
	},
	"inferno_crown": {
		"base": "flamethrower", "kind": FINAL, "name": "Inferno Crown", "model": "flamethrower", "implemented": true,
		"description": "A 110-degree fan blankets a crowd and leaves enemies burning.",
		"stats": {"damage": 5.0, "cone_degrees": 110.0, "burn_duration": 3.0},
		"visual": "FlameEvolutionVisual",
		"params": {"burner_pairs": 3, "burner_fan": 47.0},
	},
	"dragonheart": {
		"base": "flamethrower", "kind": FINAL, "name": "Dragonheart", "model": "flamethrower", "implemented": true,
		"description": "A longer, narrower jet delivers a stronger, longer-lasting burn.",
		"stats": {"damage": 5.0, "range": 380.0, "cone_degrees": 16.0, "burn_ratio": 3.0, "burn_duration": 3.5},
		"visual": "FlameEvolutionVisual",
		"params": {"lance_segments": 3},
	},
	# --- Bowling ---
	"heavy_roller": {
		"base": "bowling", "kind": UPGRADE, "name": "Heavy Roller", "model": "bowling", "implemented": true,
		"description": "Larger balls drive through crowds with stronger knockback.",
		"stats": {"damage": 30.0, "pierce": 7, "knockback_force": 330.0, "fire_rate": .6},
		"visual": "BowlingEvolutionVisual",
		"shot": {"visual_scale": 1.25},
		"params": {"braces": 1},
	},
	"juggernaut": {
		"base": "bowling", "kind": FINAL, "name": "Juggernaut", "model": "bowling", "implemented": true,
		"description": "Larger balls drive through crowds with stronger knockback.",
		"stats": {"damage": 60.0, "pierce": 14, "knockback_force": 520.0, "fire_rate": .7},
		"visual": "BowlingEvolutionVisual",
		"shot": {"visual_scale": 1.75},
		"params": {"braces": 3},
	},
	"ricochet_king": {
		"base": "bowling", "kind": FINAL, "name": "Ricochet King", "model": "bowling", "implemented": true,
		"description": "Redirects toward a fresh nearby enemy up to 6 times.",
		"stats": {"damage": 36.0, "fire_rate": .9, "projectile_speed": 400.0, "pierce": 0},
		"visual": "BowlingEvolutionVisual",
		"shot": {"ricochets": 6, "lifetime": 6.0},
		"params": {"bumpers": 3},
	},
	# --- Plasma ---
	"siege": {
		"base": "plasma", "kind": UPGRADE, "name": "Siege Cannon", "model": "siege", "implemented": true,
		"description": "Slow, heavy shells explode over a large area and push enemies back.",
		"stats": {"damage": 42.0, "fire_rate": .45, "range": 330.0, "projectile_speed": 350.0, "aoe_radius": 135.0, "knockback_force": 220.0},
		"visual": "SiegeEvolutionVisual",
		"shot": {"radius": .22},
	},
	"worldbreaker": {
		"base": "plasma", "kind": FINAL, "name": "Worldbreaker", "model": "siege", "implemented": true,
		"description": "Slow, heavy shells explode over a large area and push enemies back.",
		"stats": {"damage": 80.0, "fire_rate": .55, "range": 330.0, "projectile_speed": 350.0, "aoe_radius": 185.0, "knockback_force": 360.0},
		"visual": "SiegeEvolutionVisual",
		"shot": {"radius": .34},
		"params": {"housing_pairs": 2, "barrel_bands": 3},
	},
	"constellation": {
		"base": "plasma", "kind": FINAL, "name": "Constellation", "model": "siege", "implemented": false,
		"description": "",
		"stats": {},
	},
	# --- Shock ---
	"resonator": {
		"base": "shock", "kind": UPGRADE, "name": "Resonator", "model": "resonator", "implemented": true,
		"description": "Each pulse echoes once half a second later at half damage, refreshing the slow.",
		"stats": {"damage": 5.0, "range": 240.0},
		"behaviour": "ResonatorForm",
		"params": {"echo_delays": [.5]},
	},
	"resonance_engine": {
		"base": "shock", "kind": FINAL, "name": "Resonance Engine", "model": "resonance_engine", "implemented": true,
		"description": "Pulses alternate a tight, hard inner ring and a wide outer ring; enemies caught by both are Exposed, taking 30% more from Instant turrets.",
		"stats": {"damage": 5.0, "range": 276.0},
		"behaviour": "ResonatorForm",
		"params": {"echo_delays": [.4, .8], "alternating_rings": true},
	},
	"thunder_spear": {
		"base": "shock", "kind": FINAL, "name": "Thunder Spear", "model": "thunder_spear", "implemented": true,
		"description": "The bolt drives through a whole lane of enemies and pins every one.",
		"stats": {"damage": 48.0, "fire_rate": .85, "range": 400.0, "slow_intensity": .9, "slow_duration": 2.0},
		"behaviour": "LanceForm",
	},
	# --- Tesla (registered, not built yet) ---
	"forked_coil": {
		"base": "tesla", "kind": UPGRADE, "name": "Forked Coil", "model": "tesla", "implemented": false,
		"description": "",
		"stats": {},
	},
	"storm_network": {
		"base": "tesla", "kind": FINAL, "name": "Storm Network", "model": "storm_network", "implemented": false,
		"description": "",
		"stats": {},
	},
	"thunderhead": {
		"base": "tesla", "kind": FINAL, "name": "Thunderhead", "model": "thunderhead", "implemented": false,
		"description": "",
		"stats": {},
	},
	# --- Sniper ---
	# Single-target DPS (before level and item bonuses) is 14 base, 20.8 Piercer Rifle, 31.5 Horizon Piercer, 23.5 Overwatch.
	# Overwatch's own shots land on a Marked target, so against its first target it deals 1.25 times that.
	# All three forms share the cp_sniper chassis; `SniperEvolutionVisual` adds the per-form hardware.
	"piercer_rifle": {
		"base": "sniper", "kind": UPGRADE, "name": "Piercer Rifle", "model": "sniper", "implemented": true,
		"description": "A longer barrel and heavier rounds. The shot passes through two enemies behind its target.",
		"stats": {"damage": 52.0, "fire_rate": .40, "range": 760.0, "pierce": SNIPER_PIERCER_PIERCE},
		"visual": "SniperEvolutionVisual",
	},
	"horizon_piercer": {
		"base": "sniper", "kind": FINAL, "name": "Horizon Piercer", "model": "sniper", "implemented": true,
		"description": "The shot runs the whole line to full range and strikes every enemy on it. Aim the toughest enemy through the crowd.",
		"stats": {"damage": 70.0, "fire_rate": .45, "range": 820.0, "pierce": SNIPER_UNLIMITED_PIERCE},
		"visual": "SniperEvolutionVisual",
	},
	"overwatch": {
		"base": "sniper", "kind": FINAL, "name": "Overwatch", "model": "sniper", "implemented": true,
		"description": "Keeps the Piercer shot and marks the three toughest enemies in range for 6 seconds. Marked enemies take 25% more damage from every turret, and the mark jumps to the next toughest enemy when one dies.",
		"stats": {"damage": 56.0, "fire_rate": .42, "range": 780.0, "pierce": SNIPER_PIERCER_PIERCE},
		"behaviour": "OverwatchForm", "visual": "SniperEvolutionVisual",
	},
	# --- Quake ---
	# Per enemy struck and before level and item bonuses; a pulse's damage is dealt once to every enemy in the ring. Per-cycle
	# damage (a cycle runs from one trigger to the next, rate 0.45 means 2.22 s): base 16 x 1 = 16 at 0.45/s = 7.2 DPS;
	# Aftershock 18 + 9 = 27 (12.2 DPS); Cataclysm 4 pulses of 30 = 120 per 3.2 s salvo plus a 2 s recharge (23 DPS, measured
	# about 1.5x Aftershock in a cluster the rings reach). Tectonic hits what stands in its X (see `TurretEvolution.TECTONIC_*`),
	# tuned to about 1.4x Aftershock on a cluster and more on a single target; its value is the 3 s rift.
	# All forms share the cp_quake chassis (cube on a stone slab); `QuakeEvolutionVisual` adds the per-form hardware.
	"aftershock": {
		"base": "quake", "kind": UPGRADE, "name": "Aftershock", "model": "quake", "implemented": true,
		"description": "A second pulse follows 0.6 seconds after the first at half damage and the same radius.",
		"stats": {"damage": 18.0, "fire_rate": .45, "range": 270.0, "knockback_force": 200.0},
		"behaviour": "QuakeForm", "visual": "QuakeEvolutionVisual",
	},
	"tectonic": {
		"base": "quake", "kind": FINAL, "name": "Tectonic", "model": "quake", "implemented": true,
		"description": "Splits the ground into two crossing fissures at the densest cluster. Enemies in them are hit when they open, then slowed 40% for 3 seconds.",
		"stats": {"damage": 40.0, "fire_rate": .5, "range": 400.0, "knockback_force": 150.0},
		"behaviour": "QuakeForm", "visual": "QuakeEvolutionVisual",
	},
	"cataclysm": {
		"base": "quake", "kind": FINAL, "name": "Cataclysm", "model": "quake", "implemented": true,
		"description": "The pulse repeats every 0.9 seconds while enemies stay in range, each ring wider than the last (3 repeats at most). Stagger builds up on every hit, up to 1.5 seconds.",
		# The stagger outlasts the 0.9 s gap between repeats, so each pulse lands on an enemy that is still down and the stack builds.
		"stats": {"damage": 30.0, "fire_rate": .5, "range": 280.0, "knockback_force": 220.0, "stagger": CATACLYSM_STAGGER},
		"behaviour": "QuakeForm", "visual": "QuakeEvolutionVisual",
	},
	# --- Decoy ---
	# The pulse hits every enemy in reach once, so the numbers are per enemy (before level and item bonuses). Taunt radius is
	# `taunt_range` (base 450 = 4.5 m). All forms use the real cp_decoy chassis (key `decoy`);
	# `DecoyEvolutionVisual` adds the per-form hardware.
	"bumper_post": {
		"base": "decoy", "kind": UPGRADE, "name": "Bumper Post", "model": "decoy", "implemented": true,
		"description": "Padded bumper posts hit harder and faster: 8 damage every 1.2 seconds, and enemies are shoved back half again as far.",
		"stats": {"damage": 8.0, "fire_rate": 1.0 / 1.2, "range": 150.0, "knockback_force": 225.0},
		"behaviour": "DecoyForm", "visual": "DecoyEvolutionVisual",
	},
	"pile_driver": {
		"base": "decoy", "kind": FINAL, "name": "Pile Driver", "model": "decoy", "implemented": true,
		"description": "Every fourth pulse is a slam: triple damage over a ring half again as wide, and the enemies it hits are staggered for 0.6 seconds.",
		"stats": {"damage": 8.0, "fire_rate": 1.0 / 1.2, "range": 180.0, "knockback_force": 225.0},
		"behaviour": "DecoyForm", "visual": "DecoyEvolutionVisual",
		"params": {"slam_every": 4, "slam_damage": 3.0, "slam_radius": 1.5, "slam_stagger": .6},
	},
	"maelstrom": {
		"base": "decoy", "kind": FINAL, "name": "Maelstrom", "model": "decoy", "implemented": true,
		"description": "The taunt reaches 7 metres and draws ranged enemies too. Up to 10 enemies in reach are hooked and circle the Decoy until they die, taking a light tick of damage.",
		"stats": {"damage": 7.5, "fire_rate": 1.0, "range": 150.0, "knockback_force": 120.0, "taunt_range": 700.0},
		"behaviour": "DecoyForm", "visual": "DecoyEvolutionVisual",
		"params": {"ranged_taunt": true, "hooks": 10, "hook_share": .25},
	},
	# --- Scrap Press ---
	# No attack: `fire_rate` is drops per second (0.25 = one every 4 s) and `range` how far from the press a drop lands (150 =
	# 1.5 m). Each drop is worth `ScrapIncome.drop_value(wave)` scrap. A second press keeps 60% of its output, a third 40%.
	# The forms change where the drop goes, not how big it is, except Treasury (+25% output) and Academy (half the output, but
	# every turret in reach gets the whole drop as XP). The real cp_scrap_press chassis (key `scrap_press`);
	# `ScrapPressEvolutionVisual` adds the per-form hardware.
	"coin_feeder": {
		"base": "scrap_press", "kind": UPGRADE, "name": "Coin Feeder", "model": "scrap_press", "implemented": true,
		"description": "A hopper feeds half of every drop straight into your wallet, with no pickup trip. The other half still lands beside the press.",
		"stats": {"damage": 0.0, "fire_rate": .25, "range": 150.0},
		"behaviour": "ScrapPressForm", "visual": "ScrapPressEvolutionVisual",
		"params": {"deposit_share": .5},
	},
	"treasury": {
		"base": "scrap_press", "kind": FINAL, "name": "Treasury", "model": "scrap_press", "implemented": true,
		"description": "Every drop goes straight into your wallet, and the press makes 25% more. When a wave is won it pays interest: 1 scrap per 10 you hold, up to 5.",
		"stats": {"damage": 0.0, "fire_rate": .3125, "range": 150.0},
		"behaviour": "ScrapPressForm", "visual": "ScrapPressEvolutionVisual",
		"params": {"deposit_share": 1.0, "interest_per": 10, "interest_cap": 5},
	},
	"academy": {
		"base": "scrap_press", "kind": FINAL, "name": "Academy", "model": "scrap_press", "implemented": true,
		"description": "Makes no scrap. Every 8 seconds each turret within 6 metres gains XP equal to a drop, in full, and no cash is paid.",
		"stats": {"damage": 0.0, "fire_rate": .125, "range": 150.0},
		"behaviour": "ScrapPressForm", "visual": "ScrapPressEvolutionVisual",
		"params": {"xp_radius": 6.0},
	},
}
