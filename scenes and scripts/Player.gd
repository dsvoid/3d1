extends KinematicBody


var max_speed : float = 10.0
var move_accel : float = 60.0
var stop_accel : float = 60.0
var vel : Vector3 = Vector3()

onready var camera_rig = $CameraRig
onready var camera = $CameraRig/Camera

func _ready():
	# remove camera rotation as player moves
	camera_rig.set_as_toplevel(true)

func _physics_process(delta):
	var input_dir = Vector3.ZERO
	input_dir.x = int(Input.is_action_pressed("move_left")) - int(Input.is_action_pressed("move_right"))
	input_dir.z = int(Input.is_action_pressed("move_up")) - int(Input.is_action_pressed("move_down"))
	input_dir = input_dir.normalized()
	if input_dir == Vector3.ZERO:
		apply_friction(stop_accel * delta)
	else:
		apply_movement(input_dir * move_accel * delta)
	vel = move_and_slide(vel,Vector3.UP)
	camera_follows_player()
	
func apply_friction(amount):
	if Vector2(vel.x,vel.z).length() > amount:
		var vel_normalized = vel.normalized()
		vel.x -= vel_normalized.x * amount
		vel.z -= vel_normalized.z * amount
	else:
		vel.x = 0
		vel.z = 0

func apply_movement(amount):
	vel += amount
	var vel_clamped = Vector2(vel.x,vel.z).clamped(max_speed)
	vel.x = vel_clamped.x
	vel.z = vel_clamped.y
	
func camera_follows_player():
	camera_rig.global_transform.origin = global_transform.origin
