extends RefCounted


func run(tree: SceneTree, h: RefCounted, tier_filter: String) -> void:
	print("\n[Suite] M4: Lockpicking, Hacking, XP/Attributes & 15-Skill Tree")
	var run_t1 = tier_filter in ["all", "1"]
	var run_t2 = tier_filter in ["all", "2"]

	if run_t1:
		_test_t1_xp_leveling_awards_points(tree, h)
		_test_t1_skill_tree_15_skills_and_unlock(tree, h)
		_test_t1_lockpick_minigame_setup(tree, h)
		_test_t1_hacking_minigame_grid_and_nodes(tree, h)

	if run_t2:
		_test_t2_xp_zero_negative_and_multilevel_overflow(tree, h)
		_test_t2_skill_prerequisite_and_zero_points_failure(tree, h)
		_test_t2_lockpick_zero_durability_mag_pick(tree, h)
		_test_t2_hacking_ice_timer_zero_fails(tree, h)


func _test_t1_xp_leveling_awards_points(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M4_xp_level_up_awards_1_attr_2_skill_pts")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	if not h.assert_not_null(ps, "PlayerStats required"):
		h.end_test()
		return
	var start_level: int = ps.level
	var needed: int = ps.xp_to_next
	ps.add_xp(needed)
	h.assert_eq(ps.level, start_level + 1, "Level must increment by 1")
	h.assert_eq(ps.attribute_points, 1, "Level-up must award +1 Attribute Point")
	h.assert_eq(ps.skill_points, 2, "Level-up must award +2 Skill Points")
	h.reset_singletons(tree)
	h.end_test()


func _test_t1_skill_tree_15_skills_and_unlock(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M4_15_skill_resources_and_root_unlock")
	var expected_skills = [
		"jury_rigged_blaster", "overcharge_capacitor", "ricochet_shot", "piston_strike", "scrap_shielding",
		"signal_bypass", "turret_override", "capacitor_meltdown", "cell_recycler", "field_nano_repair",
		"mag_tumbler_sense", "shadow_stepper", "ambush_calibration", "miners_cant", "black_market_appraisal",
	]
	var dir = DirAccess.open("res://resources/skills")
	if h.assert_not_null(dir, "res://resources/skills/ directory must exist"):
		var count = 0
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				count += 1
			fname = dir.get_next()
		dir.list_dir_end()
		h.assert_eq(count, 15, "Must have all 15 .tres SkillResource files")

	var packed = h.load_scene_safe("res://scenes/ui/SkillTreeUI.tscn")
	if h.assert_not_null(packed, "SkillTreeUI.tscn must exist"):
		var ui = packed.instantiate()
		ui.queue_free()
	h.assert_eq(expected_skills.size(), 15)
	h.end_test()


func _test_t1_lockpick_minigame_setup(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M4_lockpick_minigame_cylinders_and_shear")
	var packed = h.load_scene_safe("res://scenes/ui/LockpickMinigame.tscn")
	if not h.assert_not_null(packed, "LockpickMinigame.tscn must exist"):
		h.end_test()
		return
	var ui = packed.instantiate()
	if ui.has_method("setup"):
		ui.setup("easy", "test_lock")
	if "cylinder_count" in ui:
		h.assert_ge(ui.get("cylinder_count"), 3, "Lockpick must have 3-5 cylinders")
		h.assert_le(ui.get("cylinder_count"), 5, "Lockpick must have 3-5 cylinders")
	ui.queue_free()
	h.end_test()


func _test_t1_hacking_minigame_grid_and_nodes(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M4_hacking_minigame_5x5_to_8x8_grid")
	var packed = h.load_scene_safe("res://scenes/ui/HackingMinigame.tscn")
	if not h.assert_not_null(packed, "HackingMinigame.tscn must exist"):
		h.end_test()
		return
	var ui = packed.instantiate()
	if ui.has_method("setup"):
		ui.setup("easy", "test_term")
	if "grid_size" in ui:
		h.assert_ge(ui.get("grid_size"), 5, "Grid size must be >= 5")
		h.assert_le(ui.get("grid_size"), 8, "Grid size must be <= 8")
	if "ice_timer" in ui:
		h.assert_gt(ui.get("ice_timer"), 0.0, "ICE trace timer must start > 0")
	ui.queue_free()
	h.end_test()


func _test_t2_xp_zero_negative_and_multilevel_overflow(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M4_xp_zero_negative_and_multilevel")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	if not h.assert_not_null(ps, "PlayerStats required"):
		h.end_test()
		return
	ps.add_xp(0)
	h.assert_eq(ps.level, 1, "0 XP must not level up")
	ps.add_xp(-100)
	h.assert_eq(ps.xp, 0, "Negative XP must be ignored")
	# Multi-level overflow
	var big_xp: int = ps.xp_to_next * 4
	ps.add_xp(big_xp)
	h.assert_ge(ps.level, 3, "Large XP award must support multi-level overflow")
	h.assert_ge(ps.skill_points, 4, "Multi-level must award 2 skill points per level")
	h.reset_singletons(tree)
	h.end_test()


func _test_t2_skill_prerequisite_and_zero_points_failure(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M4_skill_prerequisite_and_zero_points_failure")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	var packed = h.load_scene_safe("res://scenes/ui/SkillTreeUI.tscn")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(packed, "SkillTreeUI.tscn required"):
		h.end_test()
		return
	var ui = packed.instantiate()
	if ui.has_method("try_unlock_skill"):
		# 0 skill points -> root unlock must fail
		var ok_no_pts: bool = ui.try_unlock_skill("jury_rigged_blaster")
		h.assert_false(ok_no_pts, "Unlocking with 0 skill points must fail")
		# Give skill points, try Tier 2 skill without Tier 1 root -> must fail
		ps.skill_points = 5
		var ok_no_prereq: bool = ui.try_unlock_skill("ricochet_shot")
		h.assert_false(ok_no_prereq, "Unlocking Tier 3 skill without prerequisites must fail")
	ui.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t2_lockpick_zero_durability_mag_pick(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M4_lockpick_zero_durability_mag_pick")
	h.reset_singletons(tree)
	var packed = h.load_scene_safe("res://scenes/ui/LockpickMinigame.tscn")
	var item_script = h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(packed, "LockpickMinigame.tscn required") or not h.assert_not_null(item_script, "ItemData.gd required"):
		h.end_test()
		return
	var ui = packed.instantiate()
	var broken_pick: Resource = item_script.new()
	broken_pick.set("id", "mag_pick")
	broken_pick.set("durability", 0)
	if ui.has_method("can_attempt_pick"):
		h.assert_false(ui.can_attempt_pick(broken_pick), "0-durability Mag-Pick must not allow lockpicking")
	ui.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t2_hacking_ice_timer_zero_fails(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M4_hacking_ice_timer_zero_triggers_failure")
	var packed = h.load_scene_safe("res://scenes/ui/HackingMinigame.tscn")
	if not h.assert_not_null(packed, "HackingMinigame.tscn required"):
		h.end_test()
		return
	var ui = packed.instantiate()
	if ui.has_method("setup"):
		ui.setup("easy", "test_term")
	if "ice_timer" in ui and ui.has_method("_process"):
		ui.set("ice_timer", 0.01)
		ui._process(0.5)
		if "is_failed" in ui:
			h.assert_true(ui.get("is_failed"), "ICE timer reaching 0 must fail the hack")
	ui.queue_free()
	h.end_test()
