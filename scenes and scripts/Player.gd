extends KinematicBody


var max_speed : float = 5.0
var move_accel : float = 40.0
var stop_accel : float = 40.0
var rot_accel : float = 8.0
var vel : Vector3 = Vector3()
var grab_dist : float = 1.9
var grab_pos : Vector3 = Vector3.ZERO
var found_grab_pos : bool = false
var grabbed_obj : StaticBody = null
var move_obj_timer : float = Global.TWEEN_DURATION
var move_obj_dir : int = 0
var in_tween : bool = false

onready var camera_rig = $CameraRig
onready var camera = $CameraRig/Camera
onready var grab_ray_cast = $GrabRayCast

func _ready():
	$Tween.connect("tween_completed", self, "on_tween_completed")
	# separate player rotation from camera rotation
	camera_rig.set_as_toplevel(true)

func _physics_process(delta):
	if Input.is_action_pressed("use_key") and $GrabRayCast.is_colliding():
		process_grab(delta)
	elif Input.is_action_just_released("use_key") and $GrabRayCast.is_colliding():
		process_release()
	else:
		process_movement(delta)
	# make sure camera follows player
	camera_rig.global_transform.origin = global_transform.origin
	# object movement input delay
	if move_obj_timer < Global.TWEEN_DURATION:
		move_obj_timer = min(move_obj_timer+delta,Global.TWEEN_DURATION)

func process_grab(delta):
	# tint grabbed object
	grabbed_obj = $GrabRayCast.get_collider()
	var new_mat = SpatialMaterial.new()
	new_mat.albedo_color = Color(0,0.7,0)
	grabbed_obj.get_node("MeshInstance").material_override = new_mat
	find_grab_pos(grabbed_obj.translation)
	# move player to object until they're aligned with it
	if not move_player_against_object(delta):
		return
	# once player is aligned they may move the object
	process_move_object()

func process_release():
	# tint released object
	var collider = $GrabRayCast.get_collider()
	var new_mat = SpatialMaterial.new()
	new_mat.albedo_color = Color(1.0,0.6,1.0)
	collider.get_node("MeshInstance").material_override = new_mat
	grabbed_obj = null
	found_grab_pos = false

func move_player_against_object(delta):
	var obj_pos = grabbed_obj.translation
	var look_dir = Vector3(translation.x - obj_pos.x, 0, translation.z - obj_pos.z)
	var look_angle = atan2(-look_dir.x,-look_dir.z)
	rotation.y = lerp_angle(rotation.y, look_angle, delta*rot_accel)
	translation = lerp(translation,grab_pos,0.15)
	var x_ready = false
	var z_ready = false
	var rot_ready = false
	if abs(translation.x - grab_pos.x) < 0.05:
		translation.x = grab_pos.x
		x_ready = true
	if abs(translation.z - grab_pos.z) < 0.05:
		translation.z = grab_pos.z
		z_ready = true
	if abs(rotation.y - look_angle) < 0.05:
		rotation.y = look_angle
		rot_ready = true
	if x_ready and z_ready and rot_ready:
		return true
	return false

func find_grab_pos(obj_pos):
	if abs(translation.x - obj_pos.x) > abs(translation.z - obj_pos.z):
		grab_pos.z = obj_pos.z
		if translation.x < obj_pos.x:
			grab_pos.x = obj_pos.x - 1
		else:
			grab_pos.x = obj_pos.x + 1
	else:
		grab_pos.x = obj_pos.x
		if translation.z < obj_pos.z:
			grab_pos.z = obj_pos.z - 1
		else:
			grab_pos.z = obj_pos.z + 1

func process_move_object():
	var inputs = determine_movement_keys()
	var forward_input = inputs[0]
	var backward_input = inputs[1]
	var obj_pos = grabbed_obj.global_transform.origin
	var forward_dir = Vector3(obj_pos.x - translation.x,0,obj_pos.z - translation.z).normalized()
	# pressing the keys moves the object
	if move_obj_timer == Global.TWEEN_DURATION:
		if Input.is_action_just_pressed(forward_input):
			print("hit forward")
			move_obj_dir = 1
		elif Input.is_action_just_pressed(backward_input):
			print("hit back")
			move_obj_dir = -1
		if move_obj_dir != 0:
			move_obj_timer = 0
			grabbed_obj.apply_tween(forward_dir * move_obj_dir)
			apply_tween(forward_dir * move_obj_dir)
			move_obj_dir = 0

func apply_tween(target):
	in_tween = true
	$Tween.interpolate_property(
		self, "translation", translation, translation+target, Global.TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$Tween.start()

func on_tween_completed(object,key):
	in_tween = false

func determine_movement_keys():
	# determine which keys move the object along the axis
	var forward_input = ""
	var backward_input = ""
	var obj_pos = grabbed_obj.global_transform.origin
	var forward_dir = (Vector2(translation.x,translation.z) - Vector2(obj_pos.x,obj_pos.z)).normalized()
	var camera_dir = Vector2(sin(camera_rig.rotation.y),cos(camera_rig.rotation.y))
	var camera_perp = Vector2(camera_dir.y,-camera_dir.x)
	var dot_cam = forward_dir.dot(camera_dir)
	var dot_perp = forward_dir.dot(camera_perp)
	if abs(dot_cam) > abs(dot_perp):
		#		   [forward input, backward input]
		if dot_cam > 0:
			return ["move_down", "move_up"]
		else:
			return ["move_up", "move_down"]
	else:
		if dot_perp > 0:
			return ["move_right", "move_left"]
		else:
			return ["move_left", "move_right"]

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
