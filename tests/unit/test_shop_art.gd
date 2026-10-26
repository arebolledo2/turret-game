extends GutTest

func test_portrait_key_is_the_form_id_or_the_base_id() -> void:
	assert_eq(ShopArt.turret_portrait_key("normal"), "normal")
	assert_eq(ShopArt.turret_portrait_key("normal", ""), "normal")
	assert_eq(ShopArt.turret_portrait_key("normal", "cyclone_gatling"), "cyclone_gatling")
	assert_eq(ShopArt.turret_portrait_key("melee", "saber"), "saber")

func test_every_implemented_form_has_its_own_portrait_file() -> void:
	for form in TurretEvolution.implemented_forms():
		var path := "res://assets/ui/turrets/%s.png" % ShopArt.turret_portrait_key("", form)
		assert_true(FileAccess.file_exists(path) and ResourceLoader.exists(path), "Missing portrait for %s: %s" % [form, path])
		for base: String in TurretEvolution.bases():
			if form in TurretEvolution.options(base, 0) + TurretEvolution.options(base, 1):
				assert_same(ShopArt.turret(base, form), load(path), "%s must not fall back to the base portrait" % form)

func test_base_turrets_keep_their_base_portraits() -> void:
	for base: String in TurretEvolution.bases():
		if ResourceLoader.exists("res://assets/ui/turrets/%s.png" % base):
			assert_same(ShopArt.turret(base), load("res://assets/ui/turrets/%s.png" % base))
