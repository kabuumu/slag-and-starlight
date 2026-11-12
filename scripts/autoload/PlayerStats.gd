extends Node
## Player RPG stats, attributes, skills, resources, and locational armor state.

var level: int = 1
var xp: int = 0
var xp_to_next: int = 100
var attribute_points: int = 0
var skill_points: int = 0

var attributes: Dictionary = {
	"grit": 5,
	"reflex": 5,
	"tech": 5,
	"guile": 5,
}

var unlocked_skills: Array[String] = []
var equipped_items: Dictionary = {}
var backpack_items: Array[Resource] = []

var hp: int = 100
var max_hp: int = 100
var suit_power: float = 100.0
var max_suit_power: float = 100.0
var total_armor: int = 0
var total_weight: float = 0.0
var max_carry_weight: float = 25.0
var credits: int = 0


func _ready() -> void:
	recalculate_derived_stats()
	hp = max_hp
	suit_power = max_suit_power


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		attribute_points += 1
		skill_points += 2
		xp_to_next = int(round(float(xp_to_next) * 1.5))
		recalculate_derived_stats()
		hp = max_hp
		suit_power = max_suit_power
		EventBus.level_up.emit(level)
		EventBus.combat_log_entry.emit("LEVEL UP! Reached level %d (+1 Attr, +2 Skill)" % level, "progression")
	EventBus.player_stats_changed.emit()


func has_skill(skill_id: String) -> bool:
	return skill_id in unlocked_skills


func recalculate_derived_stats() -> void:
	var grit: int = int(attributes.get("grit", 5))
	var tech: int = int(attributes.get("tech", 5))
	max_hp = 50 + grit * 10
	hp = clampi(hp, 0, max_hp)
	max_carry_weight = 15.0 + float(grit) * 2.0
	max_suit_power = 60.0 + float(tech) * 8.0
	suit_power = clampf(suit_power, 0.0, max_suit_power)

	var armor_sum: int = 0
	var weight_sum: float = 0.0
	for slot_key in equipped_items.keys():
		var item: Variant = equipped_items[slot_key]
		if item != null and item is Resource:
			var w: Variant = item.get("weight")
			if w != null:
				weight_sum += float(w)
			var dur: Variant = item.get("durability")
			var is_broken: bool = dur != null and int(dur) <= 0
			var rating: int = 0
			if not is_broken:
				rating = int(item.get("armor_rating")) if item.get("armor_rating") != null else 0
				# Scrap Shielding perk: +15% armor rating from torso pieces (SlotType.TORSO = 2)
				var stype: Variant = item.get("slot_type")
				var effective_slot: int = int(stype) if stype != null else int(slot_key)
				if effective_slot == ItemData.SlotType.TORSO and has_skill("scrap_shielding"):
					rating = int(ceil(float(rating) * 1.15))
			armor_sum += rating

	for bp_item in backpack_items:
		if bp_item != null and bp_item is Resource:
			var bw: Variant = bp_item.get("weight")
			if bw != null:
				weight_sum += float(bw)

	total_armor = armor_sum
	total_weight = weight_sum
	EventBus.player_stats_changed.emit()


func apply_locational_damage(raw_damage: int) -> Dictionary:
	if raw_damage <= 0:
		return {
			"location": "none",
			"armor_absorbed": 0,
			"final_damage": 0,
			"remaining_hp": hp,
		}

	# Weighted random hit location: Torso 40%, Legs 25%, Arms 20%, Head 15%
	var roll: float = randf()
	var location: String = "torso"
	var slot_key: int = ItemData.SlotType.TORSO
	if roll < 0.40:
		location = "torso"
		slot_key = ItemData.SlotType.TORSO
	elif roll < 0.65:
		location = "legs"
		slot_key = ItemData.SlotType.GREAVES
	elif roll < 0.85:
		location = "arms"
		slot_key = ItemData.SlotType.GAUNTLETS
	else:
		location = "head"
		slot_key = ItemData.SlotType.HEAD

	var slot_armor: int = 0
	var equipped: Variant = equipped_items.get(slot_key, null)
	if equipped != null and equipped is Resource:
		var dur: Variant = equipped.get("durability")
		var has_durability: bool = (dur == null or int(dur) > 0)
		if has_durability:
			var ar: Variant = equipped.get("armor_rating")
			if ar != null:
				slot_armor = int(ar)
			if slot_key == ItemData.SlotType.TORSO and has_skill("scrap_shielding") and slot_armor > 0:
				slot_armor = int(ceil(float(slot_armor) * 1.15))
			if dur != null:
				equipped.set("durability", maxi(0, int(dur) - 1))

	var final_damage: int = maxi(1, raw_damage - slot_armor)
	var absorbed: int = mini(raw_damage, slot_armor)
	hp = maxi(0, hp - final_damage)
	recalculate_derived_stats()

	return {
		"location": location,
		"armor_absorbed": absorbed,
		"final_damage": final_damage,
		"remaining_hp": hp,
	}


func equip_item(slot_type: int, item: Resource) -> Resource:
	var previous: Resource = equipped_items.get(slot_type, null)
	if item == null:
		equipped_items.erase(slot_type)
	else:
		equipped_items[slot_type] = item
	recalculate_derived_stats()
	EventBus.equipment_changed.emit(slot_type)
	return previous


func consume_item(item_id: String) -> bool:
	for i in range(backpack_items.size()):
		var item: Resource = backpack_items[i]
		if item == null:
			continue
		if str(item.get("id")) == item_id:
			var is_cons: Variant = item.get("is_consumable")
			if is_cons != null and not bool(is_cons):
				continue
			var heal_amt: int = int(item.get("heal_amount")) if item.get("heal_amount") != null else 0
			if heal_amt > 0:
				hp = mini(max_hp, hp + heal_amt)
			var item_name: String = str(item.get("name")) if item.get("name") != null else item_id
			backpack_items.remove_at(i)
			recalculate_derived_stats()
			EventBus.combat_log_entry.emit("Used %s (+%d HP)" % [item_name, heal_amt], "item")
			return true
	return false


func add_item_to_backpack(item: Resource) -> void:
	if item != null:
		backpack_items.append(item)
		recalculate_derived_stats()

