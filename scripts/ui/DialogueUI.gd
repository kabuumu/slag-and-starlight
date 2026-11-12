extends Control
## Morrowind/Daggerfall-style keyword dialogue UI.
## Left: animated NPC portrait + scrolling dialogue log. Right: clickable Topics with skill/attribute/flag gates.

var current_dialogue: Resource = null
var _portrait_base_pos: Vector2 = Vector2.ZERO
var _anim_time: float = 0.0
var _transcript_lines: Array[String] = []

@onready var npc_name_label: Label = $MainPanel/Margin/RootVBox/HeaderRow/NPCNameLabel
@onready var close_button: Button = $MainPanel/Margin/RootVBox/HeaderRow/CloseButton
@onready var portrait_rect: TextureRect = $MainPanel/Margin/RootVBox/BodyRow/LeftVBox/PortraitFrame/PortraitRect
@onready var dialogue_text: RichTextLabel = $MainPanel/Margin/RootVBox/BodyRow/LeftVBox/DialogueScroll/DialogueText
@onready var topic_list: VBoxContainer = $MainPanel/Margin/RootVBox/BodyRow/RightVBox/TopicsScroll/TopicList


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if portrait_rect != null:
		_portrait_base_pos = portrait_rect.position
	if close_button != null and not close_button.pressed.is_connected(close_dialogue):
		close_button.pressed.connect(close_dialogue)


func _process(delta: float) -> void:
	if not visible or portrait_rect == null:
		return
	_anim_time += delta
	# Subtle 2D breathing/bobbing animation on the NPC portrait
	portrait_rect.position.y = _portrait_base_pos.y + sin(_anim_time * 3.0) * 2.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_dialogue()
		get_viewport().set_input_as_handled()


func open_dialogue(data: Resource) -> void:
	if data == null:
		return
	current_dialogue = data
	_transcript_lines.clear()

	var npc_name: String = str(data.get("npc_name")) if "npc_name" in data else "NPC"
	var greeting: String = str(data.get("greeting")) if "greeting" in data else "..."
	var portrait: Variant = data.get("portrait_texture") if "portrait_texture" in data else null

	if npc_name_label != null:
		npc_name_label.text = npc_name
	if portrait_rect != null and portrait is Texture2D:
		var tex: Texture2D = portrait
		var w: int = tex.get_width()
		var h: int = tex.get_height()
		if w >= 256 and h == w * 2:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(0.0, 0.0, float(w) / 4.0, float(h) / 8.0)
			portrait_rect.texture = atlas
		else:
			portrait_rect.texture = tex
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_append_line("[b]%s:[/b] %s" % [npc_name, greeting])
	_rebuild_topics()

	visible = true
	if get_tree() != null:
		get_tree().paused = true
	if not DisplayServer.get_name().begins_with("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_dialogue() -> void:
	visible = false
	current_dialogue = null
	var parent_node: Node = get_parent()
	if parent_node != null:
		for child in parent_node.get_children():
			if child != self and child is CanvasItem and child.name != "HUD" and (child as CanvasItem).visible:
				return
	if get_tree() != null:
		get_tree().paused = false
	if not DisplayServer.get_name().begins_with("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func check_topic_requirement(topic: Dictionary) -> bool:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	var gs: Node = get_node_or_null("/root/GameState")

	for attr_key in ["tech", "grit", "reflex", "guile"]:
		var min_key: String = "min_%s" % attr_key
		if topic.has(min_key):
			var req_val: int = int(topic.get(min_key, 0))
			var cur_val: int = int(ps.attributes.get(attr_key, 0)) if ps != null else 0
			if cur_val < req_val:
				return false

	if topic.has("required_skill"):
		var skill_id: String = str(topic.get("required_skill", ""))
		if not skill_id.is_empty():
			if ps == null or not ps.has_method("has_skill") or not bool(ps.call("has_skill", skill_id)):
				return false

	if topic.has("required_flag"):
		var req_flag: String = str(topic.get("required_flag", ""))
		if not req_flag.is_empty():
			if gs == null or not bool(gs.call("get_flag", req_flag, false)):
				return false

	if topic.has("forbidden_flag"):
		var forb_flag: String = str(topic.get("forbidden_flag", ""))
		if not forb_flag.is_empty():
			if gs != null and bool(gs.call("get_flag", forb_flag, false)):
				return false

	return true


func _rebuild_topics() -> void:
	if topic_list == null:
		return
	for child in topic_list.get_children():
		child.queue_free()

	if current_dialogue == null or not ("topics" in current_dialogue):
		return

	var topics_val: Variant = current_dialogue.get("topics")
	if not (topics_val is Array):
		return

	for t_var in topics_val:
		if not (t_var is Dictionary):
			continue
		var topic: Dictionary = t_var
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var label_text: String = str(topic.get("label", "Topic"))
		var unlocked: bool = check_topic_requirement(topic)
		if unlocked:
			btn.text = "> " + label_text
			btn.disabled = false
			btn.pressed.connect(_on_topic_pressed.bind(topic))
		else:
			btn.text = "[LOCKED] " + label_text
			btn.disabled = true
		topic_list.add_child(btn)


func _on_topic_pressed(topic: Dictionary) -> void:
	if current_dialogue == null:
		return
	var npc_id: String = str(current_dialogue.get("npc_id")) if "npc_id" in current_dialogue else ""
	var npc_name: String = str(current_dialogue.get("npc_name")) if "npc_name" in current_dialogue else "NPC"
	var topic_id: String = str(topic.get("topic_id", ""))
	var label_text: String = str(topic.get("label", ""))
	var response: String = str(topic.get("response", "..."))

	_append_line("\n[color=#e0b870][You asked about %s][/color]" % label_text)
	_append_line("[b]%s:[/b] %s" % [npc_name, response])

	var action: String = str(topic.get("action", ""))
	if not action.is_empty():
		_execute_topic_action(action)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("dialogue_topic_visited"):
		bus.dialogue_topic_visited.emit(npc_id, topic_id)

	_rebuild_topics()


func _execute_topic_action(action: String) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	var ps: Node = get_node_or_null("/root/PlayerStats")
	var qm: Node = get_node_or_null("/root/QuestManager")
	var bus: Node = get_node_or_null("/root/EventBus")

	match action:
		"start_dead_mans_switch":
			if qm != null and qm.has_method("start_quest"):
				qm.call("start_quest", "dead_mans_switch")
		"reroute_life_support":
			if gs != null and not bool(gs.call("get_flag", "life_support_rerouted", false)):
				gs.call("set_flag", "life_support_rerouted", true)
				if ps != null and ps.has_method("add_xp"):
					ps.call("add_xp", 50)
				if bus != null:
					bus.combat_log_entry.emit("Life-support rerouted! (+50 XP)", "quest")
		"miners_cant_union":
			if gs != null and not bool(gs.call("get_flag", "miners_cant_used", false)):
				gs.call("set_flag", "miners_cant_used", true)
				gs.call("modify_reputation", "mining_union", 15)
				if ps != null:
					ps.credits += 50
				if bus != null:
					bus.combat_log_entry.emit("Union solidarity acknowledged (+15 Mining Union rep, +50 Cr).", "quest")
		"give_blackbox_to_kael":
			if gs != null and bool(gs.call("get_flag", "has_seismic_blackbox", false)) and not bool(gs.call("get_flag", "blackbox_given_to_kael", false)):
				gs.call("set_flag", "blackbox_given_to_kael", true)
				gs.call("modify_reputation", "mining_union", 25)
				if ps != null:
					ps.credits += 150
					var barrel_path: String = "res://resources/items/modded_blaster_barrel.tres"
					if ResourceLoader.exists(barrel_path) and ps.has_method("add_item_to_backpack"):
						var loaded_barrel: Resource = load(barrel_path)
						if loaded_barrel != null:
							ps.call("add_item_to_backpack", loaded_barrel.duplicate(true))
				if bus != null:
					bus.combat_log_entry.emit("Turned in Seismic Blackbox to Kael (+150 Cr, Modded Blaster Barrel, +25 Union rep).", "quest")
		"keep_blackbox":
			if gs != null:
				gs.call("set_flag", "blackbox_kept", true)
		"sell_blackbox":
			if gs != null and bool(gs.call("get_flag", "has_seismic_blackbox", false)) and not bool(gs.call("get_flag", "blackbox_sold", false)):
				gs.call("set_flag", "blackbox_sold", true)
				gs.call("set_flag", "has_seismic_blackbox", false)
				gs.call("modify_reputation", "khoros_corp", 15)
				var payout: int = 150
				if ps != null and ps.has_method("has_skill") and bool(ps.call("has_skill", "black_market_appraisal")):
					payout = int(round(float(payout) * 1.25))
				if ps != null:
					ps.credits += payout
				if bus != null:
					bus.combat_log_entry.emit("Sold Seismic Blackbox to Corporate Agent (+%d Cr)." % payout, "loot")
		"sell_raw_ore":
			if ps != null:
				var sold_count: int = 0
				var kept_items: Array[Resource] = []
				for item in ps.backpack_items:
					if item != null and str(item.get("id")) == "raw_ore":
						sold_count += 1
					else:
						kept_items.append(item)
				if sold_count > 0:
					ps.backpack_items = kept_items
					var unit_price: int = 40
					if ps.has_method("has_skill") and bool(ps.call("has_skill", "black_market_appraisal")):
						unit_price = int(round(float(unit_price) * 1.25))
					var total_pay: int = sold_count * unit_price
					ps.credits += total_pay
					ps.recalculate_derived_stats()
					_append_line("[color=#80e080]Sold %d Raw Ore for %d credits (%d Cr each).[/color]" % [sold_count, total_pay, unit_price])
					if bus != null:
						bus.combat_log_entry.emit("Sold %d Raw Ore for %d Cr." % [sold_count, total_pay], "loot")
				else:
					_append_line("[color=#e08080]You have no Raw Ore in your backpack.[/color]")


func _append_line(bbcode_line: String) -> void:
	_transcript_lines.append(bbcode_line)
	if dialogue_text != null:
		dialogue_text.text = "\n".join(_transcript_lines)
