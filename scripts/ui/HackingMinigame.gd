extends Control
## Retro CRT Node-Matrix Intrusion hacking minigame.
## Pauses the 3D world while active and integrates Tech attribute and Signal Bypass skill.

enum NodeType {
	OPEN,
	ENTRY,
	DATA_CORE,
	FIREWALL,
	ICE_BOOST,
	DATA_CACHE,
	SIGNAL_DAMPENER,
}

var target_id: String = ""
var target_node: Node = null
var difficulty: String = "easy"
var grid_size: int = 5
var ice_timer: float = 20.0
var ice_rate: float = 1.0
var is_active: bool = false
var is_completed: bool = false
var is_failed: bool = false
var bonus_data: Dictionary = {}

var _grid: Array = []
var _buttons: Array = []
var _xp_reward: int = 45

@onready var title_label: Label = $CRTPanel/Margin/RootVBox/HeaderRow/TitleLabel
@onready var timer_label: Label = $CRTPanel/Margin/RootVBox/HeaderRow/TimerLabel
@onready var status_label: Label = $CRTPanel/Margin/RootVBox/StatusLabel
@onready var grid_container: GridContainer = $CRTPanel/Margin/RootVBox/GridContainer
@onready var close_button: Button = $CRTPanel/Margin/RootVBox/HeaderRow/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_button != null and not close_button.pressed.is_connected(cancel):
		close_button.pressed.connect(cancel)


func setup(p_difficulty: String = "easy", p_target_id: String = "", p_target_node: Node = null) -> void:
	difficulty = p_difficulty.to_lower()
	target_id = p_target_id
	target_node = p_target_node
	is_active = true
	is_completed = false
	is_failed = false
	ice_rate = 1.0
	bonus_data = {"credits": 0, "lore": false}

	var base_time: float = 20.0
	match difficulty:
		"medium":
			grid_size = 6
			base_time = 25.0
			_xp_reward = 80
		"hard":
			grid_size = 8
			base_time = 30.0
			_xp_reward = 130
		_:
			grid_size = 5
			base_time = 20.0
			_xp_reward = 45

	var ps: Node = get_node_or_null("/root/PlayerStats")
	var tech: int = int(ps.attributes.get("tech", 5)) if ps != null else 5
	ice_timer = base_time + maxf(0.0, float(tech - 5)) * 1.5

	_generate_grid(tech)
	_build_grid_ui()
	_update_ui()


func open(p_difficulty: String = "easy", p_target_id: String = "", p_target_node: Node = null) -> void:
	setup(p_difficulty, p_target_id, p_target_node)
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
	if eb != null and not is_completed and not is_failed:
		eb.emit_signal("minigame_completed", target_id, false, {"cancelled": true})
	close()


func _process(delta: float) -> void:
	if not is_active or is_completed or is_failed:
		return
	ice_timer -= delta * ice_rate
	if ice_timer <= 0.0:
		ice_timer = 0.0
		is_failed = true
		if status_label != null:
			status_label.text = "ICE TRACE COMPLETE // INTRUSION FAILED"
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb != null:
			eb.emit_signal("combat_log_entry", "Hacking failed: ICE trace detected!", "system")
			eb.emit_signal("minigame_completed", target_id, false, {"reason": "ice_trace"})
		close()
		return
	if timer_label != null:
		timer_label.text = "ICE TRACE: %.1fs (x%.1f)" % [ice_timer, ice_rate]


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_active:
		return
	if event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


func get_visibility_radius() -> int:
	var radius: int = 1
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps != null:
		if ps.has_skill("signal_bypass"):
			radius += 1
		var tech: int = int(ps.attributes.get("tech", 5))
		if tech >= 8:
			radius += 1
	return radius


func _generate_grid(tech: int) -> void:
	_grid.clear()
	for y in range(grid_size):
		var row: Array = []
		for x in range(grid_size):
			var ntype: int = NodeType.OPEN
			if x == 0 and y == 0:
				ntype = NodeType.ENTRY
			elif x == grid_size - 1 and y == grid_size - 1:
				ntype = NodeType.DATA_CORE
			else:
				var r: float = randf()
				if r < 0.16:
					ntype = NodeType.FIREWALL
				elif r < 0.26:
					ntype = NodeType.ICE_BOOST
				elif r < 0.34:
					ntype = NodeType.DATA_CACHE
				elif r < 0.42:
					ntype = NodeType.SIGNAL_DAMPENER
			var is_hazard: bool = (ntype == NodeType.FIREWALL or ntype == NodeType.ICE_BOOST)
			var revealed: bool = (x == 0 and y == 0) or (x == grid_size - 1 and y == grid_size - 1) or (tech >= 10 and is_hazard)
			row.append({
				"x": x,
				"y": y,
				"type": ntype,
				"breached": (x == 0 and y == 0),
				"revealed": revealed,
				"firewall_hits": 0,
			})
		_grid.append(row)
	_reveal_around(0, 0)


func _reveal_around(cx: int, cy: int) -> void:
	var rad: int = get_visibility_radius()
	for y in range(maxi(0, cy - rad), mini(grid_size, cy + rad + 1)):
		for x in range(maxi(0, cx - rad), mini(grid_size, cx + rad + 1)):
			if absi(x - cx) + absi(y - cy) <= rad:
				_grid[y][x]["revealed"] = true


func _is_adjacent_to_breached(x: int, y: int) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx >= 0 and nx < grid_size and ny >= 0 and ny < grid_size:
			if bool(_grid[ny][nx]["breached"]):
				return true
	return false


func click_node(x: int, y: int) -> bool:
	if not is_active or is_completed or is_failed:
		return false
	if x < 0 or x >= grid_size or y < 0 or y >= grid_size:
		return false
	var cell: Dictionary = _grid[y][x]
	if bool(cell["breached"]):
		return false
	if not _is_adjacent_to_breached(x, y):
		if status_label != null:
			status_label.text = "SELECT NODE ADJACENT TO BREACHED PATH"
		return false

	cell["revealed"] = true
	var ntype: int = int(cell["type"])
	if ntype == NodeType.FIREWALL:
		cell["firewall_hits"] = int(cell["firewall_hits"]) + 1
		if int(cell["firewall_hits"]) < 2:
			if status_label != null:
				status_label.text = "FIREWALL DAMAGED (1/2) — CLICK AGAIN TO BREACH"
			_update_ui()
			return false

	cell["breached"] = true
	_reveal_around(x, y)

	match ntype:
		NodeType.ICE_BOOST:
			ice_rate += 0.5
			if status_label != null:
				status_label.text = "ICE BOOST TRIGGERED! TRACE ACCELERATED"
		NodeType.SIGNAL_DAMPENER:
			ice_timer += 5.0
			if status_label != null:
				status_label.text = "SIGNAL DAMPENER: +5.0s TRACE TIME"
		NodeType.DATA_CACHE:
			bonus_data["credits"] = int(bonus_data.get("credits", 0)) + 35
			bonus_data["lore"] = true
			if status_label != null:
				status_label.text = "DATA CACHE EXTRACTED (+35 CREDITS)"
		NodeType.DATA_CORE:
			_on_win()
			return true
		_:
			if status_label != null:
				status_label.text = "NODE BREACHED (%d, %d)" % [x, y]

	_update_ui()
	return true


func _on_win() -> void:
	is_completed = true
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps != null:
		ps.add_xp(_xp_reward)
		var bonus_cr: int = int(bonus_data.get("credits", 0))
		if bonus_cr > 0:
			ps.credits += bonus_cr
			ps.recalculate_derived_stats()
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.emit_signal("combat_log_entry", "Subnet breached (+%d XP)" % _xp_reward, "progression")
		eb.emit_signal("minigame_completed", target_id, true, bonus_data)
	close()


func _build_grid_ui() -> void:
	if grid_container == null:
		return
	for child in grid_container.get_children():
		child.queue_free()
	_buttons.clear()
	grid_container.columns = grid_size

	for y in range(grid_size):
		var btn_row: Array = []
		for x in range(grid_size):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(36, 32)
			btn.pressed.connect(click_node.bind(x, y))
			grid_container.add_child(btn)
			btn_row.append(btn)
		_buttons.append(btn_row)


func _update_ui() -> void:
	if title_label != null:
		title_label.text = "NODE-MATRIX // %s (%dx%d)" % [difficulty.to_upper(), grid_size, grid_size]
	if timer_label != null:
		timer_label.text = "ICE TRACE: %.1fs (x%.1f)" % [ice_timer, ice_rate]

	for y in range(mini(grid_size, _buttons.size())):
		for x in range(mini(grid_size, _buttons[y].size())):
			var cell: Dictionary = _grid[y][x]
			var btn: Button = _buttons[y][x]
			var breached: bool = bool(cell["breached"])
			var revealed: bool = bool(cell["revealed"])
			var ntype: int = int(cell["type"])

			if not revealed:
				btn.text = "?"
				btn.modulate = Color(0.25, 0.45, 0.25, 1.0)
			else:
				match ntype:
					NodeType.ENTRY:
						btn.text = "IN"
						btn.modulate = Color(0.3, 1.0, 0.5, 1.0)
					NodeType.DATA_CORE:
						btn.text = "CORE"
						btn.modulate = Color(1.0, 0.9, 0.3, 1.0)
					NodeType.FIREWALL:
						btn.text = "FW" if breached else "FW!"
						btn.modulate = Color(0.4, 0.9, 0.5, 1.0) if breached else Color(1.0, 0.35, 0.25, 1.0)
					NodeType.ICE_BOOST:
						btn.text = "ICE"
						btn.modulate = Color(1.0, 0.45, 0.2, 1.0)
					NodeType.DATA_CACHE:
						btn.text = "DATA"
						btn.modulate = Color(0.4, 0.9, 1.0, 1.0)
					NodeType.SIGNAL_DAMPENER:
						btn.text = "+5s"
						btn.modulate = Color(0.5, 1.0, 0.8, 1.0)
					_:
						btn.text = "OK" if breached else "·"
						btn.modulate = Color(0.35, 1.0, 0.55, 1.0) if breached else Color(0.25, 0.75, 0.35, 1.0)
