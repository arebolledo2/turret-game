extends Node

## Centralized font size constants for all UI elements
##
## All sizes are defined for 1080p baseline and scale automatically via UIScaler
##
## Usage:
##   label.add_theme_font_size_override("font_size", FontSizes.BODY)
##   scaled_size = FontSizes.get_scaled(FontSizes.HEADING_1)

# ===== HEADING SIZES =====
# Large titles (Wave Announcement, Victory/Defeat screens)
const HEADING_1: int = 64

# Screen titles (Shop, Game Over, Main Menu)
const HEADING_2: int = 42

# Section headers (Wave number display, Shop scrap counter)
const HEADING_3: int = 32

# Sub-headers (Shop buttons, menu options)
const HEADING_4: int = 24

# ===== BODY TEXT SIZES =====
# Primary UI text (HUD labels, stats display)
const BODY: int = 18

# Secondary UI text (Shop descriptions, item details)
const BODY_SMALL: int = 16

# Tertiary text (Fine print, tooltips)
const BODY_TINY: int = 15

# Tiny labels (Off-screen indicators, minor UI elements)
const CAPTION: int = 14

# ===== ICON SIZES =====
# Large icons (Shop offer cards)
const ICON_LARGE: int = 76

# Medium icons (Item display, turret display)
const ICON_MEDIUM: int = 32

# Small icons (Inventory, compact UI)
const ICON_SMALL: int = 24

# Icon badges (Counts, status indicators)
const ICON_BADGE: int = 18

# ===== COMBAT FEEDBACK =====
# Normal damage numbers
const DAMAGE_NORMAL: int = 24

# Critical hit damage numbers
const DAMAGE_CRIT: int = 32

# ===== SHOP-SPECIFIC SIZES =====
# Shop offer card icon (extra large)
const SHOP_OFFER_ICON: int = 76

# Shop offer name
const SHOP_OFFER_NAME: int = 22

# Shop offer price
const SHOP_OFFER_PRICE: int = 20

# Shop offer description
const SHOP_OFFER_DESC: int = 18

# Shop category labels
const SHOP_CATEGORY: int = 20

# ===== UTILITY FUNCTIONS =====

## Get scaled font size for current resolution
## Uses UIScaler to calculate appropriate size based on viewport height
func get_scaled(base_size: int) -> int:
	return UIScaler.scale_font(base_size)

## Get scaled heading size by level (1-4)
func get_heading(level: int) -> int:
	match level:
		1: return HEADING_1
		2: return HEADING_2
		3: return HEADING_3
		4: return HEADING_4
		_:
			push_error("Invalid heading level: %d. Expected 1-4." % level)
			return BODY

## Get scaled icon size by category
func get_icon_size(category: String) -> int:
	match category:
		"large": return ICON_LARGE
		"medium": return ICON_MEDIUM
		"small": return ICON_SMALL
		"badge": return ICON_BADGE
		_:
			push_error("Invalid icon category: %s" % category)
			return ICON_MEDIUM
