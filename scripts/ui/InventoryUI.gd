extends Control
## Two-panel Paper-Doll & Grid Backpack inventory screen.
## Pauses the 3D world while open and syncs equipment/backpack with PlayerStats.

const BACKPACK_CAPACITY: int = 24

@onready var head_slot: InventorySlot = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/LeftSlots/HeadSlot
@onready var pauldrons_slot: InventorySlot = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/LeftSlots/PauldronsSlot
@onready var torso_slot: InventorySlot = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/LeftSlots/TorsoSlot
@onready var primary_hand_slot: InventorySlot = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/LeftSlots/PrimaryHandSlot
@onready var gauntlets_slot: InventorySlot = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/RightSlots/GauntletsSlot
@onready var greaves_slot: InventorySlot = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/RightSlots/GreavesSlot
@onready var utility_slot: InventorySlot = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/RightSlots/UtilitySlot

@onready var greaves_layer: TextureRect = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/PaperDollStack/GreavesLayer
@onready var torso_layer: TextureRect = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/PaperDollStack/TorsoLayer
@onready var gauntlets_layer: TextureRect = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/PaperDollStack/GauntletsLayer
@onready var pauldrons_layer: TextureRect = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/PaperDollStack/PauldronsLayer
@onready var head_layer: TextureRect = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/PaperDollStack/HeadLayer
@onready var primary_hand_layer: TextureRect = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/PaperDollStack/PrimaryHandLayer
@onready var utility_layer: TextureRect = $MainPanel/Margin/RootHBox/PaperDollPanel/PaperDollArea/PaperDollStack/UtilityLayer

@onready var hp_label: Label = $MainPanel/Margin/RootHBox/PaperDollPanel/StatsReadout/HPLabel
@onready var armor_label: Label = $MainPanel/Margin/RootHBox/PaperDollPanel/StatsReadout/ArmorLabel
@onready var weight_label: Label = $MainPanel/Margin/RootHBox/PaperDollPanel/StatsReadout/WeightLabel
@onready var credits_label: Label = $MainPanel/Margin/RootHBox/PaperDollPanel/StatsReadout/CreditsLabel

@onready var backpack_grid: GridContainer = $MainPanel/Margin/RootHBox/BackpackPanel/BackpackGrid
@onready var close_button: Button = $MainPanel/Margin/RootHBox/BackpackPanel/HeaderRow/CloseButton

var _equipment_slots: Dictionary = {}
var _paper_doll_layers: Dictionary = {}
var _backpack_slots: Array[InventorySlot] = []
var _overflow_backpack_items: Array[Resource] = []
var _is_syncing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_equipment_slots = {
		ItemData.SlotType.HEAD: head_slot,
		ItemData.SlotType.TORSO: torso_slot,
		ItemData.SlotType.PAULDRONS: pauldrons_slot,
		ItemData.SlotType.GAUNTLETS: gauntlets_slot,
		ItemData.SlotType.GREAVES: greaves_slot,
		ItemData.SlotType.PRIMARY_HAND: primary_hand_slot,
		ItemData.SlotType.UTILITY: utility_slot,
	}

	_paper_doll_layers = {
		ItemData.SlotType.GREAVES: greaves_layer,
		ItemData.SlotType.TORSO: torso_layer,
		ItemData.SlotType.GAUNTLETS: gauntlets_layer,
		ItemData.SlotType.PAULDRONS: pauldrons_layer,
		ItemData.SlotType.HEAD: head_layer,
		ItemData.SlotType.PRIMARY_HAND: primary_hand_layer,
		ItemData.SlotType.UTILITY: utility_layer,
	}

	for slot_type in _equipment_slots.keys():
		var slot: InventorySlot = _equipment_slots[slot_type]
		if slot != null:
			slot.allowed_slot_type = slot_type
			if not slot.slot_changed.is_connected(_on_any_slot_changed):
				slot.slot_changed.connect(_on_any_slot_changed)

	_build_backpack_grid()

	if close_button != null and not close_button.pressed.is_connected(close):
		close_button.pressed.connect(close)

	if get_node_or_null("/root/EventBus") != null:
		var eb: Node = get_node("/root/EventBus")
		if not eb.is_connected("player_stats_changed", _on_player_stats_changed):
			eb.connect("player_stats_changed", _on_player_stats_changed)
		if not eb.is_connected("equipment_changed", _on_equipment_changed):
			eb.connect("equipment_changed", _on_equipment_changed)

	refresh_from_player_stats()


func _build_backpack_grid() -> void:
	if backpack_grid == null:
		return
	for child in backpack_grid.get_children():
		child.queue_free()
	_backpack_slots.clear()

	for i in range(BACKPACK_CAPACITY):
		var slot := InventorySlot.new()
		slot.name = "BackpackSlot_%d" % i
		slot.allowed_slot_type = ItemData.SlotType.ANY
		slot.slot_index = i
		slot.custom_minimum_size = Vector2(36, 36)
		slot.slot_changed.connect(_on_any_slot_changed)
		backpack_grid.add_child(slot)
		_backpack_slots.append(slot)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	refresh_from_player_stats()
	visible = true
	if get_tree() != null:
		get_tree().paused = true
	if not DisplayServer.get_name().begins_with("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	if _has_other_visible_modal():
		return
	if get_tree() != null:
		get_tree().paused = false
	if not DisplayServer.get_name().begins_with("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _has_other_visible_modal() -> bool:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return false
	for child in parent_node.get_children():
		if child != self and child is CanvasItem and child.name != "HUD" and (child as CanvasItem).visible:
			return true
	return false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func refresh_from_player_stats() -> void:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps == null:
		return

	_is_syncing = true
	for slot_type in _equipment_slots.keys():
		var slot: InventorySlot = _equipment_slots[slot_type]
		if slot != null:
			var item: ItemData = ps.equipped_items.get(slot_type, null) as ItemData
			slot.set_item(item, false)

	_overflow_backpack_items.clear()
	for i in range(_backpack_slots.size()):
		var bp_slot: InventorySlot = _backpack_slots[i]
		if i < ps.backpack_items.size():
			bp_slot.set_item(ps.backpack_items[i] as ItemData, false)
		else:
			bp_slot.set_item(null, false)
	if ps.backpack_items.size() > BACKPACK_CAPACITY:
		for idx in range(BACKPACK_CAPACITY, ps.backpack_items.size()):
			if ps.backpack_items[idx] != null:
				_overflow_backpack_items.append(ps.backpack_items[idx])
	_is_syncing = false

	_update_paper_doll_layers()
	_update_stats_readout()


func _on_any_slot_changed(changed_slot: InventorySlot) -> void:
	if _is_syncing:
		return
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps == null:
		return

	_is_syncing = true
	for slot_type in _equipment_slots.keys():
		var slot: InventorySlot = _equipment_slots[slot_type]
		if slot != null:
			if slot.held_item != null:
				ps.equipped_items[slot_type] = slot.held_item
			else:
				ps.equipped_items.erase(slot_type)

	var new_backpack: Array[Resource] = []
	for bp_slot in _backpack_slots:
		if bp_slot.held_item != null:
			new_backpack.append(bp_slot.held_item)
	for overflow_item in _overflow_backpack_items:
		if overflow_item != null:
			new_backpack.append(overflow_item)
	ps.backpack_items = new_backpack
	_is_syncing = false

	ps.recalculate_derived_stats()
	if changed_slot != null and changed_slot.allowed_slot_type != ItemData.SlotType.ANY:
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb != null:
			eb.emit_signal("equipment_changed", int(changed_slot.allowed_slot_type))

	_update_paper_doll_layers()
	_update_stats_readout()


func _update_paper_doll_layers() -> void:
	for slot_type in _paper_doll_layers.keys():
		var layer: TextureRect = _paper_doll_layers[slot_type]
		var slot: InventorySlot = _equipment_slots.get(slot_type, null)
		if layer == null:
			continue
		if slot != null and slot.held_item != null and slot.held_item.paper_doll_sprite != null:
			layer.texture = slot.held_item.paper_doll_sprite
			layer.visible = true
		else:
			layer.texture = null
			layer.visible = false


func _update_stats_readout() -> void:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps == null:
		return
	if hp_label != null:
		hp_label.text = "HP: %d / %d" % [int(ps.hp), int(ps.max_hp)]
	if armor_label != null:
		armor_label.text = "ARMOR: %d" % int(ps.total_armor)
	if weight_label != null:
		var w: float = float(ps.get("total_weight")) if ps.get("total_weight") != null else 0.0
		var max_w: float = float(ps.get("max_carry_weight")) if ps.get("max_carry_weight") != null else 25.0
		weight_label.text = "WEIGHT: %.1f / %.1f kg" % [w, max_w]
	if credits_label != null:
		credits_label.text = "CREDITS: %d" % int(ps.credits)


func _on_player_stats_changed() -> void:
	if not _is_syncing:
		_update_stats_readout()
		for slot_type in _equipment_slots.keys():
			var eq_slot: InventorySlot = _equipment_slots[slot_type]
			if eq_slot != null:
				eq_slot._refresh_visuals()
		for bp_slot in _backpack_slots:
			if bp_slot != null:
				bp_slot._refresh_visuals()


func _on_equipment_changed(_slot_type: int) -> void:
	if not _is_syncing and visible:
		refresh_from_player_stats()
