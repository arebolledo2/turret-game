extends Node

## Debug Service - Compile-time debug output management
## Control debug output via const flags (no runtime UI overhead)
##
## Usage:
##   DebugService.log(DebugService.ENTITY, "Enemy spawned at position: ", position)
##   DebugService.warn(DebugService.COMBAT, "Invalid collision shape detected")
##   DebugService.error(DebugService.VALIDATION, "Component initialization failed")

# =============================================================================
# COMPILE-TIME FEATURE FLAGS (Edit these to control debug output)
# =============================================================================

# Master switch - disable ALL debug output
const ENABLED: bool = true

# Category-specific flags
const ENTITY: bool = true          # Entity lifecycle (enemies, turrets, targets)
const COMBAT: bool = false         # Combat mechanics (damage, collisions, hitboxes)
const AI: bool = false             # Enemy AI and movement
const ARENA: bool = false          # Arena setup and configuration
const UI: bool = false             # UI setup and interaction
const SYSTEMS: bool = false        # Game systems (modes, spawning, state)
const VALIDATION: bool = true      # Warnings and errors (always on by default)

# =============================================================================
# LOGGING METHODS
# =============================================================================

## Log a debug message for a specific category
## Only outputs if ENABLED and the category flag is true
func log(category: bool, message: Variant, arg1: Variant = "", arg2: Variant = "", arg3: Variant = "", arg4: Variant = "", arg5: Variant = "", arg6: Variant = "", arg7: Variant = "", arg8: Variant = "") -> void:
	if ENABLED and category:
		var output: String = str(message)
		if arg1 != null and not (arg1 is String and arg1 == ""):
			output += str(arg1)
		if arg2 != null and not (arg2 is String and arg2 == ""):
			output += str(arg2)
		if arg3 != null and not (arg3 is String and arg3 == ""):
			output += str(arg3)
		if arg4 != null and not (arg4 is String and arg4 == ""):
			output += str(arg4)
		if arg5 != null and not (arg5 is String and arg5 == ""):
			output += str(arg5)
		if arg6 != null and not (arg6 is String and arg6 == ""):
			output += str(arg6)
		if arg7 != null and not (arg7 is String and arg7 == ""):
			output += str(arg7)
		if arg8 != null and not (arg8 is String and arg8 == ""):
			output += str(arg8)
		print(output)

## Log a warning message for a specific category
## Uses push_warning() for better visibility in editor
func warn(category: bool, message: Variant, arg1: Variant = "", arg2: Variant = "", arg3: Variant = "", arg4: Variant = "", arg5: Variant = "") -> void:
	if ENABLED and category:
		var output: String = str(message)
		if arg1 != null and not (arg1 is String and arg1 == ""):
			output += str(arg1)
		if arg2 != null and not (arg2 is String and arg2 == ""):
			output += str(arg2)
		if arg3 != null and not (arg3 is String and arg3 == ""):
			output += str(arg3)
		if arg4 != null and not (arg4 is String and arg4 == ""):
			output += str(arg4)
		if arg5 != null and not (arg5 is String and arg5 == ""):
			output += str(arg5)
		push_warning(output)

## Log an error message for a specific category
## Uses push_error() for critical issues
func error(category: bool, message: Variant, arg1: Variant = "", arg2: Variant = "", arg3: Variant = "", arg4: Variant = "", arg5: Variant = "") -> void:
	if ENABLED and category:
		var output: String = str(message)
		if arg1 != null and not (arg1 is String and arg1 == ""):
			output += str(arg1)
		if arg2 != null and not (arg2 is String and arg2 == ""):
			output += str(arg2)
		if arg3 != null and not (arg3 is String and arg3 == ""):
			output += str(arg3)
		if arg4 != null and not (arg4 is String and arg4 == ""):
			output += str(arg4)
		if arg5 != null and not (arg5 is String and arg5 == ""):
			output += str(arg5)
		push_error(output)

# =============================================================================
# HELPER METHODS
# =============================================================================

## Quick check if a category is enabled (useful for expensive debug operations)
func is_enabled(category: bool) -> bool:
	return ENABLED and category

## Get a formatted category status report (for debugging the debug system itself)
func get_status() -> String:
	if not ENABLED:
		return "Debug System: DISABLED (Master switch off)"

	var status_lines: PackedStringArray = [
		"Debug System: ENABLED",
		"  ENTITY: " + str(ENTITY),
		"  COMBAT: " + str(COMBAT),
		"  AI: " + str(AI),
		"  ARENA: " + str(ARENA),
		"  UI: " + str(UI),
		"  SYSTEMS: " + str(SYSTEMS),
		"  VALIDATION: " + str(VALIDATION)
	]
	return "\n".join(status_lines)
