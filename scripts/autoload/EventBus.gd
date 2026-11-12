extends Node
## Central signal hub for Slag & Starlight.
## Decouples 2.5D presentation from systemic RPG rules.

signal item_picked_up(item: Resource, quantity: int)
signal quest_updated(quest_id: String, stage_id: String)
signal combat_log_entry(message: String, category: String)
signal minigame_requested(minigame_type: String, difficulty: String, target_node: Node)
signal minigame_completed(target_id: String, success: bool, bonus_data: Dictionary)
signal player_stats_changed()
signal equipment_changed(slot_type: int)
signal level_up(new_level: int)
signal enemy_killed(enemy_id: String)
signal dialogue_topic_visited(npc_id: String, topic_id: String)
