class_name UiIconData
extends RefCounted

## Icon artwork as SVG fragments on a 24px grid (1.8 stroke, round caps, white; tinted at draw time).
## Kept in code rather than .svg files so they rasterise crisply at any size, need no import step and
## survive export. Add an entry here and UiIcons picks it up. Naming: stat/UI icons are bare
## ("hull"), turrets "turret_<id>", items "item_<id>".
const PATHS: Dictionary = {
	"missing": "<rect x='5' y='5' width='14' height='14'/><path d='M9 9l6 6M15 9l-6 6'/>",
	"module": "<path d='M12 3l8 4.5v9L12 21l-8-4.5v-9z'/><path d='M12 8v8M8 10v4M16 10v4'/>",
	"turret": "<circle cx='12' cy='14' r='7'/><path d='M12 14V3'/><circle cx='12' cy='14' r='2' fill='#fff' stroke='none'/>",
	# Stats and HUD
	"hull": "<path d='M12 3l7 3v5.5c0 4.6-3 7.7-7 9.5-4-1.8-7-4.9-7-9.5V6z'/><path d='M9 11.5l3 2 3-2'/>",
	"core": "<path d='M12 3l8 4.5v9L12 21l-8-4.5v-9z'/><circle cx='12' cy='12' r='3'/>",
	"scrap": "<circle cx='12' cy='12' r='6'/><circle cx='12' cy='12' r='2.2'/><path d='M12 4V2M12 20v2M4 12H2M20 12h2M6.3 6.3L4.9 4.9M17.7 6.3l1.4-1.4M6.3 17.7l-1.4 1.4M17.7 17.7l1.4 1.4'/>",
	"kills": "<circle cx='12' cy='12' r='6.5'/><path d='M12 2.5V7M12 17v4.5M2.5 12H7M17 12h4.5'/><circle cx='12' cy='12' r='1.3' fill='#fff' stroke='none'/>",
	"wave": "<path d='M2 14c2-5 4-5 6 0s4 5 6 0 4-5 6-1'/><path d='M2 20h20' opacity='.5'/>",
	"timer": "<circle cx='12' cy='13' r='8'/><path d='M12 8.5V13l3 2M9.5 2.5h5'/>",
	"damage": "<path d='M12 2l2.2 6.3 6.3-2.3-3.7 5.6 5.2 3.4-6.2.9.8 6.6-4.6-4.6-4.6 4.6.8-6.6-6.2-.9 5.2-3.4L3.5 6l6.3 2.3z'/>",
	"rate": "<path d='M20.5 12a8.5 8.5 0 11-2.5-6M20 2.5V7h-4.5'/><path d='M12 7.5V12l3 2'/>",
	"range": "<circle cx='12' cy='12' r='9'/><circle cx='12' cy='12' r='5'/><circle cx='12' cy='12' r='1.4' fill='#fff' stroke='none'/>",
	"slow": "<path d='M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9'/><path d='M9.5 4.5L12 7l2.5-2.5M9.5 19.5L12 17l2.5 2.5'/>",
	"speed": "<path d='M13 2L5 14h6l-1 8 8-12h-6z'/>",
	"pickup": "<path d='M5 4v8a7 7 0 0014 0V4h-4v8a3 3 0 01-6 0V4z'/><path d='M5 8h4M15 8h4'/>",
	"penalty": "<path d='M3 3h8l10 10-8 8L3 11z'/><circle cx='7.5' cy='7.5' r='1.4' fill='#fff' stroke='none'/>",
	# Actions and screens
	"reroll": "<path d='M20 9a8 8 0 00-14-2.5L4 9M4 4v5h5M4 15a8 8 0 0014 2.5L20 15M20 20v-5h-5'/>",
	"repair": "<path d='M9 3h6v6h6v6h-6v6H9v-6H3V9h6z'/>",
	"deploy": "<path d='M5 5l7 7-7 7M12 5l7 7-7 7'/>",
	"play": "<path d='M7 4l13 8-13 8z'/>",
	"pause": "<path d='M8 5v14M16 5v14' stroke-width='3'/>",
	"settings": "<path d='M4 7h10M18 7h2M4 17h2M10 17h10'/><circle cx='16' cy='7' r='2'/><circle cx='8' cy='17' r='2'/>",
	"home": "<path d='M3 11l9-8 9 8M5 9.5V20h14V9.5'/>",
	"power": "<path d='M12 3v9M6.5 6.5a8 8 0 1011 0'/>",
	"check": "<path d='M5 12l5 5 9-10'/>",
	"back": "<path d='M14 5l-7 7 7 7M7 12h13'/>",
	"signal": "<path d='M3 9a14 14 0 0118 0M6 13a9 9 0 0112 0M9.5 17a4 4 0 015 0M3 3l18 18'/>",
	"trophy": "<path d='M7 4h10v5a5 5 0 01-10 0zM7 6H4v2a3 3 0 003 3M17 6h3v2a3 3 0 01-3 3M12 14v4M8 20h8'/>",
	"star": "<path d='M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z'/>",
	"sector": "<path d='M12 21s7-6 7-12a7 7 0 10-14 0c0 6 7 12 7 12z'/><circle cx='12' cy='9' r='2.5'/>",
	"bars": "<path d='M5 20v-5M10 20v-9M15 20V7M20 20V3'/>",
	"fullscreen": "<path d='M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5'/>",
	"monitor": "<path d='M3 5h18v11H3zM8 20h8M12 16v4'/>",
	"motion": "<path d='M2 12h4l3-7 4 14 3-7h6'/>",
	"volume": "<path d='M4 9h4l5-4v14l-5-4H4z'/><path d='M16 9a4 4 0 010 6M19 6a8 8 0 010 12'/>",
	# Turrets
	"turret_normal": "<circle cx='12' cy='14' r='7'/><path d='M12 14V3'/><circle cx='12' cy='14' r='2' fill='#fff' stroke='none'/>",
	"turret_plasma": "<circle cx='12' cy='12' r='9'/><circle cx='12' cy='12' r='4.2' fill='#fff' stroke='none'/>",
	"turret_shock": "<circle cx='12' cy='12' r='9.5'/><path d='M13 5.5l-4 7h4l-2 6 5-8h-4z'/>",
	"turret_tesla": "<path d='M12 21V10'/><path d='M6.5 5a8 8 0 000 9M17.5 5a8 8 0 010 9'/><circle cx='12' cy='7.5' r='2'/><path d='M8 21h8'/>",
	"turret_melee": "<path d='M5 19L18 6M15 4l5 5M5 14l5 5'/>",
	# Items (more land with the item icon pass; the rest fall back to "module")
	"item_compact_design": "<path d='M4 4l5 5M9 4.5V9H4.5M20 4l-5 5M15 4.5V9h4.5M4 20l5-5M9 19.5V15H4.5M20 20l-5-5M15 19.5V15h4.5'/>",
}
