extends GutTest

var store: AssetPresetStore
var root_path: String

func before_each() -> void:
	TestHelpers.reset_all_services()
	root_path = "user://storage_tests/%s" % str(Time.get_ticks_usec())
	store = AssetPresetStore.new(root_path)

func after_each() -> void:
	store.delete_directory_recursive(root_path)

func test_store_round_trip_isolated_from_default_service() -> void:
	var previous := AssetConfigService.get_active_preset()
	store.ensure_user_preset_state("example", "default")
	store.user_overrides["example"] = {"player:main": {"visual.scale": Vector2(2, 3)}}
	assert_eq(store.save_user_preset("example"), OK)
	var reopened := AssetPresetStore.new(root_path)
	reopened.load_user_presets()
	assert_eq(reopened.user_overrides["example"]["player:main"]["visual.scale"], Vector2(2, 3))
	assert_eq(AssetConfigService.get_active_preset(), previous)

func test_state_file_is_not_a_user_preset() -> void:
	assert_eq(store.save_active_preset_state(), OK)
	store.load_user_presets()
	assert_false(store.user_preset_bases.has("state"))

func test_malformed_preset_is_not_loaded() -> void:
	DirAccess.make_dir_recursive_absolute(store.user_preset_dir)
	var file := FileAccess.open(store.user_preset_path("broken"), FileAccess.WRITE)
	file.store_string("[broken")
	file.close()
	store.load_user_presets()
	assert_engine_error("ConfigFile parse error")
	assert_false(store.user_preset_bases.has("broken"))

func test_path_traversal_name_is_rejected() -> void:
	assert_false(AssetPresetStore.is_valid_name("../outside"))
	assert_eq(store.save_user_preset("../outside"), ERR_INVALID_PARAMETER)

func test_write_failure_is_returned() -> void:
	DirAccess.make_dir_recursive_absolute(root_path)
	var file := FileAccess.open(root_path.path_join("blocked"), FileAccess.WRITE)
	file.close()
	var blocked := AssetPresetStore.new(root_path.path_join("blocked"))
	assert_ne(blocked.save_user_preset("example"), OK)
	assert_engine_error("Could not create directory")
