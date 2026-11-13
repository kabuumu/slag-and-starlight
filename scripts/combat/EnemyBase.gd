class_name EnemyBase
extends CharacterBody3D
## Base enemy state machine (IDLE, CHASE, ATTACK, DEAD) with 8-dir billboard and PlayerStats integration.

enum State { IDLE, CHASE, ATTACK, DEAD }

@export var enemy_id: String = "enemy"
@export var display_name: String = "Enemy"
@export var max_hp: int = 30
@export var hp: int = 30
@export var evasion: int = 5
@export var attack_damage: int = 8
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.4
@export var move_speed: float = 3.2
@export var detection_range: float = 14.0
@export var xp_reward: int = 25
@export var is_stationary: bool = false
@export var is_ranged: bool = false
@export var is_friendly: bool = false

var state: State = State.IDLE
var stagger_timer: float = 0.0
var _attack_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var hitbox: EnemyHitbox = get_node_or_null("EnemyHitbox") as EnemyHitbox
@onready var sprite: Sprite3D = get_node_or_null("Billboard8Dir") as Sprite3D
@onready var body_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D


func _ready() -> void:
	add_to_group("enemies")
	if hp <= 0 and state != State.DEAD:
		hp = max_hp
	if hitbox != null:
		hitbox.evasion = evasion
		hitbox.enemy_id = enemy_id


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_stationary and not is_on_floor():
		velocity.y -= _gravity * delta

	if stagger_timer > 0.0:
		stagger_timer = maxf(0.0, stagger_timer - delta)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_stationary:
			move_and_slide()
		return

	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)

	if is_friendly:
		state = State.IDLE
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var player: Node3D = _get_player()
	if player == null:
		state = State.IDLE
		return

	var to_player: Vector3 = player.global_position - global_position
	var flat_dist: float = Vector2(to_player.x, to_player.z).length()

	var eff_detection: float = get_effective_detection_range(player)

	match state:
		State.IDLE:
			if flat_dist <= eff_detection:
				state = State.ATTACK if flat_dist <= attack_range else State.CHASE
				if hitbox != null:
					hitbox.is_unaware = false
		State.CHASE:
			_face_position(player.global_position)
			if flat_dist <= attack_range:
				state = State.ATTACK
				velocity.x = 0.0
				velocity.z = 0.0
			elif flat_dist > eff_detection * 1.5:
				state = State.IDLE
				velocity.x = 0.0
				velocity.z = 0.0
			elif not is_stationary:
				var dir: Vector3 = Vector3(to_player.x, 0.0, to_player.z).normalized()
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				move_and_slide()
		State.ATTACK:
			_face_position(player.global_position)
			velocity.x = 0.0
			velocity.z = 0.0
			if flat_dist > attack_range * 1.2:
				state = State.IDLE if is_stationary else State.CHASE
			elif _attack_timer <= 0.0:
				_perform_attack()
				_attack_timer = attack_cooldown


func _get_player() -> Node3D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as Node3D


func _face_position(target_pos: Vector3) -> void:
	var look_pos: Vector3 = Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_squared_to(look_pos) > 0.001:
		look_at(look_pos, Vector3.UP)


func _perform_attack() -> void:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	var bus: Node = get_node_or_null("/root/EventBus")
	if stats != null and stats.has_method("apply_locational_damage"):
		var res: Dictionary = stats.call("apply_locational_damage", attack_damage)
		if bus != null:
			var loc: String = str(res.get("location", "torso"))
			var dmg: int = int(res.get("final_damage", attack_damage))
			var absorbed: int = int(res.get("armor_absorbed", 0))
			bus.combat_log_entry.emit(
				"%s hits your %s for %d dmg (%d absorbed)" % [display_name, loc, dmg, absorbed],
				"enemy_attack"
			)
		if int(res.get("remaining_hp", 1)) <= 0 and is_inside_tree():
			stats.hp = maxi(1, int(stats.max_hp / 2))
			if stats.has_method("recalculate_derived_stats"):
				stats.call("recalculate_derived_stats")
			var player_node: Node3D = _get_player()
			var parent_level: Node = get_parent()
			while parent_level != null and parent_level.get_node_or_null("PlayerSpawn") == null:
				parent_level = parent_level.get_parent()
			if player_node != null and parent_level != null:
				var spawn: Node3D = parent_level.get_node_or_null("PlayerSpawn") as Node3D
				if spawn != null:
					player_node.global_position = spawn.global_position
			if bus != null:
				bus.combat_log_entry.emit("CRITICAL SUIT FAILURE! Emergency auto-stims deployed; evacuated to sector spawn.", "system")


func take_damage(amount: int, damage_type: String = "blaster", is_stagger: bool = false) -> void:
	if state == State.DEAD or amount <= 0:
		return
	hp = maxi(0, hp - maxi(0, amount))
	if hitbox != null:
		hitbox.is_unaware = false
	var bus: Node = get_node_or_null("/root/EventBus")
	if is_stagger and hp > 0:
		stagger_timer = 1.2
		if bus != null:
			bus.combat_log_entry.emit("%s staggered by %s!" % [display_name, damage_type], "combat")
	if state == State.IDLE and hp > 0 and not is_friendly:
		state = State.CHASE
	if hp <= 0:
		die()


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	hp = 0
	velocity = Vector3.ZERO
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	if hitbox != null:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	if sprite != null:
		sprite.modulate = Color(0.45, 0.25, 0.25, 0.7)
		sprite.rotation_degrees.z = 90.0

	var bus: Node = get_node_or_null("/root/EventBus")
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if bus != null:
		bus.enemy_killed.emit(enemy_id)
		bus.combat_log_entry.emit("%s destroyed! (+%d XP)" % [display_name, xp_reward], "kill")
	if stats != null and stats.has_method("add_xp"):
		stats.call("add_xp", xp_reward)


func set_friendly(friendly: bool) -> void:
	is_friendly = friendly
	if is_friendly:
		state = State.IDLE
		var bus: Node = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.combat_log_entry.emit("%s overridden: now friendly!" % display_name, "hack")


func get_effective_detection_range(player: Node3D = null) -> float:
	var target: Node3D = player if player != null else _get_player()
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null and stats.has_method("has_skill") and bool(stats.call("has_skill", "shadow_stepper")):
		if target != null:
			var crouching: bool = bool(target.get("is_crouching")) if "is_crouching" in target else false
			var venting: bool = bool(target.get("in_vent")) if "in_vent" in target else false
			if crouching or venting or target.is_in_group("in_vent"):
				return detection_range * 0.5
	return detection_range


func try_override() -> bool:
	if state == State.DEAD or is_friendly or enemy_id != "sentry_turret":
		return false
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats == null or not stats.has_method("has_skill") or not bool(stats.call("has_skill", "turret_override")):
		return false
	set_friendly(true)
	return true


func apply_capacitor_meltdown() -> bool:
	if state == State.DEAD or is_friendly:
		return false
	if not (enemy_id in ["mining_drone", "sentry_turret", "unit_734b"]):
		return false
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats == null or not stats.has_method("has_skill") or not bool(stats.call("has_skill", "capacitor_meltdown")):
		return false
	var overload_dmg: int = maxi(15, int(ceil(float(max_hp) * 0.5)))
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.combat_log_entry.emit("%s capacitor overloaded! (-%d HP, staggered)" % [display_name, overload_dmg], "hack")
	take_damage(overload_dmg, "capacitor_meltdown", true)
	return true


func interact(_player: Node = null) -> void:
	if state == State.DEAD or is_friendly:
		return
	if enemy_id == "sentry_turret" and try_override():
		return
	apply_capacitor_meltdown()
