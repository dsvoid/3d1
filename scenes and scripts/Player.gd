extends KinematicBody


var max_speed : float = 6.0
var move_accel : float = 45.0
var stop_accel : float = 45.0
var rot_accel : float = 8.0
var vel : Vector3 = Vector3()
var grab_dist : float = 1.9
var target_grab_pos : Vector3 = Vector3.ZERO
var found_grab_pos : bool = false

onready var camera_rig = $CameraRig
onready var camera = $CameraRig/Camera
onready var grab_ray_cast = $GrabRayCast

func _ready():
	# remove camera rotation as player moves
	camera_rig.set_as_toplevel(true)

func _physics_process(delta):
	if Input.is_action_pressed("use_key") and $GrabRayCast.is_colliding():
		process_grab(delta)
	elif Input.is_action_just_released("use_key") and $GrabRayCast.is_colliding():
		process_release()
		print("released")
	else:
		process_movement(delta)
	camera_follows_player()

func process_grab(delta):
	# tint grabbed object
	var collider = $GrabRayCast.get_collider()
	var new_mat = SpatialMaterial.new()
	new_mat.albedo_color = Color(0,0.7,0)
	collider.get_node("MeshInstance").material_override = new_mat
	# move player to object and rotate them towards it as well
	# ... oh shit
	move_player_against_object(collider,delta)

func process_release():
	# tint released object
	var collider = $GrabRayCast.get_collider()
	var new_mat = SpatialMaterial.new()
	new_mat.albedo_color = Color(1.0,0.6,1.0)
	collider.get_node("MeshInstance").material_override = new_mat
	found_grab_pos = false

func move_player_against_object(collider,delta):
	var obj_pos = collider.global_transform.origin
	var player_pos = translation
	if not found_grab_pos:
		find_grab_pos(player_pos,obj_pos)
		found_grab_pos = true
	var look_dir = Vector3(player_pos.x - obj_pos.x, 0, player_pos.z - obj_pos.z)
	rotation.y = lerp_angle(rotation.y, atan2(-look_dir.x,-look_dir.z), delta*rot_accel)
	translation = lerp(translation,target_grab_pos,0.15)
	if abs(translation.x - target_grab_pos.x) < 0.01:
		translation.x = target_grab_pos.x
	if abs(translation.z - target_grab_pos.z) < 0.01:
		translation.z = target_grab_pos.z

func find_grab_pos(player_pos,obj_pos):
	print("PLAYER: "+str(player_pos))
	print("OBJ: "+str(obj_pos))
	if abs(player_pos.x - obj_pos.x) > abs(player_pos.z - obj_pos.z):
		target_grab_pos.z = obj_pos.z
		if player_pos.x < obj_pos.x:
			target_grab_pos.x = obj_pos.x - 1
		else:
			target_grab_pos.x = obj_pos.x + 1
	else:
		target_grab_pos.x = obj_pos.x
		if player_pos.z < obj_pos.z:
			target_grab_pos.z = obj_pos.z - 1
		else:
			target_grab_pos.z = obj_pos.z + 1
	print("TARGET GRAB POS: "+str(target_grab_pos))

func process_movement(delta):
	var input_dir = Vector3.ZERO
	input_dir.x = int(Input.is_action_pressed("move_left")) - int(Input.is_action_pressed("move_right"))
	input_dir.z = int(Input.is_action_pressed("move_up")) - int(Input.is_action_pressed("move_down"))
	input_dir = input_dir.normalized()
	
	if input_dir == Vector3.ZERO:
		apply_friction(stop_accel * delta)
	else:
		var input_rotated = Vector2(input_dir.x,input_dir.z).rotated(-camera_rig.rotation.y)
		input_dir.x = input_rotated.x
		input_dir.z = input_rotated.y
		apply_movement(input_dir * move_accel * delta)
		apply_rotation(input_dir,delta)
	
	vel = move_and_slide(vel,Vector3.UP)

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

func apply_rotation(dir,delta):
	rotation.y = lerp_angle(rotation.y, atan2(dir.x,dir.z), delta*rot_accel)
	if camera_rig.mouse_delta.x != 0:
		var rot = camera_rig.mouse_delta.x * camera_rig.look_sensitivity * delta
		rotation_degrees.y -= rot

func camera_follows_player():
	camera_rig.global_transform.origin = global_transform.origin
