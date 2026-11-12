class_name QuestResource
extends Resource
## Data-driven quest definition containing ordered QuestStage objectives.

@export var quest_id: String = ""
@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var is_radiant: bool = false
@export var stages: Array[QuestStage] = []
@export var current_stage_index: int = 0
@export var reward_xp: int = 100
@export var reward_credits: int = 50


func get_quest_id() -> String:
	if not quest_id.is_empty():
		return quest_id
	return id


func get_current_stage() -> QuestStage:
	if current_stage_index >= 0 and current_stage_index < stages.size():
		return stages[current_stage_index]
	return null


func is_finished() -> bool:
	for stage in stages:
		if stage != null and not stage.is_optional and not stage.is_completed:
			return false
	return stages.size() > 0
