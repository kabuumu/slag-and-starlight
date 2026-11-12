extends SceneTree

## Automated Playtest Bot for Slag & Starlight.
## Boots Main.tscn with real rendering, simulates player inputs, asserts gameplay invariants,
## and captures PNG screenshots for visual inspection.

var _shot_dir: String = "/tmp/playtest_shots"
var _failures: Array[String] = []
var _main: Node = null
var _player: CharacterBody3D = null


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shot_dir = arg.split("=", false, 1)[1]
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	call_deferred("_run")


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("[PLAYTEST FAIL] %s" % msg)
	else:
		print("[PLAYTEST PASS] %s" % msg)


func _step_frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		_assert(false, "Screenshot '%s' produced empty image" % shot_name)
		return
	var path: String = _shot_dir.path_join("%s.png" % shot_name)
	var err: Error = img.save_png(path)
	_assert(err == OK, "Saved screenshot %s (err=%d)" % [path, err])


func _press_key(keycode: Key, hold_frames: int = 10) -> void:
	var ev_down := InputEventKey.new()
	ev_down.keycode = keycode
	ev_down.physical_keycode = keycode
	ev_down.pressed = true
	Input.parse_input_event(ev_down)
	await _step_frames(hold_frames)
	var ev_up := InputEventKey.new()
	ev_up.keycode = keycode
	ev_up.physical_keycode = keycode
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	await _step_frames(3)


func _press_action(action: String, hold_frames: int = 10) -> void:
	var ev_down := InputEventAction.new()
	ev_down.action = action
	ev_down.pressed = true
	Input.parse_input_event(ev_down)
	await _step_frames(hold_frames)
	var ev_up := InputEventAction.new()
	ev_up.action = action
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	await _step_frames(3)


func _move_mouse(rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	Input.parse_input_event(ev)
	await _step_frames(2)


func _click_mouse(button: MouseButton = MOUSE_BUTTON_LEFT, hold_frames: int = 4) -> void:
	var ev_down := InputEventMouseButton.new()
	ev_down.button_index = button
	ev_down.pressed = true
	Input.parse_input_event(ev_down)
	await _step_frames(hold_frames)
	var ev_up := InputEventMouseButton.new()
	ev_up.button_index = button
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	await _step_frames(3)


func _run() -> void:
	print("============================================================")
	print("Slag & Starlight — Automated Playtest Bot")
	print("Screenshots dir: %s" % _shot_dir)
	print("============================================================")

	var packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	_assert(packed != null, "Main.tscn loads")
	if packed == null:
		quit(1)
		return

	_main = packed.instantiate()
	root.add_child(_main)
	await _step_frames(15)

	_player = _main.get_node_or_null("SubViewportContainer/SubViewport/World3D/Player") as CharacterBody3D
	_assert(_player != null, "Player node exists in Main.tscn")
	if _player == null:
		quit(1)
		return

	var hud: Control = _main.get_node_or_null("HUDLayer/HUD") as Control
	var inv_ui: Control = _main.get_node_or_null("HUDLayer/InventoryUI") as Control
	var skill_ui: Control = _main.get_node_or_null("HUDLayer/SkillTreeUI") as Control
	var lockpick_ui: Control = _main.get_node_or_null("HUDLayer/LockpickMinigame") as Control
	var hacking_ui: Control = _main.get_node_or_null("HUDLayer/HackingMinigame") as Control
	var dialogue_ui: Control = _main.get_node_or_null("HUDLayer/DialogueUI") as Control

	_assert(hud != null and hud.visible, "HUD is visible on boot")
	_assert(_player.global_position.y > -2.0 and _player.global_position.y < 10.0,
		"Player spawned on floor (y=%.2f)" % _player.global_position.y)

	# 1. Initial spawn screenshot
	await _capture("01_spawn_room1")

	# 2. Test click-to-capture & WASD movement + mouse look
	await _click_mouse(MOUSE_BUTTON_LEFT, 2)
	var start_pos: Vector3 = _player.global_position
	var start_rot_y: float = _player.rotation.y

	await _press_action("move_forward", 25)
	var after_fwd: Vector3 = _player.global_position
	var moved_dist: float = start_pos.distance_to(after_fwd)
	_assert(moved_dist > 0.25, "Player moved forward with W (dist=%.2f)" % moved_dist)
	_assert(_player.global_position.y > -2.0, "Player did not fall through floor (y=%.2f)" % _player.global_position.y)

	await _move_mouse(Vector2(180.0, -20.0))
	var yaw_delta: float = absf(angle_difference(start_rot_y, _player.rotation.y))
	_assert(yaw_delta > 0.05, "Player rotated with mouse look (yaw_delta=%.3f rad)" % yaw_delta)
	await _capture("02_after_move_and_look")

	# 3. Test Blaster firing & heat
	await _press_key(KEY_1, 3)
	await _click_mouse(MOUSE_BUTTON_LEFT, 4)
	await _step_frames(6)
	_assert(_player.current_heat > 0.0, "Blaster firing generated heat (heat=%.1f)" % _player.current_heat)
	await _capture("03_blaster_fired")

	# 4. Test Melee mode switch
	await _press_key(KEY_2, 3)
	_assert(_player.is_melee_mode, "Key 2 switched to melee mode")
	await _capture("04_melee_mode")
	await _press_key(KEY_1, 3)

	# 5. Test Inventory UI toggle
	await _press_action("inventory", 4)
	_assert(inv_ui != null and inv_ui.visible, "InventoryUI opened via 'inventory' action")
	await _capture("05_inventory_open")
	await _press_action("inventory", 4)
	_assert(inv_ui != null and not inv_ui.visible, "InventoryUI closed via 'inventory' action")

	# 6. Test Skill Tree UI toggle
	await _press_action("skill_tree", 4)
	_assert(skill_ui != null and skill_ui.visible, "SkillTreeUI opened via 'skill_tree' action")
	await _capture("06_skill_tree_open")
	await _press_action("skill_tree", 4)
	_assert(skill_ui != null and not skill_ui.visible, "SkillTreeUI closed via 'skill_tree' action")

	# 7. Test Lockpick Minigame overlay opens & closes cleanly
	var eb: Node = root.get_node_or_null("EventBus")
	_assert(eb != null, "EventBus autoload present")
	if eb != null:
		eb.minigame_requested.emit("lockpick", "easy", null)
		await _step_frames(8)
		_assert(lockpick_ui != null and lockpick_ui.visible, "LockpickMinigame opened on request")
		await _capture("07_lockpick_minigame")
		if lockpick_ui != null:
			lockpick_ui.visible = false
		await _step_frames(3)

		# 8. Test Hacking Minigame overlay opens & closes cleanly
		eb.minigame_requested.emit("hacking", "easy", null)
		await _step_frames(8)
		_assert(hacking_ui != null and hacking_ui.visible, "HackingMinigame opened on request")
		await _capture("08_hacking_minigame")
		if hacking_ui != null:
			hacking_ui.visible = false
		await _step_frames(3)

	# 9. Test Dialogue UI with Kael data
	if dialogue_ui != null and dialogue_ui.has_method("open_dialogue"):
		var kael_res: Resource = load("res://resources/dialogue/kael_dialogue.tres")
		if kael_res != null:
			dialogue_ui.call("open_dialogue", kael_res)
			await _step_frames(8)
			_assert(dialogue_ui.visible, "DialogueUI opened with Kael dialogue")
			await _capture("09_dialogue_ui")
			if dialogue_ui.has_method("close"):
				dialogue_ui.call("close")
			else:
				dialogue_ui.visible = false
			await _step_frames(3)

	# 10. Test RustSpireOutpost level transition
	if _main.has_method("load_level"):
		_main.call("load_level", "res://scenes/levels/RustSpireOutpost.tscn")
		await _step_frames(15)
		_assert(_player.global_position.y > -2.0, "Player valid after RustSpireOutpost transition (y=%.2f)" % _player.global_position.y)
		await _capture("10_rust_spire_outpost")

	print("============================================================")
	if _failures.is_empty():
		print("PLAYTEST RESULT: ALL CHECKS PASSED")
		quit(0)
	else:
		printerr("PLAYTEST RESULT: %d FAILURE(S)" % _failures.size())
		quit(1)
