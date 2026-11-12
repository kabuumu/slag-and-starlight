extends Node
## Global game state singleton tracking flags, quests, faction reputation, and world state.

var flags: Dictionary = {}
var active_quests: Dictionary = {}
var completed_quests: Array[String] = []
var faction_reputation: Dictionary = {
	"mining_union": 0,
	"khoros_corp": 0,
	"free_drifters": 0,
}
var world_state: Dictionary = {
	"current_sector": "sub_level_04",
	"lockdown_active": true,
	"lift_powered": false,
}


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)


func modify_reputation(faction_id: String, delta: int) -> void:
	var current: int = int(faction_reputation.get(faction_id, 0))
	faction_reputation[faction_id] = current + delta
