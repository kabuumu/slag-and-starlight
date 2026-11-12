extends RefCounted

var passed: int = 0
var failed: int = 0
var skipped: int = 0
var failures: Array[String] = []
var _current_test: String = ""
var _test_failed: bool = false


func begin_test(test_name: String) -> void:
	_current_test = test_name
	_test_failed = false


func end_test() -> void:
	if _test_failed:
		failed += 1
		print("  [FAIL] %s" % _current_test)
	else:
		passed += 1
		print("  [PASS] %s" % _current_test)
	_current_test = ""


func skip_test(test_name: String, reason: String) -> void:
	skipped += 1
	print("  [SKIP] %s (%s)" % [test_name, reason])


func _record_failure(msg: String) -> void:
	_test_failed = true
	var full := "%s: %s" % [_current_test, msg]
	failures.append(full)
	printerr("    -> %s" % full)


func assert_true(cond: bool, msg: String = "Expected true") -> bool:
	if not cond:
		_record_failure(msg)
		return false
	return true


func assert_false(cond: bool, msg: String = "Expected false") -> bool:
	if cond:
		_record_failure(msg)
		return false
	return true


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual != expected:
		var detail := "Expected <%s>, got <%s>" % [str(expected), str(actual)]
		if not msg.is_empty():
			detail = "%s (%s)" % [msg, detail]
		_record_failure(detail)
		return false
	return true


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> bool:
	if actual == unexpected:
		var detail := "Expected value != <%s>" % str(unexpected)
		if not msg.is_empty():
			detail = "%s (%s)" % [msg, detail]
		_record_failure(detail)
		return false
	return true


func assert_gt(actual: Variant, threshold: Variant, msg: String = "") -> bool:
	if not (actual > threshold):
		var detail := "Expected <%s> > <%s>" % [str(actual), str(threshold)]
		if not msg.is_empty():
			detail = "%s (%s)" % [msg, detail]
		_record_failure(detail)
		return false
	return true


func assert_ge(actual: Variant, threshold: Variant, msg: String = "") -> bool:
	if not (actual >= threshold):
		var detail := "Expected <%s> >= <%s>" % [str(actual), str(threshold)]
		if not msg.is_empty():
			detail = "%s (%s)" % [msg, detail]
		_record_failure(detail)
		return false
	return true


func assert_lt(actual: Variant, threshold: Variant, msg: String = "") -> bool:
	if not (actual < threshold):
		var detail := "Expected <%s> < <%s>" % [str(actual), str(threshold)]
		if not msg.is_empty():
			detail = "%s (%s)" % [msg, detail]
		_record_failure(detail)
		return false
	return true


func assert_le(actual: Variant, threshold: Variant, msg: String = "") -> bool:
	if not (actual <= threshold):
		var detail := "Expected <%s> <= <%s>" % [str(actual), str(threshold)]
		if not msg.is_empty():
			detail = "%s (%s)" % [msg, detail]
		_record_failure(detail)
		return false
	return true


func assert_approx(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> bool:
	if absf(actual - expected) > tolerance:
		var detail := "Expected ~%f (+/- %f), got %f" % [expected, tolerance, actual]
		if not msg.is_empty():
			detail = "%s (%s)" % [msg, detail]
		_record_failure(detail)
		return false
	return true


func assert_not_null(val: Variant, msg: String = "Expected non-null") -> bool:
	if val == null:
		_record_failure(msg)
		return false
	return true


func assert_null(val: Variant, msg: String = "Expected null") -> bool:
	if val != null:
		_record_failure("%s (got %s)" % [msg, str(val)])
		return false
	return true


func assert_has(container: Variant, key: Variant, msg: String = "") -> bool:
	if container == null or not (key in container):
		var detail := "Expected container to have <%s>" % str(key)
		if not msg.is_empty():
			detail = "%s (%s)" % [msg, detail]
		_record_failure(detail)
		return false
	return true


func get_autoload(tree: SceneTree, node_name: String) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)


func reset_singletons(tree: SceneTree) -> void:
	var gs := get_autoload(tree, "GameState")
	if gs != null:
		if "flags" in gs:
			gs.flags.clear()
		if "active_quests" in gs:
			gs.active_quests.clear()
		if "completed_quests" in gs:
			gs.completed_quests.clear()
		if "faction_reputation" in gs:
			gs.faction_reputation.clear()
		if "world_state" in gs:
			gs.world_state.clear()

	var ps := get_autoload(tree, "PlayerStats")
	if ps != null:
		if "level" in ps:
			ps.level = 1
		if "xp" in ps:
			ps.xp = 0
		if "xp_to_next" in ps:
			ps.xp_to_next = 100
		if "attribute_points" in ps:
			ps.attribute_points = 0
		if "skill_points" in ps:
			ps.skill_points = 0
		if "attributes" in ps:
			ps.attributes = {"grit": 5, "reflex": 5, "tech": 5, "guile": 5}
		if "unlocked_skills" in ps:
			ps.unlocked_skills.clear()
		if "equipped_items" in ps:
			ps.equipped_items.clear()
		if "backpack_items" in ps:
			ps.backpack_items.clear()
		if "credits" in ps:
			ps.credits = 0
		if ps.has_method("recalculate_derived_stats"):
			ps.recalculate_derived_stats()
		if "max_hp" in ps and "hp" in ps:
			ps.hp = ps.max_hp
		if "max_suit_power" in ps and "suit_power" in ps:
			ps.suit_power = ps.max_suit_power


func load_scene_safe(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	return res as PackedScene


func load_script_safe(path: String) -> GDScript:
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	return res as GDScript
