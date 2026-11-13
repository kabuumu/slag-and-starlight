class_name CargoLift
extends StaticBody3D
## Main Cargo Lift in Room 7: requires Lift Override Keycard to ascend to Rust-Spire Outpost.

@export var next_scene_path: String = "res://scenes/levels/RustSpireOutpost.tscn"


func can_activate() -> bool:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and bool(gs.call("get_flag", "has_lift_keycard", false)):
		return true
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps != null:
		for item in ps.backpack_items:
			if item != null and str(item.get("id")) == "lift_override_keycard":
				return true
	return false


func interact(_player: Node = null) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if not can_activate():
		if bus != null:
			bus.combat_log_entry.emit("Cargo Lift locked! Requires Lift Override Keycard from Overseer Vos's Office.", "system")
		return

	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.has_method("set_flag"):
			gs.call("set_flag", "lift_restored", true)
		if "world_state" in gs:
			gs.world_state["lift_powered"] = true
			gs.world_state["lockdown_active"] = false
			gs.world_state["current_sector"] = "rust_spire_outpost"

	if bus != null:
		bus.combat_log_entry.emit("Keycard accepted! Ascending to Rust-Spire Outpost...", "quest")

	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var main_node: Node = tree.root.get_node_or_null("Main")
	if main_node != null and main_node.has_method("load_level"):
		main_node.call("load_level", next_scene_path)
	elif ResourceLoader.exists(next_scene_path):
		tree.change_scene_to_file(next_scene_path)
