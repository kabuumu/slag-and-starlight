extends Sprite3D
## Updates Sprite3D.frame_coords.y (0..7) based on XZ angle between camera and entity forward.
## Rows: 0=Front, 1=Front-Left, 2=Left, 3=Back-Left, 4=Back, 5=Back-Right, 6=Right, 7=Front-Right.

@export var facing_node: Node3D


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	vframes = 8


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return

	var target: Node3D = facing_node if facing_node != null else (get_parent() as Node3D)
	if target == null:
		target = self

	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	var ent_fwd: Vector3 = -target.global_transform.basis.z
	frame_coords.y = compute_direction_row(cam_fwd, ent_fwd)


func compute_direction_row(cam_fwd: Vector3, ent_fwd: Vector3) -> int:
	var cam_fwd_2d: Vector2 = Vector2(cam_fwd.x, cam_fwd.z)
	var ent_fwd_2d: Vector2 = Vector2(ent_fwd.x, ent_fwd.z)
	if cam_fwd_2d.length_squared() < 0.0001 or ent_fwd_2d.length_squared() < 0.0001:
		return 0

	cam_fwd_2d = cam_fwd_2d.normalized()
	ent_fwd_2d = ent_fwd_2d.normalized()

	var to_cam: Vector2 = -cam_fwd_2d
	var dot_val: float = to_cam.dot(ent_fwd_2d)
	var cross_val: float = to_cam.x * ent_fwd_2d.y - to_cam.y * ent_fwd_2d.x
	var angle: float = atan2(cross_val, dot_val)
	var sector: int = int(round(angle / (PI / 4.0))) % 8
	if sector < 0:
		sector += 8
	return sector
