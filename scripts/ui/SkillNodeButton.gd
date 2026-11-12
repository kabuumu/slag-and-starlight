class_name SkillNodeButton
extends Button
## Interactive skill node button in the branching SkillTreeUI.

enum State {
	LOCKED,
	AVAILABLE,
	UNLOCKED,
}

signal skill_selected(node_button: SkillNodeButton)

@export var skill: SkillResource

var state: State = State.LOCKED


func _ready() -> void:
	custom_minimum_size = Vector2(108, 36)
	clip_text = true
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_refresh_visuals()


func set_skill_resource(res: SkillResource) -> void:
	skill = res
	_refresh_visuals()


func set_node_state(new_state: State) -> void:
	state = new_state
	_refresh_visuals()


func _refresh_visuals() -> void:
	if skill == null:
		return
	text = skill.display_name
	var prereq_names: PackedStringArray = PackedStringArray()
	for prereq in skill.prerequisites:
		if prereq != null:
			prereq_names.append(prereq.display_name)
	var prereq_str: String = ", ".join(prereq_names) if prereq_names.size() > 0 else "None"
	tooltip_text = "%s (Tier %d, Cost: %d SP)\n%s\nRequires: %s" % [
		skill.display_name,
		skill.tier,
		skill.cost,
		skill.description,
		prereq_str,
	]

	match state:
		State.LOCKED:
			modulate = Color(0.5, 0.45, 0.45, 1.0)
		State.AVAILABLE:
			modulate = Color(1.0, 0.85, 0.35, 1.0)
		State.UNLOCKED:
			modulate = Color(0.4, 1.0, 0.55, 1.0)


func _on_pressed() -> void:
	skill_selected.emit(self)
