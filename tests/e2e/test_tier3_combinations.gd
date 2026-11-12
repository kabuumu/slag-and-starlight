extends RefCounted


func run(tree: SceneTree, h: RefCounted) -> void:
	print("\n[Suite] Tier 3: Cross-Feature Combinations")
	_test_t3_servo_grip_mag_tumbler_sense_and_guile_lockpick(tree, h)
	_test_t3_scrap_shielding_with_torso_locational_hit(tree, h)
	_test_t3_cell_recycler_power_cell_reload(tree, h)
	_test_t3_turret_override_in_room6(tree, h)
	_test_t3_room4_paths_abc_to_room5_drone_alert(tree, h)
	_test_t3_miners_cant_in_dialogue(tree, h)
	_test_t3_ambush_calibration_and_piston_strike(tree, h)


func _test_t3_servo_grip_mag_tumbler_sense_and_guile_lockpick(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T3_servo_grip_plus_mag_tumbler_sense_plus_guile_lockpick")
	h.reset_singletons(tree)
	var ps := h.get_autoload(tree, "PlayerStats")
	var lp_packed := h.load_scene_safe("res://scenes/ui/LockpickMinigame.tscn")
	var item_script := h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(lp_packed, "LockpickMinigame.tscn required"):
		h.end_test()
		return

	var lp_base := lp_packed.instantiate()
	tree.root.add_child(lp_base)
	if h.assert_true(lp_base.has_method("get_effective_tolerance"), "LockpickMinigame must expose get_effective_tolerance()"):
		var base_tol: float = lp_base.get_effective_tolerance()
		# Equip Servo-Grip Gauntlets, unlock Mag-Tumbler Sense, raise Guile
		if item_script != null:
			var gauntlets: Resource = item_script.new()
			gauntlets.set("id", "servo_grip_gauntlets")
			gauntlets.set("slot_type", 4)
			ps.equipped_items[4] = gauntlets
		ps.unlocked_skills.append("mag_tumbler_sense")
		ps.attributes["guile"] = 12
		ps.recalculate_derived_stats()
		var boosted_tol: float = lp_base.get_effective_tolerance()
		h.assert_gt(boosted_tol, base_tol, "Servo-Grip + Mag-Tumbler Sense + Guile must widen lockpick tolerance")
	tree.root.remove_child(lp_base)
	lp_base.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t3_scrap_shielding_with_torso_locational_hit(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T3_scrap_shielding_plus_torso_locational_hit")
	h.reset_singletons(tree)
	var ps := h.get_autoload(tree, "PlayerStats")
	var item_script := h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(item_script, "ItemData.gd required"):
		h.end_test()
		return
	var torso: Resource = item_script.new()
	torso.set("id", "heavy_plating")
	torso.set("slot_type", 2)
	torso.set("armor_rating", 20)
	torso.set("durability", 50)
	ps.equipped_items[2] = torso
	ps.recalculate_derived_stats()
	var armor_without: int = ps.total_armor

	ps.unlocked_skills.append("scrap_shielding")
	ps.recalculate_derived_stats()
	var armor_with: int = ps.total_armor
	h.assert_ge(armor_with, int(floor(armor_without * 1.15)), "Scrap Shielding must add +15% Torso armor rating")
	h.reset_singletons(tree)
	h.end_test()


func _test_t3_cell_recycler_power_cell_reload(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T3_cell_recycler_blaster_reload_preservation")
	h.reset_singletons(tree)
	var ps := h.get_autoload(tree, "PlayerStats")
	var pc_script := h.load_script_safe("res://scripts/player/PlayerController.gd")
	var item_script := h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(pc_script, "PlayerController.gd required"):
		h.end_test()
		return
	ps.unlocked_skills.append("cell_recycler")
	# Put 20 power cells in backpack and run 15 reloads; at least 5 remain and < 20 remain
	if item_script != null:
		for i in range(20):
			var cell: Resource = item_script.new()
			cell.set("id", "power_cell")
			ps.backpack_items.append(cell)
	var pc := CharacterBody3D.new()
	pc.set_script(pc_script)
	tree.root.add_child(pc)
	if h.assert_true(pc.has_method("reload_power_cell"), "PlayerController must expose reload_power_cell()"):
		for i in range(15):
			pc.reload_power_cell()
		h.assert_ge(ps.backpack_items.size(), 5, "Cell Recycler must preserve Power Cells during reloads")
		h.assert_lt(ps.backpack_items.size(), 20, "Reloads must actually consume Power Cells")
	tree.root.remove_child(pc)
	pc.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t3_turret_override_in_room6(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T3_turret_override_in_room6")
	h.reset_singletons(tree)
	var ps := h.get_autoload(tree, "PlayerStats")
	var turret_packed := h.load_scene_safe("res://scenes/enemies/SentryTurret.tscn")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(turret_packed, "SentryTurret.tscn required"):
		h.end_test()
		return
	var turret := turret_packed.instantiate()
	tree.root.add_child(turret)
	ps.unlocked_skills.append("turret_override")
	if h.assert_true(turret.has_method("try_override"), "SentryTurret must expose try_override()"):
		var ok: bool = turret.try_override()
		h.assert_true(ok, "Turret Override skill must allow turning SentryTurret friendly")
		if "is_friendly" in turret:
			h.assert_true(turret.get("is_friendly"), "Overridden turret must be marked is_friendly=true")
	tree.root.remove_child(turret)
	turret.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t3_room4_paths_abc_to_room5_drone_alert(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T3_room4_paths_abc_room5_drone_alert")
	h.reset_singletons(tree)
	var gs := h.get_autoload(tree, "GameState")
	var jb_script := h.load_script_safe("res://scripts/world/JunctionBox.gd")
	if not h.assert_not_null(gs, "GameState required") or not h.assert_not_null(jb_script, "JunctionBox.gd required"):
		h.end_test()
		return
	# Path C: blasting JunctionBox opens door AND alerts Room 5 drones
	var jb := StaticBody3D.new()
	jb.set_script(jb_script)
	tree.root.add_child(jb)
	if h.assert_true(jb.has_method("blast_open"), "JunctionBox must expose blast_open()"):
		jb.blast_open()
		h.assert_true(gs.get_flag("room5_drones_alerted", false), "Path C JunctionBox blast must alert Room 5 Mining Drones")
	tree.root.remove_child(jb)
	jb.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t3_miners_cant_in_dialogue(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T3_miners_cant_unlocks_union_dialogue")
	h.reset_singletons(tree)
	var ps := h.get_autoload(tree, "PlayerStats")
	var dlg_packed := h.load_scene_safe("res://scenes/ui/DialogueUI.tscn")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(dlg_packed, "DialogueUI.tscn required"):
		h.end_test()
		return
	var ui := dlg_packed.instantiate()
	tree.root.add_child(ui)
	if h.assert_true(ui.has_method("check_topic_requirement"), "DialogueUI must expose check_topic_requirement()"):
		h.assert_false(ui.check_topic_requirement({"required_skill": "miners_cant"}), "Topic must be locked without Miner's Cant")
		ps.unlocked_skills.append("miners_cant")
		h.assert_true(ui.check_topic_requirement({"required_skill": "miners_cant"}), "Topic must unlock with Miner's Cant")
	tree.root.remove_child(ui)
	ui.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t3_ambush_calibration_and_piston_strike(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T3_ambush_calibration_and_piston_strike")
	h.reset_singletons(tree)
	var ps := h.get_autoload(tree, "PlayerStats")
	var pc_script := h.load_script_safe("res://scripts/player/PlayerController.gd")
	var hb_script := h.load_script_safe("res://scripts/combat/EnemyHitbox.gd")
	var enemy_script := h.load_script_safe("res://scripts/combat/EnemyBase.gd")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(pc_script, "PlayerController.gd required") or not h.assert_not_null(hb_script, "EnemyHitbox.gd required") or not h.assert_not_null(enemy_script, "EnemyBase.gd required"):
		h.end_test()
		return
	ps.unlocked_skills.append("ambush_calibration")
	ps.unlocked_skills.append("piston_strike")
	var pc := CharacterBody3D.new()
	pc.set_script(pc_script)
	tree.root.add_child(pc)
	var enemy := CharacterBody3D.new()
	enemy.set_script(enemy_script)
	if "max_hp" in enemy and "hp" in enemy:
		enemy.set("max_hp", 100)
		enemy.set("hp", 100)
	var hb := Area3D.new()
	hb.set_script(hb_script)
	hb.is_unaware = true
	enemy.add_child(hb)
	tree.root.add_child(enemy)
	var dmg: int = pc.apply_ambush_bonus(20, hb)
	hb.take_damage(dmg, "melee_overhead", true)
	# Ambush Calibration (+50% on unaware) => 30 damage -> HP <= 70, Piston Strike => stagger_timer > 0
	if "hp" in enemy:
		h.assert_le(enemy.get("hp"), 70, "Ambush Calibration must deal +50% damage on unaware target")
	if "stagger_timer" in enemy:
		h.assert_gt(enemy.get("stagger_timer"), 0.0, "Piston Strike must stagger enemy")
	tree.root.remove_child(enemy)
	enemy.queue_free()
	tree.root.remove_child(pc)
	pc.queue_free()
	h.reset_singletons(tree)
	h.end_test()
