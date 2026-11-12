extends SceneTree

const HELPER_PATH := "res://tests/test_helper.gd"

const UNIT_SUITES := {
	"M1": "res://tests/unit/test_m1_core_25d.gd",
	"M2": "res://tests/unit/test_m2_inventory_armor.gd",
	"M3": "res://tests/unit/test_m3_combat.gd",
	"M4": "res://tests/unit/test_m4_subsystems_skills.gd",
	"M5": "res://tests/unit/test_m5_dialogue_quests.gd",
}

const E2E_SUITES := {
	"3": "res://tests/e2e/test_tier3_combinations.gd",
	"4": "res://tests/e2e/test_tier4_scenarios.gd",
}


func _init() -> void:
	call_deferred("_run_all")


func _parse_args() -> Dictionary:
	var tier := "all"
	var milestone := "ALL"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			tier = arg.split("=", false, 1)[1].to_lower()
		elif arg.begins_with("--milestone="):
			milestone = arg.split("=", false, 1)[1].to_upper()
	return {"tier": tier, "milestone": milestone}


func _milestones_to_run(target: String) -> Array[String]:
	match target:
		"M1":
			return ["M1"]
		"M2":
			return ["M1", "M2"]
		"M3":
			return ["M1", "M2", "M3"]
		"M4":
			return ["M1", "M2", "M3", "M4"]
		_:
			return ["M1", "M2", "M3", "M4", "M5"]


func _run_all() -> void:
	var opts := _parse_args()
	var tier: String = opts["tier"]
	var milestone: String = opts["milestone"]

	print("============================================================")
	print("Slag & Starlight — Godot Headless Test Runner")
	print("Tier filter: %s | Milestone: %s" % [tier, milestone])
	print("============================================================")

	var helper_script := load(HELPER_PATH) as GDScript
	if helper_script == null:
		printerr("[FATAL] Could not load %s" % HELPER_PATH)
		quit(1)
		return
	var h: RefCounted = helper_script.new()

	# Tiers 1 & 2: Unit Suites by Milestone
	if tier in ["all", "1", "2"]:
		for ms in _milestones_to_run(milestone):
			var suite_path: String = UNIT_SUITES[ms]
			var suite_script := load(suite_path) as GDScript
			if suite_script == null or not suite_script.can_instantiate():
				h.begin_test("UnitSuite_%s_load" % ms)
				h.assert_true(false, "Failed to load/parse %s" % suite_path)
				h.end_test()
				continue
			var suite: RefCounted = suite_script.new()
			suite.run(self, h, tier)

	# Tier 3: Cross-Feature Combinations
	if tier in ["all", "3"] and milestone in ["M4", "M5", "ALL"]:
		var t3_script := load(E2E_SUITES["3"]) as GDScript
		if t3_script != null and t3_script.can_instantiate():
			var t3: RefCounted = t3_script.new()
			t3.run(self, h)
		else:
			h.begin_test("E2E_Tier3_load")
			h.assert_true(false, "Failed to load/parse %s" % E2E_SUITES["3"])
			h.end_test()

	# Tier 4: Real-World Application Scenarios
	if tier in ["all", "4"] and milestone in ["M5", "ALL"]:
		var t4_script := load(E2E_SUITES["4"]) as GDScript
		if t4_script != null and t4_script.can_instantiate():
			var t4: RefCounted = t4_script.new()
			t4.run(self, h)
		else:
			h.begin_test("E2E_Tier4_load")
			h.assert_true(false, "Failed to load/parse %s" % E2E_SUITES["4"])
			h.end_test()

	print("\n============================================================")
	print("Summary: %d passed | %d failed | %d skipped" % [h.passed, h.failed, h.skipped])
	print("============================================================")

	if h.failed > 0:
		quit(1)
	else:
		quit(0)
