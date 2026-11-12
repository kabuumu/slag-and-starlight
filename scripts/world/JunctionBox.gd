class_name JunctionBox
extends StaticBody3D
## Corroded power junction box (Path C): blasting it forces the BlastDoor open but alerts Room 5 Mining Drones.

@export var linked_door_path: NodePath
@export var max_hp: int = 10
@export var hp: int = 10

var is_blasted: bool = false


func _ready() -> void:
	if hp <= 0:
		hp = max_hp


func interact(_player: Node = null) -> void:
	if is_blasted:
		return
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.combat_log_entry.emit("Corroded Junction Box: shoot or strike it to force the Blast Door (alerts Room 5 drones!).", "system")


func take_damage(amount: int, _damage_type: String = "blaster", _is_stagger: bool = false) -> void:
	if is_blasted:
		return
	hp = maxi(0, hp - maxi(1, amount))
	if hp <= 0:
		blast_open()


func blast_open() -> void:
	if is_blasted:
		return
	is_blasted = true

	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("set_flag"):
		gs.call("set_flag", "room5_drones_alerted", true)

	if not linked_door_path.is_empty():
		var door: Node = get_node_or_null(linked_door_path)
		if door != null and door.has_method("open_door"):
			door.call("open_door")

	var tree: SceneTree = get_tree()
	if tree != null:
		for drone in tree.get_nodes_in_group("room5_drones"):
			if "state" in drone:
				drone.set("state", EnemyBase.State.CHASE)
			var hb: Node = drone.get_node_or_null("EnemyHitbox")
			if hb != null and "is_unaware" in hb:
				hb.set("is_unaware", false)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.combat_log_entry.emit("Junction Box detonated! Blast Door forced open — Room 5 Mining Drones alerted!", "combat")

	visible = false
	var col: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.disabled = true
