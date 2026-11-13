extends RefCounted


func run(tree: SceneTree, h: RefCounted, tier_filter: String) -> void:
	print("\n[Suite] M2: ItemData, Paper-Doll UI, Drag-and-Drop & Locational Armor")
	var run_t1 = tier_filter in ["all", "1"]
	var run_t2 = tier_filter in ["all", "2"]

	if run_t1:
		_test_t1_item_data_properties(tree, h)
		_test_t1_inventory_ui_7_slots_and_grid(tree, h)
		_test_t1_inventory_slot_drag_drop_contract(tree, h)
		_test_t1_total_armor_recalculation(tree, h)
		_test_t1_locational_armor_damage_reduction(tree, h)

	if run_t2:
		_test_t2_locational_damage_zero_negative_overflow(tree, h)
		_test_t2_zero_durability_armor_provides_no_protection(tree, h)
		_test_t2_slot_type_mismatch_rejected(tree, h)
		_test_t2_empty_and_full_backpack(tree, h)


func _make_item(item_script: GDScript, id: String, slot_type: int, armor: int, dur: int) -> Resource:
	var item: Resource = item_script.new()
	item.set("id", id)
	item.set("name", id.capitalize())
	item.set("slot_type", slot_type)
	item.set("armor_rating", armor)
	item.set("durability", dur)
	item.set("weight", 2.0)
	item.set("damage_range", Vector2i(0, 0))
	return item


func _test_t1_item_data_properties(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M2_item_data_resource_properties")
	var item_script = h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(item_script, "ItemData.gd must exist"):
		h.end_test()
		return
	var item: Resource = item_script.new()
	for prop in ["id", "name", "icon", "paper_doll_sprite", "slot_type", "weight", "armor_rating", "damage_range", "durability"]:
		h.assert_true(prop in item, "ItemData missing property: %s" % prop)
	h.end_test()


func _test_t1_inventory_ui_7_slots_and_grid(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M2_inventory_ui_7_equipment_slots")
	var packed = h.load_scene_safe("res://scenes/ui/InventoryUI.tscn")
	if not h.assert_not_null(packed, "InventoryUI.tscn must exist"):
		h.end_test()
		return
	var ui = packed.instantiate()
	var slot_script = h.load_script_safe("res://scripts/ui/InventorySlot.gd")
	h.assert_not_null(slot_script, "InventorySlot.gd must exist")
	var slot_count = 0
	var stack: Array[Node] = [ui]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is PanelContainer and n.get_script() == slot_script:
			slot_count += 1
		for c in n.get_children():
			stack.append(c)
	h.assert_ge(slot_count, 7, "InventoryUI must contain at least 7 equipment InventorySlot nodes")
	var primary_layer := ui.find_child("PrimaryHandLayer", true, false) as TextureRect
	var utility_layer := ui.find_child("UtilityLayer", true, false) as TextureRect
	if h.assert_not_null(primary_layer, "PrimaryHandLayer must exist") and h.assert_not_null(utility_layer, "UtilityLayer must exist"):
		h.assert_approx(primary_layer.offset_top, -32.0, 0.01, "PrimaryHandLayer must be constrained to 32px corner badge")
		h.assert_approx(utility_layer.offset_top, -32.0, 0.01, "UtilityLayer must be constrained to 32px corner badge")
	var barrel := load("res://resources/items/modded_blaster_barrel.tres") as Resource
	if h.assert_not_null(barrel, "modded_blaster_barrel.tres must exist"):
		h.assert_not_null(barrel.get("paper_doll_sprite"), "modded_blaster_barrel must have paper_doll_sprite assigned")
	ui.queue_free()
	h.end_test()


func _test_t1_inventory_slot_drag_drop_contract(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M2_inventory_slot_drag_and_drop")
	var slot_script = h.load_script_safe("res://scripts/ui/InventorySlot.gd")
	var item_script = h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(slot_script, "InventorySlot.gd required") or not h.assert_not_null(item_script, "ItemData.gd required"):
		h.end_test()
		return
	var slot = PanelContainer.new()
	slot.set_script(slot_script)
	h.assert_true(slot.has_method("_get_drag_data"), "InventorySlot must override _get_drag_data")
	h.assert_true(slot.has_method("_can_drop_data"), "InventorySlot must override _can_drop_data")
	h.assert_true(slot.has_method("_drop_data"), "InventorySlot must override _drop_data")
	# Matching slot_type (e.g., Torso = 2)
	if "allowed_slot_type" in slot:
		slot.set("allowed_slot_type", 2)
		var armor = _make_item(item_script, "pressure_suit", 2, 10, 50)
		var drag_payload = {"item": armor, "source_slot": null}
		h.assert_true(slot._can_drop_data(Vector2.ZERO, drag_payload), "Matching slot_type must allow drop")
	slot.queue_free()
	h.end_test()


func _test_t1_total_armor_recalculation(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M2_total_armor_recalculation")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	var item_script = h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(item_script, "ItemData.gd required"):
		h.end_test()
		return
	var torso = _make_item(item_script, "tattered_pressure_suit", 2, 8, 40)
	var head = _make_item(item_script, "mining_visor", 1, 4, 30)
	ps.equipped_items[2] = torso
	ps.equipped_items[1] = head
	ps.recalculate_derived_stats()
	h.assert_ge(ps.total_armor, 12, "total_armor must sum equipped armor ratings (8 + 4 = 12)")
	h.reset_singletons(tree)
	h.end_test()


func _test_t1_locational_armor_damage_reduction(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T1_M2_locational_armor_damage_and_durability")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	var item_script = h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(item_script, "ItemData.gd required"):
		h.end_test()
		return
	# Equip armor in Head(1), Torso(2), Pauldrons/Arms(3/4), Greaves/Legs(5) with 5 armor each
	for slot_id in [1, 2, 3, 4, 5]:
		ps.equipped_items[slot_id] = _make_item(item_script, "armor_%d" % slot_id, slot_id, 5, 20)
	ps.recalculate_derived_stats()
	var start_hp: int = ps.hp
	var result: Dictionary = ps.apply_locational_damage(15)
	h.assert_true(result is Dictionary, "apply_locational_damage must return a Dictionary")
	h.assert_lt(ps.hp, start_hp, "15 raw damage minus 5 armor should reduce HP by ~10")
	h.assert_ge(ps.hp, start_hp - 15, "Armor must mitigate incoming damage")
	h.reset_singletons(tree)
	h.end_test()


func _test_t2_locational_damage_zero_negative_overflow(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M2_locational_damage_zero_negative_overflow")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	if not h.assert_not_null(ps, "PlayerStats required"):
		h.end_test()
		return
	var start_hp: int = ps.hp
	ps.apply_locational_damage(0)
	h.assert_eq(ps.hp, start_hp, "0 raw damage must not change HP")
	ps.apply_locational_damage(-20)
	h.assert_eq(ps.hp, start_hp, "Negative raw damage must not heal or harm HP")
	ps.apply_locational_damage(9999)
	h.assert_ge(ps.hp, 0, "Overflow damage must clamp HP >= 0 (no negative HP)")
	h.reset_singletons(tree)
	h.end_test()


func _test_t2_zero_durability_armor_provides_no_protection(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M2_zero_durability_armor_broken")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	var item_script = h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(item_script, "ItemData.gd required"):
		h.end_test()
		return
	for slot_id in [1, 2, 3, 4, 5]:
		ps.equipped_items[slot_id] = _make_item(item_script, "broken_%d" % slot_id, slot_id, 10, 0)
	ps.recalculate_derived_stats()
	var start_hp: int = ps.hp
	ps.apply_locational_damage(10)
	h.assert_eq(ps.hp, start_hp - 10, "0-durability armor must provide 0 damage reduction")
	h.reset_singletons(tree)
	h.end_test()


func _test_t2_slot_type_mismatch_rejected(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M2_inventory_slot_mismatch_rejected")
	var slot_script = h.load_script_safe("res://scripts/ui/InventorySlot.gd")
	var item_script = h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(slot_script, "InventorySlot.gd required") or not h.assert_not_null(item_script, "ItemData.gd required"):
		h.end_test()
		return
	var head_slot = PanelContainer.new()
	head_slot.set_script(slot_script)
	if "allowed_slot_type" in head_slot:
		head_slot.set("allowed_slot_type", 1) # Head
		var torso_item = _make_item(item_script, "pressure_suit", 2, 10, 50)
		var drag_payload = {"item": torso_item, "source_slot": null}
		h.assert_false(head_slot._can_drop_data(Vector2.ZERO, drag_payload), "Torso item must NOT drop into Head slot")
	head_slot.queue_free()
	h.end_test()


func _test_t2_empty_and_full_backpack(tree: SceneTree, h: RefCounted) -> void:
	h.begin_test("T2_M2_empty_and_full_backpack")
	h.reset_singletons(tree)
	var ps = h.get_autoload(tree, "PlayerStats")
	var item_script = h.load_script_safe("res://scripts/resources/ItemData.gd")
	if not h.assert_not_null(ps, "PlayerStats required") or not h.assert_not_null(item_script, "ItemData.gd required"):
		h.end_test()
		return
	h.assert_eq(ps.backpack_items.size(), 0, "Fresh backpack must be empty")
	ps.recalculate_derived_stats()
	h.assert_eq(ps.total_armor, 0, "Empty equipment must yield 0 total_armor")
	for i in range(24):
		ps.backpack_items.append(_make_item(item_script, "scrap_%d" % i, 0, 0, 1))
	h.assert_ge(ps.backpack_items.size(), 20, "Backpack should hold full grid of items")
	h.reset_singletons(tree)
	h.end_test()
