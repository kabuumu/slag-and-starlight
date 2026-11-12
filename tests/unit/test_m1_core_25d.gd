extends RefCounted


func run(tree: SceneTree, h: RefCounted, tier_filter: String) -> void:
	print("\n[Suite] M1: Core 2.5D Setup, Autoloads, Player & Billboards")
	var run_t1 = tier_filter in ["all", "1"]
	var run_t2 = tier_filter in ["all", "2"]

	if run_t1:
		_test_t1_main_subviewport(tree, h)
		_test_t1_postprocess_shader(tree, h)
		_test_t1_autoload_eventbus_signals(tree, h)
		_test_t1_autoload_gamestate(tree, h)
		_test_t1_autoload_playerstats_defaults(tree, h)
		_test_t1_player_controller_and_rays(tree, h)
		_test_t1_billboard_8dir(tree, h)

	if run_t2:
		_test_t2_gamestate_missing_flag_and_negative_rep(tree, h)
		_test_t2_billboard_zero_vector_and_cardinals(tree, h)
		_test_t2_player_ray_ranges_boundary(tree, h)


func _test_t1_main_subviewport(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M1_main_subviewport_320x200_nearest")
	var packed = h.load_scene_safe("res://scenes/Main.tscn")
	if not h.assert_not_null(packed, "Main.tscn must exist"):
		h.end_test()
		return
	var root = packed.instantiate()
	var sv = root.find_child("SubViewport", true, false) as SubViewport
	if h.assert_not_null(sv, "Main.tscn must contain a SubViewport"):
		h.assert_eq(sv.size, Vector2i(320, 200), "SubViewport size must be 320x200")
		h.assert_eq(sv.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "SubViewport texture filter must be Nearest")
	root.queue_free()
	h.end_test()


func _test_t1_postprocess_shader(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M1_retro_quantize_fog_shader")
	h.assert_true(ResourceLoader.exists("res://shaders/retro_quantize_fog.gdshader"), "retro_quantize_fog.gdshader must exist")
	var shader = load("res://shaders/retro_quantize_fog.gdshader") as Shader
	h.assert_not_null(shader, "Shader must load as Shader resource")
	h.end_test()


func _test_t1_autoload_eventbus_signals(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M1_eventbus_10_required_signals")
	var eb = h.get_autoload(tree, "EventBus")
	if not h.assert_not_null(eb, "EventBus autoload must be registered"):
		h.end_test()
		return
	var required_signals = [
		"item_picked_up",
		"quest_updated",
		"combat_log_entry",
		"minigame_requested",
		"minigame_completed",
		"player_stats_changed",
		"equipment_changed",
		"level_up",
		"enemy_killed",
		"dialogue_topic_visited",
	]
	for sig in required_signals:
		h.assert_true(eb.has_signal(sig), "EventBus missing signal: %s" % sig)
	h.end_test()


func _test_t1_autoload_gamestate(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M1_gamestate_flags_and_reputation")
	h.reset_singletons(tree)
	var gs = h.get_autoload(tree, "GameState")
	if not h.assert_not_null(gs, "GameState autoload must be registered"):
		h.end_test()
		return
	gs.set_flag("lockdown_lifted", true)
	h.assert_true(gs.get_flag("lockdown_lifted", false), "get_flag should return true after set_flag")
	gs.modify_reputation("mining_union", 15)
	h.assert_eq(gs.faction_reputation.get("mining_union", 0), 15, "Reputation should increase by 15")
	h.reset_singletons(tree)
	h.end_test()


func _test_t1_autoload_playerstats_defaults(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M1_playerstats_contract_and_defaults")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	if not h.assert_not_null(ps, "PlayerStats autoload must be registered"):
		h.end_test()
		return
	h.assert_ge(ps.level, 1, "Initial level >= 1")
	h.assert_has(ps.attributes, "grit", "attributes must have grit")
	h.assert_has(ps.attributes, "reflex", "attributes must have reflex")
	h.assert_has(ps.attributes, "tech", "attributes must have tech")
	h.assert_has(ps.attributes, "guile", "attributes must have guile")
	h.assert_gt(ps.max_hp, 0, "max_hp must be > 0")
	h.end_test()


func _test_t1_player_controller_and_rays(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M1_player_characterbody_camera_and_rays")
	var packed = h.load_scene_safe("res://scenes/player/Player.tscn")
	if not h.assert_not_null(packed, "Player.tscn must exist"):
		h.end_test()
		return
	var player = packed.instantiate()
	h.assert_true(player is CharacterBody3D, "Player root must be CharacterBody3D")
	var cam = player.find_child("Camera3D", true, false)
	h.assert_not_null(cam, "Player must have Camera3D")
	var interact_ray = player.find_child("InteractRay", true, false) as RayCast3D
	h.assert_not_null(interact_ray, "Player must have InteractRay")
	var weapon_ray = player.find_child("WeaponRay", true, false) as RayCast3D
	h.assert_not_null(weapon_ray, "Player must have WeaponRay")
	player.queue_free()
	h.end_test()


func _test_t1_billboard_8dir(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M1_billboard_8dir_fixed_y")
	var script = h.load_script_safe("res://scripts/visuals/Billboard8Dir.gd")
	if not h.assert_not_null(script, "Billboard8Dir.gd must exist"):
		h.end_test()
		return
	var sprite = Sprite3D.new()
	sprite.set_script(script)
	sprite.vframes = 8
	if sprite.has_method("_ready"):
		sprite._ready()
	h.assert_eq(sprite.billboard, BaseMaterial3D.BILLBOARD_FIXED_Y, "Billboard8Dir must use BILLBOARD_FIXED_Y")
	sprite.queue_free()
	h.end_test()


func _test_t2_gamestate_missing_flag_and_negative_rep(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M1_gamestate_missing_flag_default_and_negative_rep")
	h.reset_singletons(tree)
	var gs = h.get_autoload(tree, "GameState")
	if not h.assert_not_null(gs, "GameState autoload required"):
		h.end_test()
		return
	h.assert_eq(gs.get_flag("nonexistent_flag", "fallback"), "fallback", "Missing flag must return default")
	gs.modify_reputation("corp_security", -25)
	h.assert_eq(gs.faction_reputation.get("corp_security", 0), -25, "Negative reputation delta must be supported")
	h.reset_singletons(tree)
	h.end_test()


func _test_t2_billboard_zero_vector_and_cardinals(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M1_billboard_8dir_cardinal_angles")
	var script = h.load_script_safe("res://scripts/visuals/Billboard8Dir.gd")
	if not h.assert_not_null(script, "Billboard8Dir.gd required"):
		h.end_test()
		return
	var sprite = Sprite3D.new()
	sprite.set_script(script)
	sprite.vframes = 8
	if h.assert_true(sprite.has_method("compute_direction_row"), "Billboard8Dir must expose compute_direction_row()"):
		var row_front: int = sprite.compute_direction_row(Vector3.FORWARD, Vector3.BACK)
		var row_back: int = sprite.compute_direction_row(Vector3.FORWARD, Vector3.FORWARD)
		h.assert_ne(row_front, row_back, "Front and back camera vectors must map to different rows")
		h.assert_ge(row_front, 0)
		h.assert_lt(row_front, 8)
		var row_zero: int = sprite.compute_direction_row(Vector3.ZERO, Vector3.ZERO)
		h.assert_ge(row_zero, 0, "Zero vector must not produce negative row")
		h.assert_lt(row_zero, 8, "Zero vector must stay within 0..7")
	sprite.queue_free()
	h.end_test()


func _test_t2_player_ray_ranges_boundary(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M1_player_ray_target_position_ranges")
	var packed = h.load_scene_safe("res://scenes/player/Player.tscn")
	if not h.assert_not_null(packed, "Player.tscn required"):
		h.end_test()
		return
	var player = packed.instantiate()
	var interact_ray = player.find_child("InteractRay", true, false) as RayCast3D
	var weapon_ray = player.find_child("WeaponRay", true, false) as RayCast3D
	if interact_ray != null:
		h.assert_approx(interact_ray.target_position.length(), 2.5, 0.1, "InteractRay range must be ~2.5m")
	if weapon_ray != null:
		h.assert_ge(weapon_ray.target_position.length(), 2.2, "WeaponRay range must be >= 2.2m")
		h.assert_le(weapon_ray.target_position.length(), 50.5, "WeaponRay range must be <= 50m")
	player.queue_free()
	h.end_test()
