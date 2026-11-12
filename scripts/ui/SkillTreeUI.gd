extends Control
## Character Progression & 3-Branch Skill Tree UI.
## Pauses the 3D world while open and manages Attributes, 15 Skills, and Field Nano-Repair.

const SKILL_PATHS: Array[String] = [
	"res://resources/skills/jury_rigged_blaster.tres",
	"res://resources/skills/overcharge_capacitor.tres",
	"res://resources/skills/ricochet_shot.tres",
	"res://resources/skills/piston_strike.tres",
	"res://resources/skills/scrap_shielding.tres",
	"res://resources/skills/signal_bypass.tres",
	"res://resources/skills/turret_override.tres",
	"res://resources/skills/capacitor_meltdown.tres",
	"res://resources/skills/cell_recycler.tres",
	"res://resources/skills/field_nano_repair.tres",
	"res://resources/skills/mag_tumbler_sense.tres",
	"res://resources/skills/shadow_stepper.tres",
	"res://resources/skills/ambush_calibration.tres",
	"res://resources/skills/miners_cant.tres",
	"res://resources/skills/black_market_appraisal.tres",
]

const NODE_POSITIONS: Dictionary = {
	# Void-Scrapper (Left column)
	"jury_rigged_blaster": Vector2(76, 20),
	"overcharge_capacitor": Vector2(12, 95),
	"ricochet_shot": Vector2(12, 170),
	"piston_strike": Vector2(132, 95),
	"scrap_shielding": Vector2(132, 170),
	# Cyber-Splicer (Center column)
	"signal_bypass": Vector2(326, 20),
	"turret_override": Vector2(262, 95),
	"capacitor_meltdown": Vector2(262, 170),
	"cell_recycler": Vector2(382, 95),
	"field_nano_repair": Vector2(382, 170),
	# Tunnel-Rat (Right column)
	"mag_tumbler_sense": Vector2(576, 20),
	"shadow_stepper": Vector2(512, 95),
	"ambush_calibration": Vector2(512, 170),
	"miners_cant": Vector2(632, 95),
	"black_market_appraisal": Vector2(632, 170),
}

const COLOR_LINE_LOCKED: Color = Color(0.32, 0.26, 0.26, 0.85)
const COLOR_LINE_AVAILABLE: Color = Color(0.95, 0.75, 0.25, 0.95)
const COLOR_LINE_UNLOCKED: Color = Color(0.35, 0.95, 0.5, 1.0)

@onready var level_label: Label = $MainPanel/Margin/RootVBox/HeaderRow/LevelLabel
@onready var points_label: Label = $MainPanel/Margin/RootVBox/HeaderRow/PointsLabel
@onready var close_button: Button = $MainPanel/Margin/RootVBox/HeaderRow/CloseButton

@onready var grit_value_label: Label = $MainPanel/Margin/RootVBox/AttributesRow/GritBox/GritValue
@onready var grit_add_btn: Button = $MainPanel/Margin/RootVBox/AttributesRow/GritBox/GritAddBtn
@onready var reflex_value_label: Label = $MainPanel/Margin/RootVBox/AttributesRow/ReflexBox/ReflexValue
@onready var reflex_add_btn: Button = $MainPanel/Margin/RootVBox/AttributesRow/ReflexBox/ReflexAddBtn
@onready var tech_value_label: Label = $MainPanel/Margin/RootVBox/AttributesRow/TechBox/TechValue
@onready var tech_add_btn: Button = $MainPanel/Margin/RootVBox/AttributesRow/TechBox/TechAddBtn
@onready var guile_value_label: Label = $MainPanel/Margin/RootVBox/AttributesRow/GuileBox/GuileValue
@onready var guile_add_btn: Button = $MainPanel/Margin/RootVBox/AttributesRow/GuileBox/GuileAddBtn

@onready var tree_canvas: Control = $MainPanel/Margin/RootVBox/TreeCanvas
@onready var detail_label: Label = $MainPanel/Margin/RootVBox/FooterRow/DetailLabel
@onready var nano_repair_button: Button = $MainPanel/Margin/RootVBox/FooterRow/NanoRepairButton

var _skills_by_id: Dictionary = {}
var _node_buttons: Dictionary = {}
var _connector_lines: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_skills()
	_build_tree_canvas()
	_connect_signals()
	refresh_ui()


func _load_skills() -> void:
	_skills_by_id.clear()
	for path in SKILL_PATHS:
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is SkillResource and not res.id.is_empty():
				_skills_by_id[res.id] = res


func _build_tree_canvas() -> void:
	if tree_canvas == null:
		return
	for child in tree_canvas.get_children():
		child.queue_free()
	_node_buttons.clear()
	_connector_lines.clear()

	# First create SkillNodeButtons so we know their positions
	for skill_id in _skills_by_id.keys():
		var skill_res: SkillResource = _skills_by_id[skill_id]
		var btn := SkillNodeButton.new()
		btn.name = "Skill_%s" % skill_id
		btn.set_skill_resource(skill_res)
		var pos: Vector2 = NODE_POSITIONS.get(skill_id, Vector2.ZERO)
		btn.position = pos
		btn.size = Vector2(114, 36)
		btn.skill_selected.connect(_on_skill_node_selected)
		tree_canvas.add_child(btn)
		_node_buttons[skill_id] = btn

	# Create Line2D connectors behind buttons
	for skill_id in _skills_by_id.keys():
		var skill_res: SkillResource = _skills_by_id[skill_id]
		var child_btn: SkillNodeButton = _node_buttons.get(skill_id, null)
		if child_btn == null:
			continue
		for prereq in skill_res.prerequisites:
			if prereq == null:
				continue
			var parent_btn: SkillNodeButton = _node_buttons.get(prereq.id, null)
			if parent_btn == null:
				continue
			var line := Line2D.new()
			line.width = 2.0
			line.default_color = COLOR_LINE_LOCKED
			var p1: Vector2 = parent_btn.position + Vector2(57, 36)
			var p2: Vector2 = child_btn.position + Vector2(57, 0)
			line.add_point(p1)
			line.add_point(p2)
			tree_canvas.add_child(line)
			tree_canvas.move_child(line, 0)
			_connector_lines.append({
				"line": line,
				"parent_id": prereq.id,
				"child_id": skill_id,
			})


func _connect_signals() -> void:
	if close_button != null and not close_button.pressed.is_connected(close):
		close_button.pressed.connect(close)
	if grit_add_btn != null and not grit_add_btn.pressed.is_connected(_on_add_attribute.bind("grit")):
		grit_add_btn.pressed.connect(_on_add_attribute.bind("grit"))
	if reflex_add_btn != null and not reflex_add_btn.pressed.is_connected(_on_add_attribute.bind("reflex")):
		reflex_add_btn.pressed.connect(_on_add_attribute.bind("reflex"))
	if tech_add_btn != null and not tech_add_btn.pressed.is_connected(_on_add_attribute.bind("tech")):
		tech_add_btn.pressed.connect(_on_add_attribute.bind("tech"))
	if guile_add_btn != null and not guile_add_btn.pressed.is_connected(_on_add_attribute.bind("guile")):
		guile_add_btn.pressed.connect(_on_add_attribute.bind("guile"))
	if nano_repair_button != null and not nano_repair_button.pressed.is_connected(_on_field_nano_repair_pressed):
		nano_repair_button.pressed.connect(_on_field_nano_repair_pressed)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb != null and not eb.is_connected("player_stats_changed", refresh_ui):
		eb.connect("player_stats_changed", refresh_ui)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("skill_tree") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	refresh_ui()
	visible = true
	if get_tree() != null:
		get_tree().paused = true
	if not DisplayServer.get_name().begins_with("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
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


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func can_unlock_skill(skill_id: String) -> bool:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps == null:
		return false
	var skill_res: SkillResource = _skills_by_id.get(skill_id, null)
	if skill_res == null:
		return false
	if skill_id in ps.unlocked_skills:
		return false
	if int(ps.skill_points) < skill_res.cost:
		return false
	for prereq in skill_res.prerequisites:
		if prereq != null and not (prereq.id in ps.unlocked_skills):
			return false
	return true


func try_unlock_skill(skill_id: String) -> bool:
	if not can_unlock_skill(skill_id):
		return false
	var ps: Node = get_node_or_null("/root/PlayerStats")
	var skill_res: SkillResource = _skills_by_id.get(skill_id, null)
	if ps == null or skill_res == null:
		return false

	ps.skill_points -= skill_res.cost
	ps.unlocked_skills.append(skill_id)
	ps.recalculate_derived_stats()

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.emit_signal("combat_log_entry", "Skill Unlocked: %s" % skill_res.display_name, "progression")

	if detail_label != null:
		detail_label.text = "Unlocked %s: %s" % [skill_res.display_name, skill_res.description]
	refresh_ui()
	return true


func allocate_attribute(attr_name: String) -> bool:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps == null:
		return false
	if int(ps.attribute_points) <= 0:
		return false
	if not ps.attributes.has(attr_name):
		return false
	ps.attribute_points -= 1
	ps.attributes[attr_name] = int(ps.attributes[attr_name]) + 1
	ps.recalculate_derived_stats()
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb != null:
		eb.emit_signal("combat_log_entry", "Increased %s to %d" % [attr_name.capitalize(), int(ps.attributes[attr_name])], "progression")
	refresh_ui()
	return true


func perform_field_nano_repair() -> int:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps == null or not ps.has_skill("field_nano_repair"):
		return 0
	var tech: int = int(ps.attributes.get("tech", 5))
	var repair_amount: int = 20 + tech * 2
	var repaired_count: int = 0
	for slot_key in ps.equipped_items.keys():
		var item: Variant = ps.equipped_items[slot_key]
		if item != null and item is Resource:
			var max_dur: Variant = item.get("max_durability")
			var cur_dur: Variant = item.get("durability")
			var armor_val: Variant = item.get("armor_rating")
			if max_dur != null and cur_dur != null and armor_val != null and int(armor_val) > 0:
				var max_d: int = int(max_dur)
				var cur_d: int = int(cur_dur)
				if cur_d < max_d:
					item.set("durability", mini(max_d, cur_d + repair_amount))
					repaired_count += 1
	if repaired_count > 0:
		ps.suit_power = maxf(0.0, float(ps.suit_power) - 15.0)
		ps.recalculate_derived_stats()
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb != null:
			eb.emit_signal("combat_log_entry", "Field Nano-Repair restored %d armor piece(s) (+%d durability)." % [repaired_count, repair_amount], "item")
	return repaired_count


func refresh_ui() -> void:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps == null:
		return

	if level_label != null:
		level_label.text = "LVL %d  |  XP: %d / %d" % [int(ps.level), int(ps.xp), int(ps.xp_to_next)]
	if points_label != null:
		points_label.text = "ATTR PTS: %d   SKILL PTS: %d" % [int(ps.attribute_points), int(ps.skill_points)]

	var has_attr_pts: bool = int(ps.attribute_points) > 0
	if grit_value_label != null:
		grit_value_label.text = "GRIT: %d" % int(ps.attributes.get("grit", 5))
	if grit_add_btn != null:
		grit_add_btn.disabled = not has_attr_pts
	if reflex_value_label != null:
		reflex_value_label.text = "REFLEX: %d" % int(ps.attributes.get("reflex", 5))
	if reflex_add_btn != null:
		reflex_add_btn.disabled = not has_attr_pts
	if tech_value_label != null:
		tech_value_label.text = "TECH: %d" % int(ps.attributes.get("tech", 5))
	if tech_add_btn != null:
		tech_add_btn.disabled = not has_attr_pts
	if guile_value_label != null:
		guile_value_label.text = "GUILE: %d" % int(ps.attributes.get("guile", 5))
	if guile_add_btn != null:
		guile_add_btn.disabled = not has_attr_pts

	# Update skill nodes
	for skill_id in _node_buttons.keys():
		var btn: SkillNodeButton = _node_buttons[skill_id]
		if skill_id in ps.unlocked_skills:
			btn.set_node_state(SkillNodeButton.State.UNLOCKED)
		elif can_unlock_skill(skill_id):
			btn.set_node_state(SkillNodeButton.State.AVAILABLE)
		else:
			btn.set_node_state(SkillNodeButton.State.LOCKED)

	# Update Line2D connector colors
	for entry in _connector_lines:
		var line: Line2D = entry["line"]
		var parent_id: String = entry["parent_id"]
		var child_id: String = entry["child_id"]
		var parent_unlocked: bool = parent_id in ps.unlocked_skills
		var child_unlocked: bool = child_id in ps.unlocked_skills
		if parent_unlocked and child_unlocked:
			line.default_color = COLOR_LINE_UNLOCKED
		elif parent_unlocked:
			line.default_color = COLOR_LINE_AVAILABLE
		else:
			line.default_color = COLOR_LINE_LOCKED

	if nano_repair_button != null:
		var has_nano: bool = ps.has_skill("field_nano_repair")
		nano_repair_button.visible = has_nano
		nano_repair_button.disabled = not has_nano


func _on_skill_node_selected(node_btn: SkillNodeButton) -> void:
	if node_btn == null or node_btn.skill == null:
		return
	var skill_res: SkillResource = node_btn.skill
	if not try_unlock_skill(skill_res.id):
		if detail_label != null:
			detail_label.text = "%s (Cost %d SP): %s" % [skill_res.display_name, skill_res.cost, skill_res.description]


func _on_add_attribute(attr_name: String) -> void:
	allocate_attribute(attr_name)


func _on_field_nano_repair_pressed() -> void:
	var repaired: int = perform_field_nano_repair()
	if detail_label != null:
		if repaired > 0:
			detail_label.text = "Field Nano-Repair: Restored %d armor piece(s)." % repaired
		else:
			detail_label.text = "Field Nano-Repair: All equipped armor is at full durability."
