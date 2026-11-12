class_name InventorySlot
extends PanelContainer
## Drag-and-drop inventory/equipment slot supporting type filtering, swapping, and consumable use.

signal slot_changed(slot: InventorySlot)
signal item_used(slot: InventorySlot, item: ItemData)

@export var allowed_slot_type: ItemData.SlotType = ItemData.SlotType.ANY
@export var slot_index: int = -1
@export var slot_label_text: String = ""

var held_item: ItemData = null

var _icon_rect: TextureRect = null
var _label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(36, 36)
	_ensure_visual_children()
	_refresh_visuals()


func _ensure_visual_children() -> void:
	if _icon_rect == null:
		_icon_rect = get_node_or_null("IconRect") as TextureRect
	if _icon_rect == null:
		_icon_rect = TextureRect.new()
		_icon_rect.name = "IconRect"
		_icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon_rect)

	if _label == null:
		_label = get_node_or_null("SlotLabel") as Label
	if _label == null:
		_label = Label.new()
		_label.name = "SlotLabel"
		_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 8)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)


func set_item(item: ItemData, emit_signal_flag: bool = false) -> void:
	held_item = item
	_refresh_visuals()
	if emit_signal_flag:
		slot_changed.emit(self)


func _refresh_visuals() -> void:
	_ensure_visual_children()
	if held_item != null:
		_icon_rect.texture = held_item.icon
		_icon_rect.visible = held_item.icon != null
		var dur_text: String = ""
		if held_item.armor_rating > 0 or held_item.id == "mag_pick":
			dur_text = "%d/%d" % [held_item.durability, held_item.max_durability]
		_label.text = dur_text
		var lines: Array[String] = [held_item.name]
		if held_item.armor_rating > 0:
			lines.append("Armor: %d (Dur: %d/%d)" % [held_item.armor_rating, held_item.durability, held_item.max_durability])
		if held_item.damage_range != Vector2i.ZERO:
			lines.append("Damage: %d-%d" % [held_item.damage_range.x, held_item.damage_range.y])
		if held_item.is_consumable and held_item.heal_amount > 0:
			lines.append("Use (Right-Click / Double-Click): +%d HP" % held_item.heal_amount)
		if held_item.description != "":
			lines.append(held_item.description)
		tooltip_text = "\n".join(lines)
	else:
		_icon_rect.texture = null
		_icon_rect.visible = false
		_label.text = slot_label_text
		tooltip_text = slot_label_text


func _get_drag_data(_at_position: Vector2) -> Variant:
	if held_item == null:
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(32, 32)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.texture = held_item.icon
	set_drag_preview(preview)
	return {
		"item": held_item,
		"source_slot": self,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var item: Variant = data.get("item", null)
	if item == null or not (item is Resource):
		return false
	var stype_var: Variant = item.get("slot_type")
	var item_slot_type: int = int(stype_var) if stype_var != null else ItemData.SlotType.ANY
	if allowed_slot_type != ItemData.SlotType.ANY and item_slot_type != int(allowed_slot_type):
		return false
	if held_item != null:
		var source_slot: Variant = data.get("source_slot", null)
		if source_slot != null and source_slot is InventorySlot:
			var source_inv_slot := source_slot as InventorySlot
			if source_inv_slot.allowed_slot_type != ItemData.SlotType.ANY and int(held_item.slot_type) != int(source_inv_slot.allowed_slot_type):
				return false
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var incoming_item: ItemData = data["item"] as ItemData
	var source_slot: Variant = data.get("source_slot", null)
	if source_slot == self:
		return

	var previous_item: ItemData = held_item
	if previous_item != null and source_slot != null and source_slot is InventorySlot:
		var source_inv_slot := source_slot as InventorySlot
		var can_swap: bool = (
			source_inv_slot.allowed_slot_type == ItemData.SlotType.ANY
			or int(previous_item.slot_type) == int(source_inv_slot.allowed_slot_type)
		)
		if not can_swap:
			return
		set_item(incoming_item, false)
		source_inv_slot.set_item(previous_item, false)
		source_inv_slot.slot_changed.emit(source_inv_slot)
		slot_changed.emit(self)
		return

	set_item(incoming_item, false)
	if source_slot != null and source_slot is InventorySlot:
		var src := source_slot as InventorySlot
		src.set_item(null, false)
		src.slot_changed.emit(src)
	slot_changed.emit(self)


func _gui_input(event: InputEvent) -> void:
	if held_item == null:
		return
	if not held_item.is_consumable:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or (mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click):
			accept_event()
			_use_held_consumable()


func _use_held_consumable() -> void:
	if held_item == null or not held_item.is_consumable:
		return
	var used_item: ItemData = held_item
	if get_node_or_null("/root/PlayerStats") != null:
		var ps: Node = get_node("/root/PlayerStats")
		if ps.has_method("consume_item"):
			var consumed: bool = bool(ps.call("consume_item", used_item.id))
			if consumed:
				set_item(null, true)
				item_used.emit(self, used_item)
				return
	item_used.emit(self, used_item)
