class_name EnemyHitbox
extends Area3D
## Hitbox Area3D for enemies, exposing evasion, ID, awareness, and damage forwarding.

@export var evasion: int = 5
@export var enemy_id: String = ""
@export var is_unaware: bool = true


func take_damage(amount: int, damage_type: String = "blaster", is_stagger: bool = false) -> void:
	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.has_method("take_damage"):
		parent_node.call("take_damage", amount, damage_type, is_stagger)
