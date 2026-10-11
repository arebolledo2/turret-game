class_name ChestRewardScreen
extends CanvasLayer

var world: ArenaWorld
var active := false
var root: Control
var heading: Label
var title: Label
var description: Label
var rarity_label: Label
var value_label: Label
var art: TextureRect
var keep_button: Button
var sell_button: Button
var ready_at := 0

func _ready() -> void:
	layer = 12
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(.015, .035, .045, .94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", ChamferStyle.make(UiPalette.PANEL, UiPalette.TEAL, 16, 30, 24))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	heading = _label(column, 23)
	heading.modulate = UiPalette.TEAL_HI
	art = TextureRect.new()
	art.custom_minimum_size = Vector2(0, 200)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(art)
	rarity_label = _label(column, 20)
	title = _label(column, 34)
	description = _label(column, 24)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 560
	value_label = _label(column, 21)
	value_label.modulate = UiPalette.MUTED
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	keep_button = _button(row, "KEEP ITEM")
	sell_button = _button(row, "SELL")
	keep_button.pressed.connect(_choose.bind(true))
	sell_button.pressed.connect(_choose.bind(false))
	keep_button.focus_neighbor_right = keep_button.get_path_to(sell_button)
	sell_button.focus_neighbor_left = sell_button.get_path_to(keep_button)
	root.hide()

func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 25)
	parent.add_child(button)
	return button

func show_next() -> void:
	if active or world.drops.pending_items.is_empty():
		return
	active = true
	var reward: Dictionary = world.drops.pending_items[0]
	heading.text = "CHEST RECOVERED · %d ITEM%s TO REVIEW" % [world.drops.pending_items.size(), "" if world.drops.pending_items.size() == 1 else "S"]
	var rarity := ItemRegistry.get_rarity(reward.id)
	rarity_label.text = ItemRegistry.get_rarity_name(rarity).to_upper()
	rarity_label.modulate = ItemRegistry.get_rarity_color(rarity).lightened(.25)
	title.text = str(ItemRegistry.get_item_dict(reward.id).name)
	description.text = ArenaShop.item_description(reward.id)
	art.texture = ShopArt.item(reward.id)
	value_label.text = "Item value: %d scrap · Sell for 25%%" % reward.value
	keep_button.disabled = not world.drops.can_keep_next()
	keep_button.text = "KEEP ITEM" if not keep_button.disabled else "STACK LIMIT REACHED"
	sell_button.text = "SELL FOR %d SCRAP" % reward.sale
	root.show()
	ready_at = Time.get_ticks_msec() + 250
	focus_choice.call_deferred()

func focus_choice() -> void:
	if active:
		(sell_button if keep_button.disabled else keep_button).grab_focus()

func _choose(keep: bool) -> void:
	if not active or Time.get_ticks_msec() < ready_at:
		return
	if not world.drops.resolve_item(keep):
		return
	cancel()
	world.waves.complete_wave()

func _input(event: InputEvent) -> void:
	if not active or world.paused:
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		get_viewport().set_input_as_handled()
		_choose(get_viewport().gui_get_focus_owner() != sell_button)

func cancel() -> void:
	active = false
	if is_instance_valid(root):
		root.hide()

func _process(_delta: float) -> void:
	root.visible = active and not world.paused
