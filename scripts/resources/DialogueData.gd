class_name DialogueData
extends Resource
## Keyword-driven dialogue resource for Morrowind/Daggerfall-style NPC conversations.

@export var npc_id: String = ""
@export var npc_name: String = ""
@export var portrait_texture: Texture2D
@export_multiline var greeting: String = ""
@export var topics: Array[Dictionary] = []
