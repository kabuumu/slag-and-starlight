class_name BlastDoor
extends StaticBody3D
## Heavy security blast door opened by Wall Terminal hacking (Path B) or Junction Box blasting (Path C).

@export var unlock_target_id: String = "room4_wall_terminal"
@export var is_open: bool = false


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("minigame_completed"):
		if not bus.minigame_completed.is_connected(_on_minigame_completed):
			bus.minigame_completed.connect(_on_minigame_completed)


func interact(_player: Node = null) -> void:
	if is_open:
		return
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.combat_log_entry.emit("Blast Door sealed. Hack Wall Terminal, pick Mag-Lock Vent, or blast the Junction Box.", "system")


func open_door() -> void:
	if is_open:
		return
	is_open = true
	var col: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.disabled = true
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh != null:
		mesh.position.y += 3.2
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.combat_log_entry.emit("Blast Door opened!", "system")


func _on_minigame_completed(completed_id: String, success: bool, _bonus_data: Dictionary) -> void:
	if success and completed_id == unlock_target_id:
		open_door()
