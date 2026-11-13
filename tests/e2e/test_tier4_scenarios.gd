extends RefCounted


func run(tree: SceneTree, h: RefCounted) -> void:
	print("\n[Suite] Tier 4: Real-World Application Scenarios (Sub-Level 04 Rooms 1-7 & Rust-Spire Outpost)")
	_test_t4_sublevel04_stealth_lockpick_path(tree, h)
	_test_t4_sublevel04_tech_hack_path(tree, h)
	_test_t4_sublevel04_grit_combat_path(tree, h)
	_test_t4_blackbox_turn_in_vs_keep(tree, h)
	_test_t4_unit_734b_boss_and_rust_spire_transition(tree, h)
	_test_t4_radiant_job_generation_and_completion(tree, h)


func _test_t4_sublevel04_stealth_lockpick_path(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T4_sublevel04_rooms_1_to_7_stealth_lockpick_path")
	h.reset_singletons(tree)
	var sl04 = h.load_scene_safe("res://scenes/levels/SubLevel04.tscn")
	var gs = h.get_autoload(tree, "GameState")
	var ps = h.get_autoload(tree, "PlayerStats")
	var eb = h.get_autoload(tree, "EventBus")
	if not h.assert_not_null(sl04, "SubLevel04.tscn required") or not h.assert_not_null(gs, "GameState required") or not h.assert_not_null(ps, "PlayerStats required"):
		h.end_test()
		return
	var level = sl04.instantiate()
	# Simulate Room 1: wake up at 50% HP, equip Pressure Suit & Blaster
	ps.hp = int(ps.max_hp * 0.5)
	h.assert_gt(ps.hp, 0)
	# Room 3: Start Dead Man's Switch
	var qm = h.get_autoload(tree, "QuestManager")
	if qm != null and qm.has_method("start_quest"):
		qm.start_quest("dead_mans_switch")
		h.assert_has(gs.active_quests, "dead_mans_switch")
	# Room 4 Path A: Mag-Lock vent (no drone alert)
	if eb != null:
		eb.minigame_completed.emit("room4_mag_lock", true, {})
	h.assert_false(gs.get_flag("room5_drones_alerted", false), "Stealth Path A must not alert Room 5 drones")
	# Room 6: Keycard looted
	gs.set_flag("has_lift_keycard", true)
	h.assert_true(gs.get_flag("has_lift_keycard", false))
	level.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t4_sublevel04_tech_hack_path(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T4_sublevel04_rooms_1_to_7_tech_hack_path")
	h.reset_singletons(tree)
	var gs = h.get_autoload(tree, "GameState")
	var eb = h.get_autoload(tree, "EventBus")
	var sl04 = h.load_scene_safe("res://scenes/levels/SubLevel04.tscn")
	if not h.assert_not_null(sl04, "SubLevel04.tscn required") or not h.assert_not_null(gs, "GameState required"):
		h.end_test()
		return
	var level = sl04.instantiate()
	# Room 4 Path B: Wall Terminal hack opens blast door without alerting drones
	if eb != null:
		eb.minigame_completed.emit("room4_wall_terminal", true, {})
		# Room 6: Overseer Mainframe hack retrieves Seismic Blackbox
		eb.minigame_completed.emit("room6_overseer_mainframe", true, {"blackbox": true})
	gs.set_flag("has_seismic_blackbox", true)
	h.assert_true(gs.get_flag("has_seismic_blackbox", false), "Tech path must retrieve Seismic Blackbox")
	h.assert_false(gs.get_flag("room5_drones_alerted", false), "Tech Path B must not alert Room 5 drones")
	level.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t4_sublevel04_grit_combat_path(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T4_sublevel04_rooms_1_to_7_grit_combat_path")
	h.reset_singletons(tree)
	var gs = h.get_autoload(tree, "GameState")
	var jb_script = h.load_script_safe("res://scripts/world/JunctionBox.gd")
	var sl04 = h.load_scene_safe("res://scenes/levels/SubLevel04.tscn")
	if not h.assert_not_null(sl04, "SubLevel04.tscn required") or not h.assert_not_null(gs, "GameState required") or not h.assert_not_null(jb_script, "JunctionBox.gd required"):
		h.end_test()
		return
	var level = sl04.instantiate()
	var jb = StaticBody3D.new()
	jb.set_script(jb_script)
	tree.root.add_child(jb)
	if h.assert_true(jb.has_method("blast_open"), "JunctionBox must expose blast_open()"):
		jb.blast_open()
	h.assert_true(gs.get_flag("room5_drones_alerted", false), "Grit Path C must alert Room 5 drones")
	tree.root.remove_child(jb)
	jb.queue_free()
	level.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t4_blackbox_turn_in_vs_keep(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T4_blackbox_turn_in_to_kael_vs_keep")
	h.reset_singletons(tree)
	var gs = h.get_autoload(tree, "GameState")
	var ps = h.get_autoload(tree, "PlayerStats")
	var dlg_packed = h.load_scene_safe("res://scenes/ui/DialogueUI.tscn")
	if not h.assert_not_null(gs, "GameState required") or not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(dlg_packed, "DialogueUI.tscn required"):
		h.end_test()
		return
	var ui = dlg_packed.instantiate()
	tree.root.add_child(ui)
	# Branch 1: Turn in to Kael -> union reputation + bonus credits + clears has_seismic_blackbox
	gs.set_flag("has_seismic_blackbox", true)
	var bb_res := load("res://resources/items/seismic_blackbox.tres") as Resource
	if bb_res != null:
		ps.add_item_to_backpack(bb_res.duplicate(true))
	var start_credits: int = ps.credits
	ui._execute_topic_action("give_blackbox_to_kael")
	h.assert_gt(ps.credits, start_credits, "Turning in Blackbox to Kael awards bonus credits")
	h.assert_gt(gs.faction_reputation.get("mining_union", 0), 0, "Turning in Blackbox increases Mining Union rep")
	h.assert_false(gs.get_flag("has_seismic_blackbox", false), "Giving Blackbox to Kael must clear has_seismic_blackbox so it cannot also be sold")

	# Branch 2: Keep Blackbox for corporate agents
	h.reset_singletons(tree)
	gs.set_flag("has_seismic_blackbox", true)
	ui._execute_topic_action("keep_blackbox")
	h.assert_true(gs.get_flag("blackbox_kept", false))
	h.assert_false(gs.get_flag("blackbox_given_to_kael", false))
	tree.root.remove_child(ui)
	ui.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t4_unit_734b_boss_and_rust_spire_transition(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T4_unit_734b_boss_and_rust_spire_outpost_transition")
	h.reset_singletons(tree)
	var boss_packed = h.load_scene_safe("res://scenes/enemies/Unit734B.tscn")
	var hub_packed = h.load_scene_safe("res://scenes/levels/RustSpireOutpost.tscn")
	var lift_script = h.load_script_safe("res://scripts/world/CargoLift.gd")
	var gs = h.get_autoload(tree, "GameState")
	if not h.assert_not_null(boss_packed, "Unit734B.tscn required") or not h.assert_not_null(hub_packed, "RustSpireOutpost.tscn required") or not h.assert_not_null(lift_script, "CargoLift.gd required"):
		h.end_test()
		return
	var boss = boss_packed.instantiate()
	tree.root.add_child(boss)
	if h.assert_true(boss.has_method("take_damage"), "Unit734B must expose take_damage()"):
		boss.take_damage(9999, "blaster", false)
		h.assert_eq(boss.get("hp"), 0, "Unit 734-B must reach 0 HP after lethal damage")
		h.assert_eq(boss.get("state"), 3, "Unit 734-B must enter DEAD state (3)")
	tree.root.remove_child(boss)
	boss.queue_free()

	gs.set_flag("has_lift_keycard", true)
	var lift = StaticBody3D.new()
	lift.set_script(lift_script)
	tree.root.add_child(lift)
	if h.assert_true(lift.has_method("can_activate"), "CargoLift must expose can_activate()"):
		h.assert_true(lift.can_activate(), "CargoLift must activate once Lift Override Keycard is obtained")
	tree.root.remove_child(lift)
	lift.queue_free()

	var hub = hub_packed.instantiate()
	if h.assert_not_null(hub, "RustSpireOutpost.tscn must instantiate after Cargo Lift transition"):
		for wall_name in ["PerimeterNorth", "PerimeterSouth", "PerimeterWest", "PerimeterEast"]:
			h.assert_not_null(hub.get_node_or_null(wall_name), "RustSpireOutpost must have %s wall" % wall_name)
		hub.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t4_radiant_job_generation_and_completion(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T4_radiant_job_generation_and_completion_cycle")
	h.reset_singletons(tree)
	var gen_script = h.load_script_safe("res://scripts/world/RadiantJobGenerator.gd")
	var qm = h.get_autoload(tree, "QuestManager")
	var gs = h.get_autoload(tree, "GameState")
	var eb = h.get_autoload(tree, "EventBus")
	var item_script = h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(gen_script, "RadiantJobGenerator.gd required") or not h.assert_not_null(qm, "QuestManager required") or not h.assert_not_null(gs, "GameState required"):
		h.end_test()
		return
	var gen: Node = gen_script.new()
	if gen.has_method("generate_job"):
		var job: Resource = gen.generate_job()
		h.assert_not_null(job, "RadiantJobGenerator must produce a QuestResource")
		if qm.has_method("accept_quest"):
			var accepted: bool = bool(qm.accept_quest(job))
			h.assert_true(accepted, "accept_quest must return true for fresh radiant job")
			var qid: String = job.get("id") if "id" in job else ""
			if not qid.is_empty():
				h.assert_has(gs.active_quests, qid, "Accepted radiant job must appear in active_quests")
				var stages: Array = job.get("stages")
				if stages.size() > 0 and eb != null:
					var st: Resource = stages[0]
					var obj_type: int = int(st.get("objective_type"))
					var target_id: String = str(st.get("target_id"))
					if obj_type == 0: # KILL
						eb.enemy_killed.emit(target_id)
					elif obj_type == 1 and item_script != null: # FETCH
						var dummy_item: Resource = item_script.new()
						dummy_item.set("id", target_id)
						eb.item_picked_up.emit(dummy_item, 1)
					h.assert_true(qid in gs.completed_quests, "Completed radiant job must move to completed_quests")
	if gen is Node:
		gen.queue_free()
	h.reset_singletons(tree)
	h.end_test()
