class_name EvolutionReminder
extends ConfirmationDialog

signal review_requested
signal deploy_requested
var deploy_button: Button

func _ready() -> void:
	title = "Evolutions ready"
	get_ok_button().text = "REVIEW TURRETS"
	get_cancel_button().text = "BACK"
	deploy_button = add_button("DEPLOY ANYWAY", false, "deploy")
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0b2530")
	panel.border_color = Color("48dcd4")
	panel.set_border_width_all(2)
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	add_theme_stylebox_override("panel", panel)
	get_label().add_theme_font_size_override("font_size", 23)
	for button in [deploy_button, get_ok_button(), get_cancel_button()]:
		button.custom_minimum_size = Vector2(190, 48)
		button.add_theme_font_size_override("font_size", 23)
	var buttons: Array[Button] = [deploy_button, get_ok_button(), get_cancel_button()]
	for i in range(buttons.size()):
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(buttons[maxi(0, i - 1)])
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(buttons[mini(buttons.size() - 1, i + 1)])
	confirmed.connect(func() -> void: review_requested.emit())
	custom_action.connect(func(action: StringName) -> void:
		if action == "deploy":
			hide()
			deploy_requested.emit())

func show_ready(count: int) -> void:
	dialog_text = "%d turret%s ready to evolve.
Review your free upgrades before the next wave.
You can deploy now and keep them for a later Shop visit." % [count, " is" if count == 1 else "s are"]
	popup_centered(Vector2i(760, 220))
	get_ok_button().grab_focus.call_deferred()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		hide()
		canceled.emit()
