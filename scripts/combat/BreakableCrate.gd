class_name BreakableCrate
extends StaticBody3D
## Breakable supply crate that shatters on weapon hit and grants a Power Cell.

@export var max_hp: int = 12
@export var hp: int = 12
@export var loot_item_path: String = "res://resources/items/power_cell.tres"

var is_broken: bool = false


func _ready() -> void:
	if hp <= 0:
		hp = max_hp


func take_damage(amount: int, _damage_type: String = "blaster", _is_stagger: bool = false) -> void:
	if is_broken:
		return
	hp = maxi(0, hp - maxi(1, amount))
	if hp <= 0:
		_shatter()


func _shatter() -> void:
	is_broken = true
	var stats: Node = get_node_or_null("/root/PlayerStats")
	var bus: Node = get_node_or_null("/root/EventBus")
	var loaded_res: Resource = load(loot_item_path) if ResourceLoader.exists(loot_item_path) else null
	var item: Resource = loaded_res.duplicate(true) if loaded_res != null else null
	if item != null and stats != null and stats.has_method("add_item_to_backpack"):
		stats.call("add_item_to_backpack", item)
	if bus != null:
		if item != null:
			bus.item_picked_up.emit(item, 1)
		bus.combat_log_entry.emit("Supply crate shattered! Found Power Cell.", "loot")
	queue_free()
