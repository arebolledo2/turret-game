class_name FloorThemes
extends RefCounted

## Display data for the arena floor texture sets (`WorldGeometry.FLOOR_THEMES`); the art rules live in doc/art/floor-themes.md.
const INFO := {
	"foundry": {"name": "Clockwork Stage", "note": "Teal enamel stage plates with brass inlay frames, engraved dials, cog recesses and key-wound spirals."},
	"concrete": {"name": "Terracotta Flagstones", "note": "Warm terracotta, sandstone and umber crazy-paving in ivory grout, copper wire joints and inlaid cog medallions."},
	"grating": {"name": "Verdigris Deck", "note": "Oxidised copper deck plates, brass bar gratings over a green glow, a drain, pipe-work and oily puddles."},
	"hexworks": {"name": "Honeycomb Works", "note": "Violet-slate hexagon plates rimmed in brass: ribbed cells, domed bosses and lit watch-jewels, some rims powered."},
	"marquetry": {"name": "Walnut Chevron", "note": "Mitred walnut parquet meeting in V points, with a brass zigzag inlay and jewels set at the peaks."},
	"orrery": {"name": "Midnight Orrery", "note": "Four slate plates engraved as orreries: brass suns, orbit grooves, an astrolabe ring, planets, moons and star-jewels."},
	"mosaic": {"name": "Glazed Mosaic", "note": "A thousand glazed ceramic tiles drifting from teal to indigo to moss, crossed by a brass lattice and lit ivory jewels."},
	"frost": {"name": "Frostglass", "note": "Slabs of cracked blue ice with rime, snow drifts, frozen bubbles, glowing fissures and brass clamp studs."},
}

static func display_name(theme: String) -> String:
	return str(INFO.get(theme, {}).get("name", theme.capitalize()))

static func note(theme: String) -> String:
	return str(INFO.get(theme, {}).get("note", ""))

## The arena layout that uses this theme, or "" if none does.
static func layout_name(theme: String) -> String:
	for entry in ArenaLayouts.all():
		if str(entry["theme"]) == theme:
			return str(entry["name"])
	return ""
