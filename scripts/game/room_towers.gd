class_name RoomTowers
extends RefCounted

## The stepped corner towers of the room (see `ArenaRoom`): lanterns, vents and cupolas.
## Builds into the room's shared `RoomMeshKit` and materials; `ArenaRoom.build` creates one of these per part after the materials exist.
var room: ArenaRoom
var _kit: RoomMeshKit
var _hull: ShaderMaterial
var _brass: ShaderMaterial
var _frame: StandardMaterial3D
var _paint: StandardMaterial3D
var _lamp: StandardMaterial3D
var _enamel: StandardMaterial3D
var _glow: StandardMaterial3D

func _init(owner: ArenaRoom) -> void:
	room = owner
	_kit = owner._kit
	_hull = owner.hull
	_brass = owner._brass
	_frame = owner._frame
	_paint = owner._paint
	_lamp = owner._lamp
	_enamel = owner._enamel
	_glow = owner._glow

func build(inner: Vector2) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * (inner.x + ArenaRoom.SIDE_DEPTH * 0.5)
		_tower(Vector3(ArenaRoom.SIDE_DEPTH, ArenaRoom.BACK_TOWER_HEIGHT, 1.5), Vector2(x, -inner.y - 0.15), side, ArenaRoom.BACK_CROWN, true)
		_tower(Vector3(ArenaRoom.SIDE_DEPTH, ArenaRoom.FRONT_TOWER_HEIGHT, 1.05), Vector2(x, inner.y - 0.075), side, ArenaRoom.FRONT_CROWN, false)

## A stepped column with a cupola. The box body (with a brass band, frieze, cornice and two lid steps) still hides the joins
## between walls of different heights; on the lid sit an enamel inset, an octagonal drum with lit slits, a brass ring, a domed cap
## with a beacon finial and a pinnacle at each corner, so from above it reads as a turret, not a lid. The south face (the one the
## camera sees) carries posts, a lantern, vents and an enamel stripe. `size.y` is the total height, `crown` how much of it is cupola.
func _tower(size: Vector3, centre: Vector2, side: float, crown: float, is_back: bool) -> void:
	var lid := size.y - 0.004 - crown # the top of the lid steps; nothing rises above `size.y`
	var body := lid - 0.3
	var cx := centre.x
	var cz := centre.y
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	_kit.add_box(_hull, Vector3(size.x, body + ArenaRoom.HULL_DEPTH, size.z), Vector3(cx, -ArenaRoom.HULL_DEPTH, cz))
	_kit.add_box(_brass, Vector3(size.x + 0.04, 0.08, size.z + 0.04), Vector3(cx, body, cz))
	_kit.add_box(_hull, Vector3(size.x - 0.04, 0.1, size.z - 0.04), Vector3(cx, body + 0.08, cz))
	_kit.add_box(_brass, Vector3(size.x + 0.16, 0.06, size.z + 0.16), Vector3(cx, body + 0.18, cz))
	_kit.add_box(_brass, Vector3(size.x - 0.06, 0.03, size.z - 0.06), Vector3(cx, body + 0.24, cz))
	_kit.add_box(_brass, Vector3(size.x - 0.3, 0.03, size.z - 0.3), Vector3(cx, body + 0.27, cz))
	_tower_face(Vector3(cx, body, cz + hz), size, side, is_back)
	_tower_crown(Vector3(cx, lid, cz), size, crown)
	# The lantern light is the same as ever: `body` of the old design was `size.y - 0.42`.
	var light := OmniLight3D.new()
	light.omni_range = 3.5
	light.light_energy = ArenaRoom.LANTERN_ENERGY
	light.shadow_enabled = false
	light.position = Vector3(cx - side * 0.9, (size.y - 0.42) * 0.5, cz + hz + 0.45)
	room.add_child(light)
	room._lanterns.append(light)

## The face of a tower the camera sees, at `face` (x centre, top of the body, z of the face): corner posts, a framed lantern,
## louvred vents and an enamel stripe under the cornice. On the back towers the side wall hides everything below about 1.1 m
## (more towards the outer edge), so the lantern sits higher there.
func _tower_face(face: Vector3, size: Vector3, side: float, is_back: bool) -> void:
	var body := face.y
	var hx := size.x * 0.5
	for post: float in [-1.0, 1.0]:
		_kit.add_cylinder(_brass, Vector3(face.x + post * (hx - 0.03), (body - 1.2) * 0.5, face.z), Vector3.UP, 0.075, body + 1.2, 8)
	var lantern_height := 0.5 if is_back else 0.52
	var lantern_bottom := 1.45 if is_back else body * 0.5 - 0.26
	var z := face.z
	_kit.add_box(_brass, Vector3(0.38, lantern_height, 0.08), Vector3(face.x, lantern_bottom, z + 0.03))
	_kit.add_box(_brass, Vector3(0.46, 0.05, 0.12), Vector3(face.x, lantern_bottom + lantern_height, z + 0.03)) # roof
	_kit.add_box(_brass, Vector3(0.46, 0.05, 0.12), Vector3(face.x, lantern_bottom - 0.05, z + 0.03)) # sill
	_kit.add_box(_lamp, Vector3(0.24, lantern_height - 0.12, 0.06), Vector3(face.x, lantern_bottom + 0.06, z + 0.08), ArenaRoom.LANTERN_WARM)
	_kit.add_box(_brass, Vector3(0.26, 0.025, 0.07), Vector3(face.x, lantern_bottom + lantern_height * 0.5, z + 0.085)) # glazing bar
	_kit.add_box(_brass, Vector3(0.025, lantern_height - 0.1, 0.07), Vector3(face.x, lantern_bottom + 0.06, z + 0.085))
	_kit.glow_quad(Vector3(face.x, lantern_bottom + lantern_height * 0.5, z + 0.12), Vector3.RIGHT, ArenaRoom.SCREEN_UP, 0.4, 0.4, 0.26)
	# Vents either side of the lantern (the back towers show only the inner one, where the wall is lowest).
	for vent: float in [-1.0, 1.0]:
		if is_back and vent != -side:
			continue
		var vent_x := face.x + vent * 0.5
		var vent_bottom := 0.62 if is_back else body * 0.5 - 0.2
		_kit.add_box(_paint, Vector3(0.4, 0.3, 0.03), Vector3(vent_x, vent_bottom, z + 0.015), ArenaRoom.DARK)
		for slat in 5:
			_kit.add_box(_brass, Vector3(0.4, 0.025, 0.05), Vector3(vent_x, vent_bottom + 0.03 + slat * 0.055, z + 0.025))
	_kit.add_box(_enamel, Vector3(size.x - 0.24, 0.1, 0.02), Vector3(face.x, body - 0.15, z + 0.01))

## The cupola on a lid whose top centre is `at`: an enamel disc, an octagonal drum with lit slits, a brass tier and ring, a dome,
## a finial and a glowing bead with a halo, and a pinnacle at each lid corner. Seen from above they are concentric rings, which
## is what stops the lid reading as a flat rectangle. Everything stays within `crown` metres of the lid.
func _tower_crown(at: Vector3, size: Vector3, crown: float) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var drum_r := minf(hx, hz) * 0.62
	var drum_h := crown * 0.22
	var tier_h := crown * 0.1
	var dome_h := crown * 0.3
	_kit.add_cylinder(_enamel, Vector3(at.x, at.y + 0.006, at.z), Vector3.UP, drum_r + 0.07, 0.012, 16)
	var drum_y := at.y + 0.012
	var spare := (hx - 0.15) - (drum_r + 0.07) # lid left over either side of the enamel disc (the lid steps are 0.3 m narrower than the body)
	if spare > 0.12: # a louvred hood each side, for the long, shallow lids
		for hood: float in [-1.0, 1.0]:
			var hood_at := Vector3(at.x + hood * (drum_r + 0.07 + spare * 0.5), at.y, at.z)
			_kit.add_box(_frame, Vector3(spare * 0.8, 0.05, minf(hz * 0.7, 0.4)), hood_at)
			for slat in 4:
				_kit.add_box(_brass, Vector3(spare * 0.8, 0.012, 0.03), hood_at + Vector3(0.0, 0.05, (slat - 1.5) * minf(hz * 0.7, 0.4) * 0.24))
	_kit.add_cylinder(_frame, Vector3(at.x, drum_y + drum_h * 0.5, at.z), Vector3.UP, drum_r, drum_h, 8)
	# A lit slit on each of the drum's south-facing facets (the cylinder's facets are centred on 22.5 degrees plus 45 each).
	for facet in 8:
		var angle := TAU * (facet + 0.5) / 8.0
		var normal := Vector3(-sin(angle), 0.0, -cos(angle))
		if normal.z < 0.1:
			continue
		var tangent := Vector3.UP.cross(normal)
		var slit_at := Vector3(at.x, drum_y + drum_h * 0.5, at.z) + normal * (drum_r * cos(PI / 8.0) + 0.004)
		_kit.add_oriented_box(_lamp, Vector3(drum_r * 0.4, drum_h * 0.5, 0.012), slit_at, Basis(tangent, Vector3.UP, normal))
	var tier_y := drum_y + drum_h
	var tier_r := drum_r * 0.86
	_kit.add_cylinder(_brass, Vector3(at.x, tier_y + tier_h * 0.5, at.z), Vector3.UP, tier_r, tier_h, 12)
	var ring_y := tier_y + tier_h
	_kit.add_torus(_brass, Vector3(at.x, ring_y, at.z), Vector3.UP, tier_r - 0.02, 0.02, 12, 5)
	var dome_r := tier_r * 0.92
	var dome := PackedVector2Array()
	for step in 7: # a flattened hemisphere traced from the apex out and down
		var dome_angle := deg_to_rad(90.0 - step * 15.0)
		dome.append(Vector2(cos(dome_angle) * dome_r, sin(dome_angle) * dome_h))
	_kit.add_lathe(_brass, Vector3(at.x, ring_y, at.z), Vector3.UP, dome, 12)
	var stem := crown * 0.06
	var dome_top := ring_y + dome_h
	var bead_r := (at.y + crown - dome_top - stem) * 0.5
	_kit.add_cylinder(_frame, Vector3(at.x, dome_top + stem * 0.5, at.z), Vector3.UP, 0.012, stem, 6)
	var bead_at := Vector3(at.x, dome_top + stem + bead_r, at.z)
	_bead(bead_at, bead_r, Color.WHITE)
	_kit.glow_quad(bead_at, Vector3.RIGHT, ArenaRoom.SCREEN_UP, 0.34, 0.34, 0.4)
	var pinnacle_h := crown * 0.55
	var spike := PackedVector2Array([Vector2(0.0, pinnacle_h), Vector2(0.025, pinnacle_h * 0.55), Vector2(0.045, 0.03), Vector2(0.045, 0.0)])
	for px: float in [-1.0, 1.0]:
		for pz: float in [-1.0, 1.0]:
			var corner := Vector3(at.x + px * (hx - 0.2), at.y, at.z + pz * (hz - 0.2))
			_kit.add_box(_brass, Vector3(0.1, 0.04, 0.1), corner)
			_kit.add_lathe(_brass, corner + Vector3(0.0, 0.04, 0.0), Vector3.UP, spike, 6)

## A small sphere (a lathe of a half circle) of `radius` centred on `at`.
func _bead(at: Vector3, radius: float, color: Color) -> void:
	_kit.add_lathe(_lamp, at, Vector3.UP, RoomMeshKit.arc(Vector2.ZERO, radius, 90.0, -90.0, 6), 10, color)
