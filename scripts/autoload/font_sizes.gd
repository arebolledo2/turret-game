extends Node

## Centralized font size management
##
## This service automatically updates the global UI theme based on the current
## UI scale factor. CONSTANTS are kept as BASE values (1080p).
##
## Usage:
##   - Just use the Type Variations in the Theme (e.g. "Header1", "Body")
##   - No need to call FontSizes.get_scaled() manually anymore
##     (though it is kept for backward compatibility if needed)

# ===== HEADING SIZES (Base 1080p) =====
const HEADING_1: int = 64 # Large titles
const HEADING_2: int = 42 # Screen titles
const HEADING_3: int = 32 # Section headers
const HEADING_4: int = 24 # Sub-headers

# ===== BODY TEXT SIZES (Base 1080p) =====
const BODY: int = 18 # Primary UI text
const BODY_SMALL: int = 16 # Secondary UI text
const BODY_TINY: int = 15 # Tertiary text
const CAPTION: int = 14 # Tiny labels

# ===== COMBAT FEEDBACK (Restored) =====
const DAMAGE_NORMAL: int = 24
const DAMAGE_CRIT: int = 32

# ===== BUTTON SIZES (Base 1080p) =====
const BUTTON_LARGE: int = 24
const BUTTON_MEDIUM: int = 20
const BUTTON_XLARGE: int = 32

# ===== ICON SIZES (Base 1080p) =====
const ICON_LARGE: int = 76
const ICON_MEDIUM: int = 32
const ICON_SMALL: int = 24
const ICON_BADGE: int = 18

# ===== SHOP-SPECIFIC SIZES (Restored) =====
const SHOP_OFFER_ICON: int = 76
const SHOP_OFFER_NAME: int = 22
const SHOP_OFFER_PRICE: int = 20
const SHOP_OFFER_DESC: int = 18
const SHOP_CATEGORY: int = 20

# Theme Reference
var _theme: Theme

func _ready() -> void:
	# Load the global theme
	_theme = load("res://resources/ui_theme.tres")
	
	# Connect to scaler
	if UIScaler:
		UIScaler.scale_changed.connect(_on_scale_changed)
		_update_theme_sizes(UIScaler.scale_factor)

func _on_scale_changed(new_scale: float) -> void:
	_update_theme_sizes(new_scale)

func _update_theme_sizes(scale: float) -> void:
	if not _theme:
		return
		
	# Update Label Variations
	_set_font_size("Header1", HEADING_1, scale)
	_set_font_size("Header2", HEADING_2, scale)
	_set_font_size("Header3", HEADING_3, scale)
	_set_font_size("Header4", HEADING_4, scale)
	_set_font_size("Body", BODY, scale)
	_set_font_size("BodySmall", BODY_SMALL, scale)
	
	# Update Button Variations
	_set_font_size("ButtonLarge", BUTTON_LARGE, scale)
	_set_font_size("ButtonMedium", BUTTON_MEDIUM, scale)
	_set_font_size("ButtonXLarge", BUTTON_XLARGE, scale)
	
	# Also update default Label/Button if desired, 
	# but usually we want to rely on variations. 
	# If we want the *default* Label to be BODY size:
	_theme.set_default_font_size(UIScaler.scale_font(BODY))

func _set_font_size(type_name: String, base_size: int, scale: float) -> void:
	# Use UIScaler.scale_font logic locally or call it
	# Reimplementing simplified here to ensure we use the passed scale
	var scaled = maxi(int(base_size * scale), 8)
	_theme.set_font_size("font_size", type_name, scaled)

# --- Legacy/Helper Methods (kept for code compatibility vs refactoring EVERYTHING) ---

func get_scaled(base_size: int) -> int:
	return UIScaler.scale_font(base_size)

func get_heading(level: int) -> int:
	match level:
		1: return HEADING_1
		2: return HEADING_2
		3: return HEADING_3
		4: return HEADING_4
		_: return BODY

func get_icon_size(category: String) -> int:
	match category:
		"large": return ICON_LARGE
		"medium": return ICON_MEDIUM
		"small": return ICON_SMALL
		"badge": return ICON_BADGE
		_: return ICON_MEDIUM
