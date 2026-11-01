class_name ArenaLayout
extends RefCounted

## A named list of terrain zones; the data an arena is authored from (see `ArenaLayouts`).
var id: String = ""
var layout_name: String = ""
## Which texture set paints the arena floor (see `WorldGeometry.FLOOR_THEMES`).
var floor_theme: String = WorldGeometry.DEFAULT_FLOOR_THEME
## What is outside the room's windows (see `SpaceThemes`).
var space_theme: String = SpaceThemes.DEFAULT_THEME
var zones: Array[TerrainZone] = []

static func from_entry(entry: Dictionary) -> ArenaLayout:
	var layout := ArenaLayout.new()
	layout.id = str(entry["id"])
	layout.layout_name = str(entry["name"])
	layout.floor_theme = str(entry.get("theme", WorldGeometry.DEFAULT_FLOOR_THEME))
	layout.space_theme = str(entry.get("space", SpaceThemes.DEFAULT_THEME))
	for zone in entry["zones"]:
		layout.zones.append(zone)
	return layout

func has_type(zone_type: String) -> bool:
	for zone in zones:
		if zone.type == zone_type:
			return true
	return false
