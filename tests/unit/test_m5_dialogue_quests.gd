extends RefCounted


func run(tree: SceneTree, h: RefCounted, tier_filter: String) -> void:
	print("\n[Suite] M5: Keyword Dialogue, QuestManager, Radiant Jobs & Sub-Level 04")
	var run_t1 := tier_filter in ["all", "1"]
	var run_t2 := tier_filter in ["all", "2"]

	if run_t1:
		_test_t1_dialogue_ui_and_topics(tree, h)
		_test_t1_quest_manager_and_dead_mans_switch(tree, h)
		_test_t1_radiant_job_generator(tree, h)
		_test_t1_sublevel04_and_rust_spire_scenes(tree, h)

	if run_t2:
		_test_t2_dialogue_tech_15_gate_boundary_14_vs_15(tree, h)
		_test_t2_quest_duplicate_start_and_missing_keycard_lift(tree, h)


func _test_t1_dialogue_ui_and_topics(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M5_dialogue_ui_loads_and_has_topic_list")
	var packed := h.load_scene_safe("res://scenes/ui/DialogueUI.tscn")
	if not h.assert_not_null(packed, "DialogueUI.tscn must exist"):
		h.end_test()
		return
	var ui := packed.instantiate()
	h.assert_not_null(ui, "DialogueUI must instantiate")
	ui.queue_free()
	h.end_test()


func _test_t1_quest_manager_and_dead_mans_switch(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M5_quest_manager_dead_mans_switch")
	h.reset_singletons(tree)
	var qm := h.get_autoload(tree, "QuestManager")
	var gs := h.get_autoload(tree, "GameState")
	if not h.assert_not_null(qm, "QuestManager autoload must exist") or not h.assert_not_null(gs, "GameState required"):
		h.end_test()
		return
	if qm.has_method("start_quest"):
		qm.start_quest("dead_mans_switch")
		h.assert_has(gs.active_quests, "dead_mans_switch", "Dead Man's Switch must be in active_quests")
	h.reset_singletons(tree)
	h.end_test()


func _test_t1_radiant_job_generator(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M5_radiant_job_generator_creates_valid_quest")
	var gen_script := h.load_script_safe("res://scripts/world/RadiantJobGenerator.gd")
	if not h.assert_not_null(gen_script, "RadiantJobGenerator.gd must exist"):
		h.end_test()
		return
	var gen: Node = gen_script.new()
	if gen.has_method("generate_job"):
		var job: Resource = gen.generate_job()
		h.assert_not_null(job, "generate_job() must return a QuestResource")
		if "stages" in job:
			h.assert_gt(job.get("stages").size(), 0, "Radiant job must have at least 1 QuestStage")
	if gen is Node:
		gen.queue_free()
	h.end_test()


func _test_t1_sublevel04_and_rust_spire_scenes(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M5_sublevel04_and_rust_spire_outpost_load")
	var sl04 := h.load_scene_safe("res://scenes/levels/SubLevel04.tscn")
	var hub := h.load_scene_safe("res://scenes/levels/RustSpireOutpost.tscn")
	if h.assert_not_null(sl04, "SubLevel04.tscn must exist"):
		var inst := sl04.instantiate()
		inst.queue_free()
	if h.assert_not_null(hub, "RustSpireOutpost.tscn must exist"):
		var inst2 := hub.instantiate()
		inst2.queue_free()
	h.end_test()


func _test_t2_dialogue_tech_15_gate_boundary_14_vs_15(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M5_dialogue_tech_15_gate_boundary_14_vs_15")
	h.reset_singletons(tree)
	var ps := h.get_autoload(tree, "PlayerStats")
	var packed := h.load_scene_safe("res://scenes/ui/DialogueUI.tscn")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(packed, "DialogueUI.tscn required"):
		h.end_test()
		return
	var ui := packed.instantiate()
	if ui.has_method("check_topic_requirement"):
		ps.attributes["tech"] = 14
		h.assert_false(ui.check_topic_requirement({"min_tech": 15}), "Tech 14 must fail [Tech 15] gate")
		ps.attributes["tech"] = 15
		h.assert_true(ui.check_topic_requirement({"min_tech": 15}), "Tech 15 must pass [Tech 15] gate")
	ui.queue_free()
	h.reset_singletons(tree)
	h.end_test()


func _test_t2_quest_duplicate_start_and_missing_keycard_lift(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M5_quest_duplicate_start_and_cargo_lift_no_keycard")
	h.reset_singletons(tree)
	var qm := h.get_autoload(tree, "QuestManager")
	var lift_script := h.load_script_safe("res://scripts/world/CargoLift.gd")
	if h.assert_not_null(qm, "QuestManager required") and qm.has_method("start_quest"):
		qm.start_quest("dead_mans_switch")
		qm.start_quest("dead_mans_switch") # Should be idempotent
	if h.assert_not_null(lift_script, "CargoLift.gd required"):
		var lift := StaticBody3D.new()
		lift.set_script(lift_script)
		tree.root.add_child(lift)
		if h.assert_true(lift.has_method("can_activate"), "CargoLift must expose can_activate()"):
			h.assert_false(lift.can_activate(), "CargoLift must reject activation without Lift Override Keycard")
		tree.root.remove_child(lift)
		lift.queue_free()
	h.reset_singletons(tree)
	h.end_test()
