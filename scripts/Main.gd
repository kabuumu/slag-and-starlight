extends Node
## Main scene controller managing the 320x200 SubViewport, post-process layer, and HUD layer.

@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var world_3d: Node3D = $SubViewportContainer/SubViewport/World3D
@onready var post_process_layer: CanvasLayer = $PostProcessLayer
@onready var hud_layer: CanvasLayer = $HUDLayer
@onready var hud: Control = $HUDLayer/HUD
@onready var inventory_ui: Control = $HUDLayer/InventoryUI
@onready var skill_tree_ui: Control = $HUDLayer/SkillTreeUI
@onready var lockpick_minigame: Control = $HUDLayer/LockpickMinigame
@onready var hacking_minigame: Control = $HUDLayer/HackingMinigame
@onready var dialogue_ui: Control = $HUDLayer/DialogueUI
@onready var player: CharacterBody3D = $SubViewportContainer/SubViewport/World3D/Player


func _ready() -> void:
	if sub_viewport_container != null:
		sub_viewport_container.stretch = true
		sub_viewport_container.stretch_shrink = 4
		sub_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sub_viewport != null:
		sub_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	if dialogue_ui != null:
		dialogue_ui.add_to_group("dialogue_ui")

	var gs: Node = get_node_or_null("/root/GameState")
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if gs != null and ps != null and not bool(gs.call("get_flag", "sublevel04_intro_hp_set", false)):
		gs.call("set_flag", "sublevel04_intro_hp_set", true)
		ps.hp = maxi(1, int(floor(float(ps.max_hp) * 0.5)))
		var bus: Node = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.player_stats_changed.emit()

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb != null and not eb.is_connected("minigame_requested", _on_minigame_requested):
		eb.connect("minigame_requested", _on_minigame_requested)


func load_level(scene_path: String) -> void:
	if world_3d == null or not ResourceLoader.exists(scene_path):
		return
	var current_level: Node = world_3d.get_node_or_null("CurrentLevel")
	if current_level != null:
		world_3d.remove_child(current_level)
		current_level.queue_free()
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return
	var new_level: Node = packed.instantiate()
	new_level.name = "CurrentLevel"
	world_3d.add_child(new_level)
	var spawn: Node3D = new_level.get_node_or_null("PlayerSpawn") as Node3D
	if player != null:
		player.velocity = Vector3.ZERO
		if "in_vent" in player:
			player.set("in_vent", false)
		if spawn != null:
			player.global_position = spawn.global_position
	if hud != null and hud.has_method("_connect_player"):
		hud.call("_connect_player")


func is_blocking_modal_open() -> bool:
	if lockpick_minigame != null and lockpick_minigame.visible:
		return true
	if hacking_minigame != null and hacking_minigame.visible:
		return true
	if dialogue_ui != null and dialogue_ui.visible:
		return true
	return false


func is_any_modal_open() -> bool:
	if is_blocking_modal_open():
		return true
	if inventory_ui != null and inventory_ui.visible:
		return true
	if skill_tree_ui != null and skill_tree_ui.visible:
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if is_blocking_modal_open():
		return
	if event.is_action_pressed("inventory"):
		if skill_tree_ui != null and skill_tree_ui.visible and skill_tree_ui.has_method("close"):
			skill_tree_ui.call("close")
		if inventory_ui != null and inventory_ui.has_method("toggle"):
			inventory_ui.call("toggle")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_tree"):
		if inventory_ui != null and inventory_ui.visible and inventory_ui.has_method("close"):
			inventory_ui.call("close")
		if skill_tree_ui != null and skill_tree_ui.has_method("toggle"):
			skill_tree_ui.call("toggle")
			get_viewport().set_input_as_handled()


func _on_minigame_requested(minigame_type: String, difficulty: String, target_node: Node) -> void:
	if inventory_ui != null and inventory_ui.visible and inventory_ui.has_method("close"):
		inventory_ui.call("close")
	if skill_tree_ui != null and skill_tree_ui.visible and skill_tree_ui.has_method("close"):
		skill_tree_ui.call("close")
	var target_id: String = ""
	if target_node != null:
		if "target_id" in target_node and not str(target_node.get("target_id")).is_empty():
			target_id = str(target_node.get("target_id"))
		else:
			target_id = target_node.name
	match minigame_type.to_lower():
		"lockpick":
			if lockpick_minigame != null and lockpick_minigame.has_method("open"):
				lockpick_minigame.call("open", difficulty, target_id, target_node)
		"hacking":
			if hacking_minigame != null and hacking_minigame.has_method("open"):
				hacking_minigame.call("open", difficulty, target_id, target_node)
