extends Control
## HUD overlay displaying HP, Heat, Suit Power bars, Combat Log, and WeaponView2D.

const MAX_LOG_LINES: int = 6

@onready var hp_bar: ProgressBar = $StatusPanel/VBox/HPRow/HPBar
@onready var hp_value: Label = $StatusPanel/VBox/HPRow/HPValue
@onready var heat_bar: ProgressBar = $StatusPanel/VBox/HeatRow/HeatBar
@onready var heat_value: Label = $StatusPanel/VBox/HeatRow/HeatValue
@onready var suit_bar: ProgressBar = $StatusPanel/VBox/SuitRow/SuitBar
@onready var suit_value: Label = $StatusPanel/VBox/SuitRow/SuitValue
@onready var combat_log_label: RichTextLabel = $CombatLogPanel/Margin/CombatLogLabel
@onready var weapon_view: WeaponView2D = $WeaponAnchor/WeaponView2D

var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		if bus.has_signal("player_stats_changed"):
			bus.player_stats_changed.connect(_refresh_stats)
		if bus.has_signal("combat_log_entry"):
			bus.combat_log_entry.connect(_on_combat_log_entry)
	_refresh_stats()
	_connect_player()


var _death_banner: Label = null


func _ensure_death_banner() -> void:
	if _death_banner != null:
		return
	_death_banner = Label.new()
	_death_banner.name = "DeathBanner"
	_death_banner.text = "CRITICAL FAILURE — SUIT INTEGRITY LOST\nPRESS [R] TO REBOOT AT CHECKPOINT"
	_death_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_banner.anchors_preset = Control.PRESET_CENTER
	_death_banner.offset_left = -240
	_death_banner.offset_right = 240
	_death_banner.offset_top = -36
	_death_banner.offset_bottom = 36
	_death_banner.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2, 1.0))
	_death_banner.add_theme_font_size_override("font_size", 18)
	_death_banner.visible = false
	add_child(_death_banner)


func _connect_player() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	if player != null:
		if "weapon_view" in player:
			player.set("weapon_view", weapon_view)
		if player.has_signal("heat_changed") and not player.heat_changed.is_connected(_on_heat_changed):
			player.heat_changed.connect(_on_heat_changed)


func _refresh_stats() -> void:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats == null:
		return
	var hp: int = int(stats.hp)
	var max_hp: int = maxi(1, int(stats.max_hp))
	var sp: float = float(stats.suit_power)
	var max_sp: float = maxf(1.0, float(stats.max_suit_power))
	if hp_bar != null:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if hp_value != null:
		hp_value.text = "%d/%d" % [hp, max_hp]
	if suit_bar != null:
		suit_bar.max_value = max_sp
		suit_bar.value = sp
	if suit_value != null:
		suit_value.text = "%d/%d" % [int(sp), int(max_sp)]
	_ensure_death_banner()
	if _death_banner != null:
		_death_banner.visible = (hp <= 0)


func _on_heat_changed(cur_heat: float, max_h: float, is_overheated: bool) -> void:
	if heat_bar != null:
		heat_bar.max_value = maxf(1.0, max_h)
		heat_bar.value = cur_heat
	if heat_value != null:
		heat_value.text = "OVERHEAT!" if is_overheated else "%d%%" % int(round((cur_heat / maxf(1.0, max_h)) * 100.0))


func _on_combat_log_entry(message: String, _category: String) -> void:
	_log_lines.append(message)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	if combat_log_label != null:
		combat_log_label.text = "\n".join(_log_lines)
