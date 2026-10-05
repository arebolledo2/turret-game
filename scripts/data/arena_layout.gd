class_name ArenaLayout
extends RefCounted

## A named list of terrain zones; the data an arena is authored from (see `ArenaLayouts`).
var id: String = ""
var layout_name: String = ""
var zones: Array[TerrainZone] = []

static func from_entry(entry: Dictionary) -> ArenaLayout:
	var layout := ArenaLayout.new()
	layout.id = str(entry["id"])
	layout.layout_name = str(entry["name"])
	for zone in entry["zones"]:
		layout.zones.append(zone)
	return layout

func has_type(zone_type: String) -> bool:
	for zone in zones:
		if zone.type == zone_type:
			return true
	return false
