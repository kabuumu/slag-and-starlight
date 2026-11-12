class_name Interactable
extends StaticBody3D
## Generic world interactable supporting lockers/pickups, NPC dialogue, minigames, and radiant terminals.

@export_enum("pickup", "locker", "npc", "minigame", "radiant_terminal") var interaction_type: String = "pickup"
@export var prompt_text: String = "Interact"
@export var target_id: String = ""
@export var item_paths: Array[String] = []
@export var grant_flag: String = ""
@export var consume_on_use: bool = false
@export var dialogue_data: Resource
@export var minigame_type: String = "lockpick"
@export var difficulty: String = "easy"
@export var reward_item_path: String = ""
@export var reward_flag: String = ""

var is_used: bool = false
var _radiant_gen: RadiantJobGenerator = null


func _exit_tree() -> void:
	if _radiant_gen != null and is_instance_valid(_radiant_gen):
		_radiant_gen.free()
		_radiant_gen = null


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("minigame_completed"):
		if not bus.minigame_completed.is_connected(_on_minigame_completed):
			bus.minigame_completed.connect(_on_minigame_completed)


func interact(_player: Node = null) -> void:
	if is_used and interaction_type in ["pickup", "locker"]:
		_log("Already looted.", "loot")
		return

	match interaction_type:
		"pickup", "locker":
			_handle_loot()
		"npc":
			_handle_npc()
		"minigame":
			_handle_minigame()
		"radiant_terminal":
			_handle_radiant_terminal()


func _handle_loot() -> void:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	var gs: Node = get_node_or_null("/root/GameState")
	var bus: Node = get_node_or_null("/root/EventBus")

	for path in item_paths:
		if ResourceLoader.exists(path):
			var loaded_res: Resource = load(path)
			var item: Resource = loaded_res.duplicate(true) if loaded_res != null else null
			if item != null:
				if ps != null and ps.has_method("add_item_to_backpack"):
					ps.call("add_item_to_backpack", item)
				if bus != null:
					bus.item_picked_up.emit(item, 1)
				var item_name: String = str(item.get("name")) if "name" in item else path
				_log("Picked up %s." % item_name, "loot")

	if not grant_flag.is_empty() and gs != null:
		gs.call("set_flag", grant_flag, true)

	is_used = true
	if consume_on_use:
		queue_free()


func _handle_npc() -> void:
	if dialogue_data == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var dlg_ui: Node = tree.get_first_node_in_group("dialogue_ui")
	if dlg_ui == null:
		dlg_ui = tree.root.find_child("DialogueUI", true, false)
	if dlg_ui != null and dlg_ui.has_method("open_dialogue"):
		dlg_ui.call("open_dialogue", dialogue_data)


func _handle_minigame() -> void:
	if is_used:
		_log("Already bypassed.", "system")
		return
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("minigame_requested"):
		bus.minigame_requested.emit(minigame_type, difficulty, self)


func _handle_radiant_terminal() -> void:
	if _radiant_gen == null or not is_instance_valid(_radiant_gen):
		_radiant_gen = RadiantJobGenerator.new()
	var job: QuestResource = _radiant_gen.generate_job()
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm != null and qm.has_method("accept_quest") and job != null:
		var accepted: bool = bool(qm.call("accept_quest", job))
		if accepted:
			_log("New Radiant Contract accepted: %s" % job.title, "quest")
		else:
			_log("Contract already active or unavailable.", "quest")


func _on_minigame_completed(completed_id: String, success: bool, _bonus_data: Dictionary) -> void:
	if not success or target_id.is_empty() or completed_id != target_id:
		return
	is_used = true
	var ps: Node = get_node_or_null("/root/PlayerStats")
	var gs: Node = get_node_or_null("/root/GameState")
	var bus: Node = get_node_or_null("/root/EventBus")

	if not reward_item_path.is_empty() and ResourceLoader.exists(reward_item_path):
		var loaded_res: Resource = load(reward_item_path)
		var item: Resource = loaded_res.duplicate(true) if loaded_res != null else null
		if item != null:
			if ps != null and ps.has_method("add_item_to_backpack"):
				ps.call("add_item_to_backpack", item)
			if bus != null:
				bus.item_picked_up.emit(item, 1)
			var item_name: String = str(item.get("name")) if "name" in item else reward_item_path
			_log("Retrieved %s!" % item_name, "loot")

	if not reward_flag.is_empty() and gs != null:
		gs.call("set_flag", reward_flag, true)

	if minigame_type == "lockpick" and target_id == "room4_mag_lock":
		var col: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null:
			col.disabled = true
		visible = false
		var parent_node: Node = get_parent()
		if parent_node != null:
			var wall_west: Node3D = parent_node.get_node_or_null("BlastWallWest") as Node3D
			if wall_west != null:
				var wall_col: CollisionShape3D = wall_west.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if wall_col != null:
					wall_col.disabled = true
				var wall_mesh: MeshInstance3D = wall_west.get_node_or_null("MeshInstance3D") as MeshInstance3D
				if wall_mesh != null:
					wall_mesh.position.y += 1.8
		if gs != null and gs.has_method("set_flag"):
			gs.call("set_flag", "room4_vent_unlocked", true)
		var tree: SceneTree = get_tree()
		if tree != null:
			var player_node: Node = tree.get_first_node_in_group("player")
			if player_node != null and "in_vent" in player_node:
				player_node.set("in_vent", true)
		_log("Mag-Lock vent unsealed! Crawling bypass open.", "system")


func _log(msg: String, category: String) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.combat_log_entry.emit(msg, category)
