extends Control
## Retro CRT Mag-Tumbler Alignment lockpicking minigame.
## Pauses the 3D world while active and integrates Guile, Mag-Tumbler Sense, Servo-Grip Gauntlets, and Mag-Pick durability.

const BASE_TOLERANCE: float = 0.16
const CYLINDER_TRAVEL_PX: float = 64.0

var target_id: String = ""
var target_node: Node = null
var difficulty: String = "easy"
var cylinder_count: int = 3
var selected_index: int = 0
var tension: float = 0.0
var is_active: bool = false
var is_completed: bool = false
var is_failed: bool = false

var _cylinders: Array[Dictionary] = []
var _cylinder_visuals: Array[Dictionary] = []
var _base_speed: float = 1.6
var _xp_reward: int = 40

@onready var title_label: Label = $CRTPanel/Margin/RootVBox/HeaderRow/TitleLabel
@onready var status_label: Label = $CRTPanel/Margin/RootVBox/StatusLabel
@onready var cylinder_container: HBoxContainer = $CRTPanel/Margin/RootVBox/ShearFrame/CylinderContainer
@onready var tension_bar: ProgressBar = $CRTPanel/Margin/RootVBox/TensionRow/TensionBar
@onready var pick_durability_label: Label = $CRTPanel/Margin/RootVBox/TensionRow/PickLabel
@onready var close_button: Button = $CRTPanel/Margin/RootVBox/HeaderRow/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_button != null and not close_button.pressed.is_connected(cancel):
		close_button.pressed.connect(cancel)


func setup(p_difficulty: String = "easy", p_target_id: String = "", p_target_node: Node = null) -> void:
	difficulty = p_difficulty.to_lower()
	target_id = p_target_id
	target_node = p_target_node
	is_completed = false
	is_failed = false
	selected_index = 0
	tension = 0.0

	match difficulty:
		"medium":
			cylinder_count = 4
			_base_speed = 2.1
			_xp_reward = 75
		"hard":
			cylinder_count = 5
			_base_speed = 2.6
			_xp_reward = 120
		_:
			cylinder_count = 3
			_base_speed = 1.6
			_xp_reward = 40

	_cylinders.clear()
	for i in range(cylinder_count):
		_cylinders.append({
			"phase": float(i) * 1.35,
			"speed": _base_speed + float(i) * 0.35,
			"offset": sin(float(i) * 1.35),
			"locked": false,
		})

	_build_cylinder_visuals()
	_update_ui()


func open(p_difficulty: String = "easy", p_target_id: String = "", p_target_node: Node = null) -> void:
	setup(p_difficulty, p_target_id, p_target_node)
	is_active = true
	visible = true
	if get_tree() != null:
		get_tree().paused = true
	if not DisplayServer.get_name().begins_with("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	is_active = false
	visible = false
	var parent_node: Node = get_parent()
	if parent_node != null:
		for child in parent_node.get_children():
			if child != self and child is CanvasItem and child.name != "HUD" and (child as CanvasItem).visible:
				return
	if get_tree() != null:
		get_tree().paused = false
	if not DisplayServer.get_name().begins_with("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func cancel() -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb != null and not is_completed:
		eb.emit_signal("minigame_completed", target_id, false, {"cancelled": true})
	close()


func _process(delta: float) -> void:
	if not is_active or is_completed or is_failed:
		return
	var speed_mult: float = get_effective_speed_multiplier()
	for i in range(_cylinders.size()):
		var cyl: Dictionary = _cylinders[i]
		if not bool(cyl["locked"]):
			cyl["phase"] = float(cyl["phase"]) + float(cyl["speed"]) * speed_mult * delta
			cyl["offset"] = sin(float(cyl["phase"]))
	_update_cylinder_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_active:
		return
	if event.is_action_pressed("ui_left"):
		select_cylinder(selected_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		select_cylinder(selected_index + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("minigame_pulse"):
		fire_pulse()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


func select_cylinder(index: int) -> void:
	if cylinder_count <= 0:
		return
	selected_index = posmod(index, cylinder_count)
	_update_cylinder_visuals()


func get_effective_tolerance() -> float:
	var tol: float = BASE_TOLERANCE
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps != null:
		var guile: int = int(ps.attributes.get("guile", 5))
		tol += maxf(0.0, float(guile - 5)) * 0.015

		# Equipped Servo-Grip Gauntlets / lockpick_bonus
		for slot_key in ps.equipped_items.keys():
			var item: Variant = ps.equipped_items[slot_key]
			if item != null and item is Resource:
				var bonus: Variant = item.get("lockpick_bonus")
				if bonus != null and float(bonus) > 0.0:
					tol += float(bonus)
				elif str(item.get("id")) == "servo_grip_gauntlets":
					tol += 0.10

		if ps.has_skill("mag_tumbler_sense"):
			tol *= 1.25
	return clampf(tol, 0.08, 0.75)


func get_effective_speed_multiplier() -> float:
	var mult: float = 1.0
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps != null:
		var guile: int = int(ps.attributes.get("guile", 5))
		mult /= (1.0 + maxf(0.0, float(guile - 5)) * 0.04)
		if ps.has_skill("mag_tumbler_sense"):
			mult *= 0.85
	return clampf(mult, 0.35, 1.5)


func can_attempt_pick(pick_item: Resource = null) -> bool:
	if pick_item != null:
		var dur: Variant = pick_item.get("durability")
		return dur != null and int(dur) > 0
	var found: Resource = _find_usable_mag_pick()
	return found != null


func _find_usable_mag_pick() -> Resource:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps == null:
		return null
	for item in ps.backpack_items:
		if item != null and str(item.get("id")) == "mag_pick":
			var dur: Variant = item.get("durability")
			if dur != null and int(dur) > 0:
				return item
	return null


func _damage_mag_pick() -> bool:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps == null:
		return false
	var pick: Resource = _find_usable_mag_pick()
	if pick == null:
		return false
	var cur_dur: int = int(pick.get("durability"))
	cur_dur = maxi(0, cur_dur - 1)
	pick.set("durability", cur_dur)
	var eb: Node = get_node_or_null("/root/EventBus")
	if cur_dur <= 0:
		ps.backpack_items.erase(pick)
		ps.recalculate_derived_stats()
		if eb != null:
			eb.emit_signal("combat_log_entry", "Mag-Pick snapped!", "item")
	else:
		if eb != null:
			eb.emit_signal("combat_log_entry", "Mag-Pick damaged (%d durability left)." % cur_dur, "item")
	return true


func fire_pulse() -> bool:
	if is_completed or is_failed or selected_index < 0 or selected_index >= _cylinders.size():
		return false

	if not can_attempt_pick(null):
		if status_label != null:
			status_label.text = "NO USABLE MAG-PICK!"
		is_failed = true
		var eb_no_pick: Node = get_node_or_null("/root/EventBus")
		if eb_no_pick != null:
			eb_no_pick.emit_signal("minigame_completed", target_id, false, {"reason": "no_mag_pick"})
		close()
		return false

	var cyl: Dictionary = _cylinders[selected_index]
	if bool(cyl["locked"]):
		return false

	var tol: float = get_effective_tolerance()
	if absf(float(cyl["offset"])) <= tol:
		cyl["locked"] = true
		cyl["offset"] = 0.0
		tension = clampf(tension + (100.0 / float(cylinder_count)), 0.0, 100.0)
		if status_label != null:
			status_label.text = "TUMBLER %d LOCKED!" % (selected_index + 1)

		if _all_cylinders_locked():
			_on_win()
			return true

		# Advance to next unlocked cylinder
		for step in range(1, cylinder_count + 1):
			var next_idx: int = (selected_index + step) % cylinder_count
			if not bool(_cylinders[next_idx]["locked"]):
				selected_index = next_idx
				break
		_update_ui()
		return true
	else:
		_damage_mag_pick()
		tension = maxf(0.0, tension - 15.0)
		if status_label != null:
			status_label.text = "MISALIGNED! MAG-PICK DAMAGED"
		if not can_attempt_pick(null):
			is_failed = true
			var eb_fail: Node = get_node_or_null("/root/EventBus")
			if eb_fail != null:
				eb_fail.emit_signal("minigame_completed", target_id, false, {"reason": "pick_broken"})
			close()
			return false
		_update_ui()
		return false


func _all_cylinders_locked() -> bool:
	for cyl in _cylinders:
		if not bool(cyl["locked"]):
			return false
	return true


func _on_win() -> void:
	is_completed = true
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps != null:
		ps.add_xp(_xp_reward)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.emit_signal("combat_log_entry", "Mag-Lock bypassed (+%d XP)" % _xp_reward, "progression")
		eb.emit_signal("minigame_completed", target_id, true, {})
	close()


func _build_cylinder_visuals() -> void:
	if cylinder_container == null:
		return
	for child in cylinder_container.get_children():
		child.queue_free()
	_cylinder_visuals.clear()

	for i in range(cylinder_count):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(48, 160)
		slot.name = "Cylinder_%d" % i

		var bg := ColorRect.new()
		bg.color = Color(0.08, 0.14, 0.09, 1.0)
		bg.position = Vector2(8, 10)
		bg.size = Vector2(32, 140)
		slot.add_child(bg)

		var gap := ColorRect.new()
		gap.color = Color(0.25, 0.95, 0.45, 1.0)
		gap.position = Vector2(10, 74)
		gap.size = Vector2(28, 12)
		slot.add_child(gap)

		var selector := ColorRect.new()
		selector.color = Color(1.0, 0.85, 0.25, 0.9)
		selector.position = Vector2(16, 152)
		selector.size = Vector2(16, 6)
		slot.add_child(selector)

		cylinder_container.add_child(slot)
		_cylinder_visuals.append({
			"bg": bg,
			"gap": gap,
			"selector": selector,
		})


func _update_cylinder_visuals() -> void:
	for i in range(mini(_cylinders.size(), _cylinder_visuals.size())):
		var cyl: Dictionary = _cylinders[i]
		var vis: Dictionary = _cylinder_visuals[i]
		var gap: ColorRect = vis["gap"]
		var selector: ColorRect = vis["selector"]
		var center_y: float = 74.0 + float(cyl["offset"]) * CYLINDER_TRAVEL_PX
		gap.position.y = center_y
		if bool(cyl["locked"]):
			gap.color = Color(0.3, 1.0, 0.6, 1.0)
		elif i == selected_index:
			gap.color = Color(1.0, 0.9, 0.35, 1.0)
		else:
			gap.color = Color(0.2, 0.7, 0.35, 1.0)
		selector.visible = (i == selected_index)


func _update_ui() -> void:
	if title_label != null:
		title_label.text = "MAG-TUMBLER LOCK // %s" % difficulty.to_upper()
	if tension_bar != null:
		tension_bar.value = tension
	if pick_durability_label != null:
		var pick: Resource = _find_usable_mag_pick()
		if pick != null:
			pick_durability_label.text = "MAG-PICK: %d/%d" % [int(pick.get("durability")), int(pick.get("max_durability"))]
		else:
			pick_durability_label.text = "MAG-PICK: NONE"
	_update_cylinder_visuals()
