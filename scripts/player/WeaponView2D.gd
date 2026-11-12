class_name WeaponView2D
extends AnimatedSprite2D
## First-person 2D weapon view anchored bottom-right of HUDLayer with velocity sine-wave bobbing.

@export var bob_frequency: float = 9.0
@export var bob_amplitude: Vector2 = Vector2(8.0, 6.0)
@export var base_position: Vector2 = Vector2(256.0, 152.0)

var _bob_time: float = 0.0
var _swing_offset: Vector2 = Vector2.ZERO
var _swing_rot: float = 0.0
var _is_melee: bool = false
var _player_ref: Node = null


func _ready() -> void:
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_sprite_frames()
	if base_position == Vector2.ZERO:
		base_position = position
	else:
		position = base_position
	animation_finished.connect(_on_animation_finished)
	play("blaster_idle")


func _setup_sprite_frames() -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	var blaster_idle_tex: Texture2D = load("res://assets/weapons/blaster_idle.png")
	var blaster_fire_tex: Texture2D = load("res://assets/weapons/blaster_fire.png")
	var spanner_idle_tex: Texture2D = load("res://assets/weapons/spanner_idle.png")
	var spanner_swing_tex: Texture2D = load("res://assets/weapons/spanner_swing.png")

	frames.add_animation("blaster_idle")
	frames.set_animation_loop("blaster_idle", true)
	if blaster_idle_tex != null:
		frames.add_frame("blaster_idle", blaster_idle_tex)

	frames.add_animation("blaster_fire")
	frames.set_animation_loop("blaster_fire", false)
	frames.set_animation_speed("blaster_fire", 14.0)
	if blaster_fire_tex != null:
		frames.add_frame("blaster_fire", blaster_fire_tex)
	if blaster_idle_tex != null:
		frames.add_frame("blaster_fire", blaster_idle_tex)

	frames.add_animation("spanner_idle")
	frames.set_animation_loop("spanner_idle", true)
	if spanner_idle_tex != null:
		frames.add_frame("spanner_idle", spanner_idle_tex)

	frames.add_animation("spanner_swing")
	frames.set_animation_loop("spanner_swing", false)
	frames.set_animation_speed("spanner_swing", 12.0)
	if spanner_swing_tex != null:
		frames.add_frame("spanner_swing", spanner_swing_tex)
	if spanner_idle_tex != null:
		frames.add_frame("spanner_swing", spanner_idle_tex)

	sprite_frames = frames


func compute_bob_offset(horizontal_speed: float, delta: float) -> Vector2:
	if horizontal_speed <= 0.05:
		_bob_time = 0.0
		return Vector2.ZERO
	_bob_time += delta * bob_frequency
	var speed_scale: float = clampf(horizontal_speed / 5.0, 0.2, 2.0)
	var ox: float = cos(_bob_time) * bob_amplitude.x * speed_scale
	var oy: float = absf(sin(_bob_time)) * bob_amplitude.y * speed_scale
	return Vector2(ox, oy)


func _process(delta: float) -> void:
	var speed: float = 0.0
	if _player_ref == null or not is_instance_valid(_player_ref):
		var tree: SceneTree = get_tree()
		if tree != null:
			_player_ref = tree.get_first_node_in_group("player")
	if _player_ref != null and _player_ref.has_method("get_horizontal_speed"):
		speed = float(_player_ref.call("get_horizontal_speed"))

	var bob: Vector2 = compute_bob_offset(speed, delta)
	_swing_offset = _swing_offset.lerp(Vector2.ZERO, minf(1.0, delta * 14.0))
	_swing_rot = lerpf(_swing_rot, 0.0, minf(1.0, delta * 14.0))
	position = base_position + bob + _swing_offset
	rotation = _swing_rot


func set_weapon_mode(melee: bool) -> void:
	_is_melee = melee
	play("spanner_idle" if _is_melee else "blaster_idle")


func play_fire() -> void:
	_is_melee = false
	_swing_offset = Vector2(8.0, 12.0)
	play("blaster_fire")


func play_melee_swing(direction: String) -> void:
	_is_melee = true
	match direction:
		"thrust":
			_swing_offset = Vector2(-14.0, -22.0)
			_swing_rot = -0.1
		"overhead":
			_swing_offset = Vector2(0.0, 26.0)
			_swing_rot = 0.15
		"left_slash":
			_swing_offset = Vector2(-28.0, 6.0)
			_swing_rot = -0.35
		"right_slash":
			_swing_offset = Vector2(28.0, 6.0)
			_swing_rot = 0.35
		_:
			_swing_offset = Vector2(-16.0, 10.0)
			_swing_rot = -0.2
	play("spanner_swing")


func _on_animation_finished() -> void:
	play("spanner_idle" if _is_melee else "blaster_idle")
