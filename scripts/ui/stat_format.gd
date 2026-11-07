class_name StatFormat
extends RefCounted

## Number formatting for stat displays: one decimal everywhere. A before → after pair that would read the
## same at one decimal (1.20 → 1.24) keeps two, so a real change never shows as "1.2 → 1.2".

static func one(value: float, unit: String = "") -> String:
	return "%.1f%s" % [value, unit]

## "before → after" (or just the value when unchanged), each with `unit`.
static func pair(before: float, after: float, unit: String = "") -> String:
	if is_equal_approx(before, after):
		return one(after, unit)
	var format := "%.2f%s" if "%.1f" % before == "%.1f" % after else "%.1f%s"
	return (format % [before, unit]) + " → " + (format % [after, unit])

## The decimals `pair` would use, for callers that colour or lay out the two halves themselves.
static func decimals(before: float, after: float) -> String:
	return "%.2f" if not is_equal_approx(before, after) and "%.1f" % before == "%.1f" % after else "%.1f"
