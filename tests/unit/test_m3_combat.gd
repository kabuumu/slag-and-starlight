extends RefCounted


func run(tree: SceneTree, h: RefCounted, tier_filter: String) -> void:
	print("\n[Suite] M3: 2D Weapon View, Blaster d100, Directional Melee & Enemy FSM")
	var run_t1 = tier_filter in ["all", "1"]
	var run_t2 = tier_filter in ["all", "2"]

	if run_t1:
		_test_t1_weapon_view_2d_bobbing(tree, h)
		_test_t1_blaster_hit_chance_formula(tree, h)
		_test_t1_directional_melee_modifiers(tree, h)
		_test_t1_enemy_archetype_scenes_load(tree, h)
		_test_t1_enemy_hitbox_and_fsm_transitions(tree, h)
		_test_t1_breakable_crate_exists(tree, h)

	if run_t2:
		_test_t2_blaster_hit_chance_clamped_5_to_95(tree, h)
		_test_t2_blaster_overheat_and_zero_power_cells(tree, h)
		_test_t2_enemy_dead_state_ignores_damage(tree, h)
		_test_t2_melee_drag_below_threshold(tree, h)


func _test_t1_weapon_view_2d_bobbing(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M3_weapon_view_2d_bobbing")
	var script = h.load_script_safe("res://scripts/player/WeaponView2D.gd")
	if not h.assert_not_null(script, "WeaponView2D.gd must exist"):
		h.end_test()
		return
	var node = AnimatedSprite2D.new()
	node.set_script(script)
	if node.has_method("compute_bob_offset"):
		var idle_off: Vector2 = node.compute_bob_offset(0.0, 1.0)
		var move_off: Vector2 = node.compute_bob_offset(6.0, 0.5)
		h.assert_approx(idle_off.length(), 0.0, 0.01, "Zero velocity should produce zero bob")
		h.assert_gt(move_off.length(), 0.0, "Non-zero velocity should produce sine-wave bob")
	node.queue_free()
	h.end_test()


func _test_t1_blaster_hit_chance_formula(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M3_blaster_hit_chance_formula")
	var pc_script = h.load_script_safe("res://scripts/player/PlayerController.gd")
	if not h.assert_not_null(pc_script, "PlayerController.gd must exist"):
		h.end_test()
		return
	var pc = CharacterBody3D.new()
	pc.set_script(pc_script)
	if pc.has_method("calculate_blaster_hit_chance"):
		# Base 65 + (skill 10 * 2) - (dist 10 * 0.8) - evasion 5 = 65 + 20 - 8 - 5 = 72
		var chance: float = pc.calculate_blaster_hit_chance(65.0, 10, 10.0, 5.0)
		h.assert_approx(chance, 72.0, 0.1, "Hit chance formula must match Base + 2*Skill - 0.8*Dist - Evasion")
	pc.queue_free()
	h.end_test()


func _test_t1_directional_melee_modifiers(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M3_directional_melee_modifiers")
	var pc_script = h.load_script_safe("res://scripts/player/PlayerController.gd")
	if not h.assert_not_null(pc_script, "PlayerController.gd must exist"):
		h.end_test()
		return
	var pc = CharacterBody3D.new()
	pc.set_script(pc_script)
	if pc.has_method("get_melee_swing_modifiers"):
		var thrust: Dictionary = pc.get_melee_swing_modifiers(Vector2(0, -40)) # Up -> Thrust
		var overhead: Dictionary = pc.get_melee_swing_modifiers(Vector2(0, 40)) # Down -> Overhead Chop
		var slash: Dictionary = pc.get_melee_swing_modifiers(Vector2(-40, 0)) # Left -> Side Slash
		h.assert_eq(thrust.get("hit_mod", 0), 15, "Thrust must give +15% To-Hit")
		h.assert_approx(thrust.get("dmg_mult", 1.0), 0.8, 0.01, "Thrust must give -20% Damage (0.8x)")
		h.assert_eq(overhead.get("hit_mod", 0), -15, "Overhead must give -15% To-Hit")
		h.assert_approx(overhead.get("dmg_mult", 1.0), 1.3, 0.01, "Overhead must give +30% Damage (1.3x)")
		h.assert_eq(slash.get("hit_mod", -99), 0, "Side slash must give 0% To-Hit mod")
		h.assert_approx(slash.get("dmg_mult", 0.0), 1.0, 0.01, "Side slash must give 1.0x Damage")
	pc.queue_free()
	h.end_test()


func _test_t1_enemy_archetype_scenes_load(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M3_all_5_enemy_archetype_scenes")
	var scenes = [
		"res://scenes/enemies/SlagTick.tscn",
		"res://scenes/enemies/MiningDrone.tscn",
		"res://scenes/enemies/FeralDriller.tscn",
		"res://scenes/enemies/SentryTurret.tscn",
		"res://scenes/enemies/Unit734B.tscn",
	]
	for path in scenes:
		var packed = h.load_scene_safe(path)
		if h.assert_not_null(packed, "Missing enemy scene: %s" % path):
			var inst = packed.instantiate()
			h.assert_not_null(inst, "Failed to instantiate %s" % path)
			var bb := inst.get_node_or_null("Billboard8Dir") as Sprite3D
			if h.assert_not_null(bb, "%s must have Billboard8Dir Sprite3D" % path):
				h.assert_eq(bb.hframes, 4, "%s Billboard8Dir must have hframes = 4" % path)
				h.assert_eq(bb.vframes, 8, "%s Billboard8Dir must have vframes = 8" % path)
			inst.queue_free()
	h.end_test()


func _test_t1_enemy_hitbox_and_fsm_transitions(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M3_enemy_hitbox_contract_and_fsm")
	var hb_script = h.load_script_safe("res://scripts/combat/EnemyHitbox.gd")
	var enemy_script = h.load_script_safe("res://scripts/combat/EnemyBase.gd")
	if not h.assert_not_null(hb_script, "EnemyHitbox.gd required") or not h.assert_not_null(enemy_script, "EnemyBase.gd required"):
		h.end_test()
		return
	var enemy = CharacterBody3D.new()
	enemy.set_script(enemy_script)
	if "hp" in enemy and "max_hp" in enemy:
		enemy.set("max_hp", 30)
		enemy.set("hp", 30)
	var hb = Area3D.new()
	hb.set_script(hb_script)
	h.assert_true("evasion" in hb, "EnemyHitbox must have evasion")
	h.assert_true("enemy_id" in hb, "EnemyHitbox must have enemy_id")
	h.assert_true("is_unaware" in hb, "EnemyHitbox must have is_unaware")
	h.assert_true(hb.has_method("take_damage"), "EnemyHitbox must have take_damage()")
	enemy.add_child(hb)
	hb.take_damage(30, "blaster", false)
	if "hp" in enemy:
		h.assert_le(enemy.get("hp"), 0, "30 damage must reduce 30 HP enemy to <= 0")
	enemy.queue_free()
	h.end_test()


func _test_t1_breakable_crate_exists(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M3_breakable_crate_script")
	var crate_script = h.load_script_safe("res://scripts/combat/BreakableCrate.gd")
	h.assert_not_null(crate_script, "BreakableCrate.gd must exist")
	h.end_test()


func _test_t2_blaster_hit_chance_clamped_5_to_95(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M3_blaster_hit_chance_clamped_5_to_95")
	var pc_script = h.load_script_safe("res://scripts/player/PlayerController.gd")
	if not h.assert_not_null(pc_script, "PlayerController.gd required"):
		h.end_test()
		return
	var pc = CharacterBody3D.new()
	pc.set_script(pc_script)
	if pc.has_method("calculate_blaster_hit_chance"):
		var max_c: float = pc.calculate_blaster_hit_chance(150.0, 50, 0.0, 0.0)
		var min_c: float = pc.calculate_blaster_hit_chance(10.0, 0, 500.0, 80.0)
		h.assert_le(max_c, 95.0, "Hit chance must clamp at <= 95%")
		h.assert_ge(min_c, 5.0, "Hit chance must clamp at >= 5%")
	pc.queue_free()
	h.end_test()


func _test_t2_blaster_overheat_and_zero_power_cells(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M3_blaster_overheat_and_zero_power_cells")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	var pc_script = h.load_script_safe("res://scripts/player/PlayerController.gd")
	if not h.assert_not_null(pc_script, "PlayerController.gd required"):
		h.end_test()
		return
	var pc = CharacterBody3D.new()
	pc.set_script(pc_script)
	tree.root.add_child(pc)
	if h.assert_true(pc.has_method("reload_power_cell"), "PlayerController must expose reload_power_cell()"):
		var reloaded: bool = pc.reload_power_cell()
		h.assert_false(reloaded, "Reloading with 0 Power Cells in backpack must return false")
	if pc.has_method("_fire_blaster") and ps != null:
		ps.suit_power = 0.0
		pc._fire_blaster(true)
		h.assert_approx(pc.current_heat, pc.heat_per_shot, 0.01, "Overcharged shot with 0 suit_power must downgrade to normal 1x heat")
		for i in range(6):
			pc._fire_blaster(false)
		h.assert_true(pc.is_overheated, "Firing blaster past max_heat must set is_overheated = true")
		h.assert_ge(pc.current_heat, pc.max_heat, "Overheated blaster heat must reach max_heat")
	tree.root.remove_child(pc)
	pc.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t2_enemy_dead_state_ignores_damage(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M3_dead_enemy_ignores_further_damage")
	var enemy_script = h.load_script_safe("res://scripts/combat/EnemyBase.gd")
	if not h.assert_not_null(enemy_script, "EnemyBase.gd required"):
		h.end_test()
		return
	var enemy = CharacterBody3D.new()
	enemy.set_script(enemy_script)
	if "hp" in enemy:
		enemy.set("hp", 0)
	if enemy.has_method("die"):
		enemy.die()
	if enemy.has_method("take_damage"):
		enemy.take_damage(50, "blaster", false)
		h.assert_eq(enemy.get("hp"), 0, "Dead enemy HP must remain 0")
	enemy.queue_free()
	h.end_test()


func _test_t2_melee_drag_below_threshold(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M3_melee_drag_below_threshold_none")
	var pc_script = h.load_script_safe("res://scripts/player/PlayerController.gd")
	if not h.assert_not_null(pc_script, "PlayerController.gd required"):
		h.end_test()
		return
	var pc = CharacterBody3D.new()
	pc.set_script(pc_script)
	if pc.has_method("get_melee_swing_modifiers"):
		var tiny: Dictionary = pc.get_melee_swing_modifiers(Vector2(1, 1))
		h.assert_eq(tiny.get("direction", "none"), "none", "Tiny mouse drag below threshold must not trigger swing")
	pc.queue_free()
	h.end_test()
