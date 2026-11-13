extends CharacterBody3D
## First-person 2.5D player controller with mouse look, WASD movement, jump, raycasts, and hybrid combat.

signal heat_changed(current_heat: float, max_heat: float, is_overheated: bool)

@export var base_speed: float = 5.0
@export var jump_velocity: float = 4.8
@export var mouse_sensitivity: float = 0.0025
@export var acceleration: float = 12.0
@export var deceleration: float = 14.0

@export var base_accuracy: float = 65.0
@export var blaster_skill: int = 10
@export var melee_skill: int = 10
@export var max_heat: float = 100.0
@export var heat_per_shot: float = 22.0
@export var cooling_rate: float = 18.0
@export var melee_drag_threshold: float = 15.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var pitch: float = 0.0

var current_heat: float = 0.0
var is_overheated: bool = false
var is_melee_mode: bool = false
var _manual_weapon_override: bool = false
var is_crouching: bool = false
var in_vent: bool = false
var is_dead: bool = false
var weapon_view: WeaponView2D = null

var _is_holding_attack: bool = false
var _attack_hold_time: float = 0.0
var _melee_drag_accum: Vector2 = Vector2.ZERO
var _melee_swung_this_hold: bool = false
var _was_in_vent_zone: bool = false

const SPARK_TEXTURE_PATH: String = "res://assets/sprites/spark_2d.png"

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var weapon_ray: RayCast3D = $Camera3D/WeaponRay


func _ready() -> void:
	add_to_group("player")
	if interact_ray != null:
		interact_ray.add_exception(self)
	if weapon_ray != null:
		weapon_ray.add_exception(self)
	if not DisplayServer.get_name().begins_with("headless") and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("equipment_changed") and not bus.equipment_changed.is_connected(_on_equipment_changed):
		bus.equipment_changed.connect(_on_equipment_changed)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		if event.is_action_pressed("reload") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R):
			var ps_dead: Node = get_node_or_null("/root/PlayerStats")
			if ps_dead != null:
				ps_dead.hp = ps_dead.max_hp
				is_dead = false
				velocity = Vector3.ZERO
				global_position = Vector3(0.0, 0.2, 2.5)
				var eb_dead: Node = get_node_or_null("/root/EventBus")
				if eb_dead != null:
					eb_dead.player_stats_changed.emit()
				_log_combat("Suit rebooted at checkpoint.", "combat")
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not DisplayServer.get_name().begins_with("headless"):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion:
		if _is_holding_attack and _is_using_melee() and not _melee_swung_this_hold:
			_melee_drag_accum += event.relative
			var mods: Dictionary = get_melee_swing_modifiers(_melee_drag_accum)
			if str(mods.get("direction", "none")) != "none":
				_melee_swung_this_hold = true
				_perform_melee_attack(mods)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(85.0), deg_to_rad(85.0))
			if camera != null:
				camera.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_1:
			set_melee_mode(false)
		elif event.keycode == KEY_2:
			set_melee_mode(true)
		elif event.keycode == KEY_C or event.keycode == KEY_CTRL:
			set_crouching(not is_crouching)
	elif event.is_action_pressed("reload"):
		reload_power_cell()
	elif event.is_action_pressed("attack"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name().begins_with("headless"):
			_is_holding_attack = true
			_attack_hold_time = 0.0
			_melee_drag_accum = Vector2.ZERO
			_melee_swung_this_hold = false
			if not _is_using_melee() and not _has_skill("overcharge_capacitor"):
				_fire_blaster(false)
	elif event.is_action_released("attack"):
		if _is_holding_attack and not _is_using_melee() and _has_skill("overcharge_capacitor"):
			var is_overcharged: bool = _attack_hold_time >= 0.75
			_fire_blaster(is_overcharged)
		_is_holding_attack = false
		_attack_hold_time = 0.0
		_melee_drag_accum = Vector2.ZERO
		_melee_swung_this_hold = false


func _physics_process(delta: float) -> void:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null and int(stats.hp) <= 0:
		if not is_dead:
			is_dead = true
			velocity = Vector3.ZERO
			_log_combat("CRITICAL: Suit integrity lost! Press [R] to reboot at checkpoint.", "combat")
		return
	elif is_dead and stats != null and int(stats.hp) > 0:
		is_dead = false

	if _is_holding_attack:
		if not DisplayServer.get_name().begins_with("headless") and not Input.is_action_pressed("attack"):
			_is_holding_attack = false
			_attack_hold_time = 0.0
			_melee_drag_accum = Vector2.ZERO
			_melee_swung_this_hold = false
		else:
			_attack_hold_time += delta

	if current_heat > 0.0:
		current_heat = maxf(0.0, current_heat - cooling_rate * delta)
		if is_overheated and current_heat <= 25.0:
			is_overheated = false
			_log_combat("Blaster capacitor cooled.", "combat")
		heat_changed.emit(current_heat, max_heat, is_overheated)

	if stats != null:
		var sp: float = float(stats.suit_power)
		var max_sp: float = float(stats.max_suit_power)
		if sp < max_sp:
			stats.suit_power = minf(max_sp, sp + 2.0 * delta)
			var bus: Node = get_node_or_null("/root/EventBus")
			if bus != null:
				bus.player_stats_changed.emit()

	# Detect Room 4 ventilation crawlspace proximity and reset on exit
	var inside_vent_box: bool = absf(global_position.x - (-4.5)) <= 1.8 and absf(global_position.z - (-40.0)) <= 3.0
	if inside_vent_box:
		in_vent = true
		_was_in_vent_zone = true
	elif _was_in_vent_zone:
		in_vent = false
		_was_in_vent_zone = false

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var reflex_bonus: float = 0.0
	var encumbrance_mult: float = 1.0
	if stats != null:
		reflex_bonus = float(int(stats.attributes.get("reflex", 5)) - 5) * 0.2
		var max_w: float = float(stats.get("max_carry_weight")) if "max_carry_weight" in stats else 25.0
		var cur_w: float = float(stats.get("total_weight")) if "total_weight" in stats else 0.0
		if cur_w > max_w and max_w > 0.0:
			encumbrance_mult = 0.65
	var crouch_mult: float = 0.65 if is_crouching else 1.0
	var target_speed: float = maxf(1.5, (base_speed + reflex_bonus) * encumbrance_mult * crouch_mult)

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta * target_speed)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta * target_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta * target_speed)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta * target_speed)

	move_and_slide()

	if Input.is_action_just_pressed("interact"):
		_try_interact()


func set_crouching(crouch: bool) -> void:
	is_crouching = crouch
	if camera != null:
		camera.position.y = 0.9 if is_crouching else 1.5


func set_melee_mode(melee: bool) -> void:
	is_melee_mode = melee
	_manual_weapon_override = true
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null:
		var wanted_token: String = "spanner" if melee else "blaster"
		var current_primary: Variant = stats.equipped_items.get(ItemData.SlotType.PRIMARY_HAND, null)
		var already_matching: bool = (
			current_primary != null
			and current_primary is Resource
			and wanted_token in str(current_primary.get("id"))
		)
		if not already_matching:
			for i in range(stats.backpack_items.size()):
				var item: Resource = stats.backpack_items[i]
				if item != null and int(item.get("slot_type")) == ItemData.SlotType.PRIMARY_HAND and wanted_token in str(item.get("id")):
					stats.backpack_items.remove_at(i)
					var prev: Resource = stats.equip_item(ItemData.SlotType.PRIMARY_HAND, item)
					if prev != null:
						stats.backpack_items.append(prev)
					stats.recalculate_derived_stats()
					break
	if weapon_view != null:
		weapon_view.set_weapon_mode(melee)
	_log_combat("Switched to %s." % ("Hydro-Spanner" if melee else "Scrappy Blaster"), "combat")


func _on_equipment_changed(slot_type: int) -> void:
	if slot_type == ItemData.SlotType.PRIMARY_HAND:
		_manual_weapon_override = false
		var melee: bool = _is_using_melee()
		is_melee_mode = melee
		if weapon_view != null:
			weapon_view.set_weapon_mode(melee)


func _is_using_melee() -> bool:
	if _manual_weapon_override:
		return is_melee_mode
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null:
		var primary: Variant = stats.equipped_items.get(ItemData.SlotType.PRIMARY_HAND, null)
		if primary != null and primary is Resource:
			var item_id: String = str(primary.get("id"))
			if bool(primary.get("is_melee_weapon")) or "spanner" in item_id or "torch" in item_id:
				return true
			if "blaster" in item_id:
				return false
	return is_melee_mode


func calculate_blaster_hit_chance(base_acc: float, skill: int, target_dist: float, enemy_evasion: float) -> float:
	var chance: float = base_acc + (float(skill) * 2.0) - (target_dist * 0.8) - enemy_evasion
	if _has_skill("jury_rigged_blaster"):
		chance += 10.0
	return clampf(chance, 5.0, 95.0)


func get_melee_swing_modifiers(drag_delta: Vector2) -> Dictionary:
	if drag_delta.length() < melee_drag_threshold:
		return {"direction": "none", "hit_mod": 0, "dmg_mult": 1.0}
	if absf(drag_delta.y) >= absf(drag_delta.x):
		if drag_delta.y < 0.0:
			return {"direction": "thrust", "hit_mod": 15, "dmg_mult": 0.8}
		return {"direction": "overhead", "hit_mod": -15, "dmg_mult": 1.3}
	if drag_delta.x < 0.0:
		return {"direction": "left_slash", "hit_mod": 0, "dmg_mult": 1.0}
	return {"direction": "right_slash", "hit_mod": 0, "dmg_mult": 1.0}


func reload_power_cell() -> bool:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats == null:
		return false
	var cell_index: int = -1
	for i in range(stats.backpack_items.size()):
		var item: Resource = stats.backpack_items[i]
		if item != null and str(item.get("id")) == "power_cell":
			cell_index = i
			break
	if cell_index < 0:
		_log_combat("No Power Cell in backpack to reload!", "combat")
		return false

	var recycled: bool = _has_skill("cell_recycler") and randf() < 0.20
	if not recycled:
		stats.backpack_items.remove_at(cell_index)
		stats.recalculate_derived_stats()
	else:
		_log_combat("Cell Recycler preserved Power Cell!", "perk")

	current_heat = 0.0
	is_overheated = false
	heat_changed.emit(current_heat, max_heat, is_overheated)
	_log_combat("Blaster reloaded with Power Cell (0% heat).", "combat")
	return true


func _fire_blaster(is_overcharged: bool = false) -> void:
	if is_overheated:
		_log_combat("Blaster OVERHEATED! Cool down or press R to reload Power Cell.", "combat")
		return

	var stats: Node = get_node_or_null("/root/PlayerStats")
	var tech_eff: float = 1.0
	if stats != null:
		var tech_val: int = int(stats.attributes.get("tech", 5))
		if tech_val > 5:
			tech_eff = clampf(1.0 - float(tech_val - 5) * 0.03, 0.5, 1.0)
	if is_overcharged:
		if stats != null and float(stats.suit_power) >= 10.0:
			stats.suit_power = maxf(0.0, float(stats.suit_power) - 10.0)
			var bus: Node = get_node_or_null("/root/EventBus")
			if bus != null:
				bus.player_stats_changed.emit()
		else:
			is_overcharged = false

	var added_heat: float = heat_per_shot * tech_eff * (2.0 if is_overcharged else 1.0)
	current_heat = minf(max_heat, current_heat + added_heat)
	if current_heat >= max_heat:
		is_overheated = true
		_log_combat("WARNING: Blaster capacitor OVERHEATED!", "combat")
	heat_changed.emit(current_heat, max_heat, is_overheated)

	if weapon_view != null:
		weapon_view.play_fire()

	if weapon_ray == null:
		return
	weapon_ray.target_position = Vector3(0.0, 0.0, -50.0)
	weapon_ray.force_raycast_update()
	if not weapon_ray.is_colliding():
		_log_combat("Blaster fired into open air.", "combat")
		return

	var collider: Object = weapon_ray.get_collider()
	var hit_pos: Vector3 = weapon_ray.get_collision_point()
	if collider == null:
		return

	if collider is EnemyHitbox or ("evasion" in collider and collider.has_method("take_damage")):
		var dist: float = global_position.distance_to(hit_pos)
		var eff_acc: float = base_accuracy + _get_reflex_acc_bonus() + _get_blaster_mod_acc_bonus()
		var enemy_evasion: float = float(collider.get("evasion"))
		var hit_chance: float = calculate_blaster_hit_chance(eff_acc, blaster_skill, dist, enemy_evasion)
		var roll: float = randf_range(0.0, 100.0)
		if roll <= hit_chance:
			var dmg: int = _roll_weapon_damage(Vector2i(8, 14)) + _get_blaster_mod_dmg_bonus()
			if is_overcharged:
				dmg *= 2
			dmg = apply_ambush_bonus(dmg, collider)
			if _roll_guile_crit():
				dmg = int(round(float(dmg) * 1.5))
			collider.call("take_damage", dmg, "blaster", false)
			_spawn_spark(hit_pos)
			_log_combat("Blaster HIT (%.0f%%, d100=%.0f) for %d dmg!" % [hit_chance, roll, dmg], "combat")
		else:
			var wall_pos: Vector3 = hit_pos
			if camera != null:
				wall_pos += (-camera.global_transform.basis.z) * 0.6
			_spawn_spark(wall_pos)
			_log_combat("Blaster MISS (%.0f%%, d100=%.0f) - ricochet!" % [hit_chance, roll], "combat")
			if _has_skill("ricochet_shot") and randf() < 0.25:
				_try_ricochet_hit(hit_pos, collider)
	elif collider.has_method("take_damage"):
		collider.call("take_damage", 10, "blaster", false)
		_spawn_spark(hit_pos)
	else:
		_spawn_spark(hit_pos)


func _perform_melee_attack(mods: Dictionary) -> void:
	var dir_name: String = str(mods.get("direction", "left_slash"))
	if weapon_view != null:
		weapon_view.play_melee_swing(dir_name)

	if weapon_ray == null:
		return
	weapon_ray.target_position = Vector3(0.0, 0.0, -2.2)
	weapon_ray.force_raycast_update()
	if not weapon_ray.is_colliding():
		_log_combat("Melee %s missed (out of range)." % dir_name, "combat")
		return

	var collider: Object = weapon_ray.get_collider()
	var hit_pos: Vector3 = weapon_ray.get_collision_point()
	if collider == null:
		return

	if collider is EnemyHitbox or ("evasion" in collider and collider.has_method("take_damage")):
		var enemy_evasion: float = float(collider.get("evasion"))
		var hit_chance: float = clampf(
			base_accuracy + float(melee_skill * 2) + float(mods.get("hit_mod", 0)) - enemy_evasion,
			5.0,
			95.0
		)
		var roll: float = randf_range(0.0, 100.0)
		if roll <= hit_chance:
			var base_dmg: int = _roll_weapon_damage(Vector2i(6, 12)) + _get_grit_melee_bonus()
			var dmg: int = maxi(1, int(round(float(base_dmg) * float(mods.get("dmg_mult", 1.0)))))
			dmg = apply_ambush_bonus(dmg, collider)
			if _roll_guile_crit():
				dmg = int(round(float(dmg) * 1.5))
			var is_stagger: bool = (dir_name == "overhead" and _has_skill("piston_strike"))
			collider.call("take_damage", dmg, "melee", is_stagger)
			_spawn_spark(hit_pos)
			_log_combat("Melee %s HIT for %d dmg!" % [dir_name, dmg], "combat")
		else:
			_log_combat("Melee %s MISSED (%.0f%%)!" % [dir_name, hit_chance], "combat")
	elif collider.has_method("take_damage"):
		collider.call("take_damage", 12, "melee", false)
		_spawn_spark(hit_pos)


func apply_ambush_bonus(base_dmg: int, collider: Object) -> int:
	if collider == null or not _has_skill("ambush_calibration"):
		return base_dmg
	var target_hb: Object = collider
	if not ("is_unaware" in target_hb) and collider is Node:
		var child_hb: Node = (collider as Node).get_node_or_null("EnemyHitbox")
		if child_hb != null:
			target_hb = child_hb
	if target_hb != null and bool(target_hb.get("is_unaware")):
		return int(round(float(base_dmg) * 1.5))
	return base_dmg


func _try_ricochet_hit(origin_pos: Vector3, excluded_hitbox: Object) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	for enemy in enemies:
		if not (enemy is Node3D):
			continue
		if enemy.get("state") == EnemyBase.State.DEAD:
			continue
		if bool(enemy.get("is_friendly")):
			continue
		var hb: Node = enemy.get_node_or_null("EnemyHitbox")
		if enemy == excluded_hitbox or hb == excluded_hitbox:
			continue
		if (enemy as Node3D).global_position.distance_to(origin_pos) <= 8.0:
			var dmg: int = maxi(1, int(round(float(_roll_weapon_damage(Vector2i(8, 14))) * 0.75)))
			if enemy.has_method("take_damage"):
				enemy.call("take_damage", dmg, "blaster", false)
				_spawn_spark((enemy as Node3D).global_position + Vector3(0.0, 0.8, 0.0))
				_log_combat("Ricochet Shot hit nearby %s for %d dmg!" % [str(enemy.get("display_name")), dmg], "perk")
				return


func _roll_weapon_damage(fallback_range: Vector2i) -> int:
	var dmg_range: Vector2i = fallback_range
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null:
		var primary: Variant = stats.equipped_items.get(ItemData.SlotType.PRIMARY_HAND, null)
		if primary != null and primary is Resource:
			var item_id: String = str(primary.get("id"))
			var item_is_melee: bool = bool(primary.get("is_melee_weapon")) or ("spanner" in item_id) or ("torch" in item_id)
			if item_is_melee == _is_using_melee():
				var r: Variant = primary.get("damage_range")
				if r is Vector2i and r.y > 0:
					dmg_range = r
	return randi_range(dmg_range.x, dmg_range.y)


func _has_modded_blaster_barrel() -> bool:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats == null:
		return false
	for slot_key in stats.equipped_items.keys():
		var eq: Variant = stats.equipped_items[slot_key]
		if eq != null and eq is Resource and str(eq.get("id")) == "modded_blaster_barrel":
			return true
	for bp in stats.backpack_items:
		if bp != null and str(bp.get("id")) == "modded_blaster_barrel":
			return true
	return false


func _get_blaster_mod_acc_bonus() -> float:
	return 10.0 if _has_modded_blaster_barrel() else 0.0


func _get_blaster_mod_dmg_bonus() -> int:
	return 3 if _has_modded_blaster_barrel() else 0


func _roll_guile_crit() -> bool:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats == null:
		return false
	var guile: int = int(stats.attributes.get("guile", 5))
	var crit_chance: float = clampf(float(maxi(0, guile - 5)) * 0.02, 0.0, 0.5)
	return crit_chance > 0.0 and randf() < crit_chance


func _get_reflex_acc_bonus() -> float:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null:
		return float(int(stats.attributes.get("reflex", 5)) - 5) * 2.0
	return 0.0


func _get_grit_melee_bonus() -> int:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null:
		return maxi(0, int(stats.attributes.get("grit", 5)) - 5)
	return 0


func _has_skill(skill_id: String) -> bool:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null and stats.has_method("has_skill"):
		return bool(stats.call("has_skill", skill_id))
	return false


func _spawn_spark(world_pos: Vector3) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var spark: Sprite3D = Sprite3D.new()
	var tex: Texture2D = load(SPARK_TEXTURE_PATH) if ResourceLoader.exists(SPARK_TEXTURE_PATH) else null
	if tex != null:
		spark.texture = tex
	spark.hframes = 4
	spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spark.pixel_size = 0.025
	parent_node.add_child(spark)
	spark.global_position = world_pos
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.create_timer(0.15).timeout.connect(func() -> void:
			if is_instance_valid(spark):
				spark.queue_free()
		)


func _log_combat(msg: String, category: String) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.combat_log_entry.emit(msg, category)


func _try_interact() -> void:
	if interact_ray == null:
		return
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return
	var collider: Object = interact_ray.get_collider()
	if collider == null:
		return
	if collider.has_method("interact"):
		collider.call("interact", self)
	elif collider is Node and collider.get_parent() != null and collider.get_parent().has_method("interact"):
		collider.get_parent().call("interact", self)


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
