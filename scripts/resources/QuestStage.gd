class_name QuestStage
extends Resource
## Represents a single stage/objective within a QuestResource.

enum ObjectiveType {
	KILL,
	FETCH,
	HACK,
	TALK,
}

@export var stage_id: String = ""
@export var journal_text: String = ""
@export var objective_type: ObjectiveType = ObjectiveType.TALK
@export var target_id: String = ""
@export var is_optional: bool = false
@export var is_completed: bool = false
@export var xp_reward: int = 25
@export var credit_reward: int = 0
