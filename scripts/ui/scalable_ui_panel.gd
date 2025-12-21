class_name ScalableUIPanel
extends RefCounted

## Base class for UI panels that scale with resolution
##
## This class provides automatic scaling behavior for overlay UI panels.
## Subclasses should:
## 1. Set base_panel_size in their setup() method
## 2. Call super.setup() to initialize scaling
## 3. Override _scale_fonts() to handle custom font scaling
## 4. Use register_font() to track labels that need scaling

var container: Control
var panel: Control  # The centered panel/container that gets scaled
var _owner: Node

# Base dimensions at 1080p
var base_panel_size: Vector2 = Vector2.ZERO
var base_font_sizes: Dictionary = {}  # node_path: base_size


func setup(nodes: Dictionary, owner: Node) -> void:
	container = nodes.get("container")
	panel = nodes.get("panel")
	_owner = owner

	if panel:
		# Store base size from current offsets
		base_panel_size = Vector2(
			panel.offset_right - panel.offset_left,
			panel.offset_bottom - panel.offset_top
		)

	# Connect to scale changes
	UIScaler.scale_changed.connect(_on_scale_changed)

	# Apply initial scale
	_apply_scale(UIScaler.scale_factor)


func _on_scale_changed(new_scale: float) -> void:
	_apply_scale(new_scale)


func _apply_scale(scale: float) -> void:
	if not panel:
		return

	# Scale panel size
	var scaled_size = base_panel_size * scale
	panel.offset_left = -scaled_size.x / 2.0
	panel.offset_top = -scaled_size.y / 2.0
	panel.offset_right = scaled_size.x / 2.0
	panel.offset_bottom = scaled_size.y / 2.0

	# Scale fonts (implemented by subclasses)
	_scale_fonts(scale)


func _scale_fonts(scale: float) -> void:
	# Override in subclasses to scale specific fonts and other elements
	pass


## Register a label for automatic font scaling
func register_font(label: Label, base_size: int) -> void:
	if label:
		var path = str(label.get_path())
		base_font_sizes[path] = base_size


## Apply font scales to all registered labels
func apply_font_scales(scale: float) -> void:
	for path in base_font_sizes:
		var label = _owner.get_node_or_null(NodePath(path))
		if label and label is Label:
			var base_size = base_font_sizes[path]
			label.add_theme_font_size_override("font_size", UIScaler.scale_font(base_size))
