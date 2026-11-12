class_name ItemData
extends Resource
## Data-driven item definition for weapons, armor, consumables, and quest items.

enum SlotType {
	ANY,
	HEAD,
	TORSO,
	PAULDRONS,
	GAUNTLETS,
	GREAVES,
	PRIMARY_HAND,
	UTILITY,
}

@export var id: String = ""
@export var name: String = ""
@export var icon: Texture2D
@export var paper_doll_sprite: Texture2D
@export var slot_type: SlotType = SlotType.ANY
@export var weight: float = 0.5
@export var armor_rating: int = 0
@export var damage_range: Vector2i = Vector2i.ZERO
@export var durability: int = 100
@export var max_durability: int = 100
@export var description: String = ""
@export var value_credits: int = 10
@export var is_consumable: bool = false
@export var heal_amount: int = 0
@export var lockpick_bonus: float = 0.0


func get_effective_armor() -> int:
	if durability <= 0:
		return 0
	return armor_rating


func is_broken() -> bool:
	return max_durability > 0 and durability <= 0
