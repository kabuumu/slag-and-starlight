class_name SkillResource
extends Resource
## Data-driven skill node definition for the 3-branch Skill Tree.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var branch: String = ""
@export var cost: int = 1
@export var prerequisites: Array[SkillResource] = []
@export var tier: int = 1
