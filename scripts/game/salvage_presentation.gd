class_name SalvagePresentation
extends CanvasLayer

## Replays a committed settlement. Visual progress never writes XP or currency.
signal finished
const FLIGHT_END: float = 1.9
const MAX_FLIGHTS: int = 48
var world: ArenaWorld
var active: bool = false
var elapsed: float = 0.0
var reduced: bool = false
var ledger: Dictionary = {}
var root: Control
var fx: Node3D
var cards: Dictionary = {}
var packets: Array[Dictionary] = []
var heading: Label
var panel: PanelContainer
var grid: GridContainer
var skip_button: Button

func begin(record: Dictionary) -> void:
	cancel()
	ledger = record.duplicate(true)
	# Include zero-XP recipients in the roster without changing the committed settlement.
	for target: Dictionary in ledger.get("targets", []):
		var id := int(target["id"])
		var turret := _turret(id)
		if turret and not ledger["changes"].has(id):
			var snapshot := turret.progression.snapshot()
			ledger["changes"][id] = {"before": snapshot, "after": snapshot, "xp_awarded": 0}
	active = true
	elapsed = 0.0
	reduced = FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	layer = 8
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	fx = Node3D.new()
	world.add_child(fx)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL, UiPalette.TEAL, 12, 24, 18))
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	heading = _label(header, "WAVE SECURED · COLLECTING SALVAGE", 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_button = Button.new()
	ChamferStyle.style_button(skip_button)
	skip_button.text = "CONTINUE  ·  A / Space"
	skip_button.custom_minimum_size = Vector2(260, 48)
	skip_button.pressed.connect(complete)
	header.add_child(skip_button)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	root.resized.connect(_layout_report)
	grid.minimum_size_changed.connect(_layout_report.call_deferred)
	var targets: Array = ledger.get("targets", []).duplicate()
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_change: Dictionary = ledger["changes"].get(a["id"], {})
		var b_change: Dictionary = ledger["changes"].get(b["id"], {})
		var a_levels := int(a_change.get("after", {}).get("level", 0)) - int(a_change.get("before", {}).get("level", 0))
		var b_levels := int(b_change.get("after", {}).get("level", 0)) - int(b_change.get("before", {}).get("level", 0))
		return a_levels > b_levels if a_levels != b_levels else int(a["id"]) < int(b["id"]))
	for target: Dictionary in targets:
		var id: int = target["id"]
		if not ledger["changes"].has(id):
			continue
		var turret := _turret(id)
		if not turret:
			continue
		var change: Dictionary = ledger["changes"][id]
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 3)
		grid.add_child(card)
		var name_label := _label(card, "%s #%d" % [TurretRegistry.get_short_name(turret.turret_type), id], 21)
		name_label.modulate = UiPalette.TEAL_HI
		var detail := _label(card, "", 19)
		var progress := TurretXpBar.new()
		progress.custom_minimum_size.y = 14
		card.add_child(progress)
		var stats := _label(card, "", 18)
		var floating := Label3D.new()
		floating.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		floating.no_depth_test = true
		floating.font_size = 38
		floating.pixel_size = .01
		floating.position = target["position"] + Vector3(0, 1.8, 0)
		floating.visible = int(change["xp_awarded"]) > 0
		fx.add_child(floating)
		var glow: MeshInstance3D
		if not reduced:
			glow = MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = .75
			sphere.height = 1.5
			glow.mesh = sphere
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(.25, 1.0, .8, .15)
			glow.material_override = material
			glow.position = target["position"] + Vector3(0, .5, 0)
			glow.visible = false
			fx.add_child(glow)
		cards[id] = {"change": change, "bar": progress, "detail": detail, "stats": stats,
			"floating": floating, "glow": glow, "level": int(change["before"]["level"]),
			"damage": turret._current_view(1.0).damage, "range": turret.stats_view.range_metres * (turret.stats_view.area_size if TurretRegistry.get_fire_mode(turret.turret_type) == TurretRegistry.FIRE_PULSE else 1.0),
			"speed": turret.stats_view.rotation_rate if TurretRegistry.get_fire_mode(turret.turret_type) == TurretRegistry.FIRE_SWEEP else turret.stats_view.fire_rate,
			"speed_label": "Swing speed" if TurretRegistry.get_fire_mode(turret.turret_type) == TurretRegistry.FIRE_SWEEP else "Fire rate", "pulse_until": 0.0}
	_build_packets()

	advance(0.0)
	_layout_report.call_deferred()
	skip_button.grab_focus()

## Grow to fit the roster, then fit the whole report for unusually large armies.
## No scrolling, clipped cards or hidden stat gains; layout responds to window resizing.
func _layout_report() -> void:
	if not active or not is_instance_valid(panel): return
	var available := root.size - Vector2(64, 64)
	var width := minf(1560, available.x)
	grid.columns = 4 if width >= 1400 else 3 if width >= 1050 else 2
	panel.size = Vector2(width, panel.get_combined_minimum_size().y)
	var fit := minf(1.0, minf(available.x / panel.size.x, available.y / panel.size.y))
	panel.scale = Vector2.ONE * fit
	panel.position = Vector2((root.size.x - panel.size.x * fit) * .5, root.size.y - panel.size.y * fit - 32)

func _label(parent: Node, text: String, size: int) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	parent.add_child(result)
	return result

func _turret(id: int) -> TurretActor:
	for turret in world.turrets:
		if turret.turret_id == id:
			return turret
	return null

func _build_packets() -> void:
	var trail_material := ShaderMaterial.new()
	trail_material.shader = EnergyFx.ORB
	trail_material.set_shader_parameter("core_color", Color(1, .95, .65))
	trail_material.set_shader_parameter("glow_color", Color(1, .65, .12))
	var locations := {}
	for target: Dictionary in ledger.get("targets", []):
		locations[target["id"]] = target["position"] + Vector3(0, .75, 0)
	var index := 0
	for pickup: Dictionary in ledger.get("pickups", []):
		for id: int in pickup["allocations"]:
			var packet := {"id": id, "amount": int(pickup["allocations"][id]),
				"from": pickup["position"] + Vector3(0, .25, 0), "to": locations[id],
				"delay": float(index % 13) * .055, "nodes": [], "arrived": false}
			if not reduced and index < MAX_FLIGHTS:
				for tail in 3:
					var bead: Node3D
					if tail == 0:
						bead = ScrapPickup.MODEL.instantiate() as Node3D
						bead.scale = Vector3.ONE * .7
					else:
						var mote := MeshInstance3D.new()
						var mesh := SphereMesh.new()
						mesh.radius = .055 * (1.0 - tail * .2)
						mesh.height = mesh.radius * 2.0
						mesh.radial_segments = 8
						mesh.rings = 4
						mote.mesh = mesh
						mote.material_override = trail_material
						mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						bead = mote
					fx.add_child(bead)
					packet["nodes"].append(bead)
			packets.append(packet)
			index += 1

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not active:
		return
	if GameStateMachine.current_state != GameStateMachine.GameState.WAVE_END:
		cancel()
		return
	root.visible = not world.paused
	if world.paused:
		return
	elapsed += delta
	var received := {}
	for packet in packets:
		var t := clampf((elapsed - float(packet["delay"])) / 1.15, 0, 1)
		if t >= 1 and not packet["arrived"]:
			packet["arrived"] = true
			world.audio.play_cue("pickup", packet["to"])
		# XP fills on arrival, using every allocation even if its flight mesh was batched away.
		received[packet["id"]] = float(received.get(packet["id"], 0.0)) + float(packet["amount"]) * clampf((t - .7) / .3, 0, 1)
		for i in packet["nodes"].size():
			var node: Node3D = packet["nodes"][i]
			var tail := clampf(t - i * .045, 0, 1)
			node.visible = t > 0 and t < 1
			node.position = (packet["from"] as Vector3).lerp(packet["to"], tail * tail) + Vector3.UP * sin(tail * PI) * 1.4
	var gained := 0
	for id: int in cards:
		var card: Dictionary = cards[id]
		var change: Dictionary = card["change"]
		var awarded := mini(int(change["xp_awarded"]), floori(float(received.get(id, 0.0))))
		if elapsed >= FLIGHT_END:
			awarded = int(change["xp_awarded"])
		var shown := TurretProgression.new()
		shown.level = int(change["before"]["level"])
		shown.xp = int(change["before"]["xp"])
		shown.award(awarded)
		var levels := shown.level - int(change["before"]["level"])
		gained += levels
		if shown.level > int(card["level"]):
			card["level"] = shown.level
			card["pulse_until"] = elapsed + .5
			world.audio.play_cue("purchase", (card["floating"] as Label3D).position)
		var bar: TurretXpBar = card["bar"]
		bar.show_progress(shown.level, shown.xp)
		var detail: Label = card["detail"]
		detail.text = "LEVEL UP · Lv %d → %d · +%d XP" % [change["before"]["level"], shown.level, awarded] if levels > 0 else "Lv %d · +%d XP → Lv %d" % [shown.level, awarded, shown.level + 1]
		detail.modulate = UiPalette.GOOD if levels > 0 else UiPalette.INK
		var result := ""
		if levels > 0:
			var lines: Array[String] = []
			var multipliers := shown.stat_multipliers()
			for key: String in ["damage", "speed", "range"]:
				var before_mult := float(change["before"]["multipliers"][key])
				var current_mult := float(multipliers[key])
				if current_mult <= before_mult:
					continue
				var base := float(card[key]) / float(change["after"]["multipliers"][key])
				var title: String = card["speed_label"] if key == "speed" else key.capitalize()
				var format := "%.2f" if key == "speed" else "%.1f"
				var old_text := format % (base * before_mult)
				var new_text := format % (base * current_mult)
				lines.append("%s %s → %s" % [title, old_text, new_text] if old_text != new_text else "%s +%.1f%%" % [title, (current_mult / before_mult - 1.0) * 100.0])
			result = "\n".join(lines)
			for milestone in TurretProgression.EVOLUTION_LEVELS:
				if int(change["before"]["level"]) < milestone and shown.level >= milestone:
					result += ("\n" if not result.is_empty() else "") + "Lv %d milestone · form pending" % milestone
		(card["stats"] as Label).text = result
		(card["stats"] as Label).visible = not result.is_empty()
		(card["floating"] as Label3D).text = ("LEVEL UP!  Lv %d\n+%d XP" % [shown.level, awarded]) if levels > 0 else "+%d XP" % awarded
		var glow: MeshInstance3D = card["glow"]
		if glow:
			glow.visible = elapsed < float(card["pulse_until"])
			glow.scale = Vector3.ONE * (1.0 + .5 * (1.0 - maxf(0, float(card["pulse_until"]) - elapsed) / .5))
	var growth_text := "NO LEVEL-UPS" if gained == 0 else "%d LEVEL%s GAINED" % [gained, "" if gained == 1 else "S"]
	heading.text = "SALVAGE SECURED · +%d XP · %s" % [ledger.get("xp_awarded", 0), growth_text] if elapsed >= FLIGHT_END else "WAVE SECURED · COLLECTING SALVAGE"

func complete() -> void:
	if not active or world.paused:
		return
	cancel()
	finished.emit()

func cancel() -> void:
	active = false
	if is_instance_valid(root):
		root.visible = false
		root.queue_free()
	if is_instance_valid(fx):
		fx.visible = false
		fx.queue_free()
	root = null
	fx = null
	cards.clear()
	packets.clear()
	ledger = {}

func _exit_tree() -> void:
	cancel()
