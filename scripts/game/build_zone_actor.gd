class_name BuildZoneActor
extends Node3D

## One build zone: a ground ring with an inner progress ring and a label naming what it will build.
## `BuildZoneDirector` owns the rules; this node holds the zone's state and draws it.
const TIER_COLORS: Array[Color] = [Color("58ece1"), Color("6ec6ff"), Color("c88bff"), Color("f4b942")]
const DIM_COLOR := Color("8a98a6")
## "turret" or "item", and the id of the turret type or item it will build.
var kind: String = "turret"
var asset_id: String = "normal"
var tier: int = 0
var progress: float = 0.0
## Seconds left before the zone activates (it shows dim while pending) and before it fades.
var warning_left: float = 0.0
var life_left: float = 0.0
## Seconds since the hero last stood inside; progress only decays once this passes the grace time.
var away_time: float = 0.0
var occupied: bool = false
var _outer: MeshInstance3D
var _fill: MeshInstance3D
var _label: Label3D
var _pulse: float = 0.0

func setup(zone_kind: String, zone_asset_id: String, zone_tier: int) -> void:
	kind = zone_kind
	asset_id = zone_asset_id
	tier = clampi(zone_tier, 0, GameConstants.BUILD_ZONE_MAX_TIER)
	var color := TIER_COLORS[mini(tier, TIER_COLORS.size() - 1)]
	_outer = WorldGeometry.ring(self, GameConstants.BUILD_ZONE_RADIUS, color)
	_outer.position.y = .04
	_fill = WorldGeometry.ring(self, GameConstants.BUILD_ZONE_RADIUS, color.lightened(.35))
	_fill.position.y = .05
	_fill.scale = Vector3(.001, 1.0, .001)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 40
	_label.pixel_size = .008
	_label.outline_size = 10
	_label.position.y = 1.5
	_label.text = preview_text()
	add_child(_label)
	refresh()

func is_active() -> bool:
	return warning_left <= 0.0

## "Plasma Turret ★★" — what finishing this zone builds, with one star per quality tier above the base.
func preview_text() -> String:
	var result := ArenaShop.offer_name(ShopOffer.new(kind, asset_id, 0))
	return result + (" " + "★".repeat(tier) if tier > 0 else "")

func refresh() -> void:
	if not _outer:
		return
	var active := is_active()
	_fill.visible = active and progress > 0.0
	var fill_scale := maxf(progress, .001)
	_fill.scale = Vector3(fill_scale, 1.0, fill_scale)
	_label.modulate = Color.WHITE if active else DIM_COLOR
	_label.text = preview_text() if active else "Incoming…"

func _process(delta: float) -> void:
	if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) or not _outer:
		return
	_pulse += delta * (6.0 if occupied else 2.5)
	var wobble := 1.0 + (.06 if occupied else .03) * sin(_pulse)
	_outer.scale = Vector3(wobble, 1.0, wobble)
