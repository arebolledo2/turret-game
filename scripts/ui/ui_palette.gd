class_name UiPalette
extends RefCounted

## One place for UI colours. Teal is the UI colour, amber is money, each stat keeps one hue on every
## screen (icon, chip, bar), and green/red are reserved for good/bad changes.
const PANEL: Color = Color(.024, .063, .09, .94)
const PANEL_SOLID: Color = Color("07131b")
const PANEL_HI: Color = Color("0c2a33")
const LINE: Color = Color("1b4048")
const TEAL: Color = Color("54c5c5")
const TEAL_HI: Color = Color("58ece1")
const INK: Color = Color("d4efec")
const MUTED: Color = Color("7e9ca6")
const SCRAP: Color = Color("f5b942")
const GOOD: Color = Color("5fe3a0")
const BAD: Color = Color("ff5a6a")

const STAT_COLORS: Dictionary = {
	"dmg": Color("ff7a6b"), "rate": Color("c4e65a"), "range": Color("6cb8ff"), "slow": Color("b48cff"),
	"hull": Color("5ef0b0"), "speed": Color("bff3ff"), "pickup": Color("ff9fe0"), "scrap": SCRAP,
	"penalty": SCRAP, "dps": Color("ff9c6e"), "kills": Color("e8eef0"), "wave": TEAL_HI,
	"time": Color("cfe9ea"), "core": TEAL_HI,
}

## Colour for a UI stat key ("dmg", "rate", "hull"...); teal for anything unknown.
static func stat_color(stat: String) -> Color:
	return STAT_COLORS.get(stat, TEAL)

## Chip/tile tint after a good or bad change; -1 bad, 0 neutral, 1 good.
static func tone_color(tone: int, neutral: Color) -> Color:
	if tone > 0:
		return GOOD
	if tone < 0:
		return BAD
	return neutral
