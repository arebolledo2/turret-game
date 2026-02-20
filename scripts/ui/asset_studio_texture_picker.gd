extends Window
class_name AssetStudioTexturePicker

signal texture_selected(slot_key: String, path: String)

@onready var search_input: LineEdit = $MarginContainer/VBoxContainer/SearchInput
@onready var texture_list: ItemList = $MarginContainer/VBoxContainer/TextureList
@onready var select_button: Button = $MarginContainer/VBoxContainer/Buttons/SelectButton
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/Buttons/CancelButton

var _slot_key: String = ""
var _all_paths: Array[String] = []


func _ready() -> void:
	close_requested.connect(_on_cancel_pressed)
	if search_input:
		search_input.text_changed.connect(_on_search_changed)
	if texture_list:
		texture_list.item_activated.connect(_on_item_activated)
	if select_button:
		select_button.pressed.connect(_on_select_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	_refresh_texture_paths()
	_refresh_list("")


func open_for_slot(slot_key: String, initial_path: String = "") -> void:
	_slot_key = slot_key
	if _all_paths.is_empty():
		_refresh_texture_paths()
	_refresh_list(search_input.text if search_input else "")
	_select_initial_path(initial_path)
	popup_centered_ratio(0.7)
	if search_input:
		search_input.grab_focus()


func _refresh_texture_paths() -> void:
	_all_paths.clear()
	_collect_paths_recursive("res://assets", _all_paths)
	_all_paths.sort()


func _collect_paths_recursive(root_path: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := "%s/%s" % [root_path, entry]
		if dir.current_is_dir():
			_collect_paths_recursive(full_path, out_paths)
		elif _is_supported_texture(full_path):
			out_paths.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_supported_texture(path: String) -> bool:
	var lower := path.to_lower()
	return lower.ends_with(".png") or lower.ends_with(".webp") or lower.ends_with(".jpg") or lower.ends_with(".jpeg")


func _refresh_list(filter_text: String) -> void:
	if texture_list == null:
		return
	texture_list.clear()
	var filter_lower := filter_text.to_lower().strip_edges()
	for texture_path in _all_paths:
		if not filter_lower.is_empty() and texture_path.to_lower().find(filter_lower) < 0:
			continue
		texture_list.add_item(texture_path)


func _select_initial_path(path: String) -> void:
	if texture_list == null:
		return
	if path.is_empty():
		if texture_list.item_count > 0:
			texture_list.select(0)
		return

	for i in range(texture_list.item_count):
		if texture_list.get_item_text(i) == path:
			texture_list.select(i)
			texture_list.ensure_current_is_visible()
			return

	if texture_list.item_count > 0:
		texture_list.select(0)


func _on_search_changed(new_text: String) -> void:
	_refresh_list(new_text)


func _on_item_activated(index: int) -> void:
	texture_list.select(index)
	_emit_selected_path()


func _on_select_pressed() -> void:
	_emit_selected_path()


func _emit_selected_path() -> void:
	if texture_list == null:
		return
	var selected := texture_list.get_selected_items()
	if selected.is_empty():
		return
	var index := int(selected[0])
	var selected_path := texture_list.get_item_text(index)
	texture_selected.emit(_slot_key, selected_path)
	hide()


func _on_cancel_pressed() -> void:
	hide()
