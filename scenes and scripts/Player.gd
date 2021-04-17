extends KinematicBody

var max_speed : float = 5.0
var move_accel : float = 40.0
var stop_accel : float = 40.0
var rot_accel : float = 8.0
var align_rot_accel : float = 12.0
var vel : Vector3 = Vector3()
var grabbed_obj : StaticBody = null
var grab_pos : Vector3 = Vector3.ZERO
var move_obj_dir : int = 0

enum {IDLE,ALIGN_WITH_OBJ,HOLD_OBJ,MOVE_OBJ}
var state : int = IDLE

var in_move_obj_tween : bool = false
var move_obj_tween_complete : bool = false
var in_align_tween : bool = false
var align_tween_complete : bool = false

func _ready():
	$MoveObjTween.connect("tween_completed", self, "on_move_obj_tween_completed")
	$AlignTween.connect("tween_completed", self, "on_align_tween_completed")
	# separate player rotation from camera rotation
	$CameraRig.set_as_toplevel(true)

func _physics_process(delta):
	match state:
		IDLE:
			state_idle(delta)
		ALIGN_WITH_OBJ:
			state_align_with_obj(delta)
		HOLD_OBJ:
			state_hold_obj(delta)
		MOVE_OBJ:
			state_move_obj(delta)
	$CameraRig.global_transform.origin = global_transform.origin

func state_idle(delta):
	process_movement(delta)
	if Input.is_action_pressed("use_key") and $GrabRayCast.is_colliding():
		grabbed_obj = $GrabRayCast.get_collider()
		var new_mat = SpatialMaterial.new()
		new_mat.albedo_color = Color(0,0.7,0)
		grabbed_obj.get_node("MeshInstance").material_override = new_mat
		find_grab_pos()
		state = ALIGN_WITH_OBJ
		return

func state_align_with_obj(delta):
	var obj_pos = grabbed_obj.global_transform.origin
	var look_dir = Vector3(translation.x - obj_pos.x, 0, translation.z - obj_pos.z)
	var look_angle = atan2(-look_dir.x,-look_dir.z)
	if align_tween_complete:
		align_tween_complete = false
		rotation.y = look_angle
		if not Input.is_action_pressed("use_key"):
			release_obj()
			state = IDLE
			return
		state = HOLD_OBJ
		return
	if not in_align_tween:
		apply_align_tween()
	rotation.y = lerp_angle(rotation.y, look_angle, delta*align_rot_accel)

func state_hold_obj(delta):
	if not Input.is_action_pressed("use_key"):
		release_obj()
		state = IDLE
		return
	var inputs = determine_movement_keys()
	var forward_input = inputs[0]
	var backward_input = inputs[1]
	var move_obj = false
	if Input.is_action_pressed(forward_input):
		move_obj_dir = 1
		move_obj = true
	elif Input.is_action_pressed(backward_input):
		move_obj_dir = -1
		move_obj = true
	if move_obj:
		state = MOVE_OBJ
		return

func state_move_obj(delta):
	if move_obj_tween_complete:
		move_obj_tween_complete = false
		state = HOLD_OBJ
		return
	if not in_move_obj_tween:
		var obj_pos = grabbed_obj.global_transform.origin
		var forward_dir = Vector3(obj_pos.x - translation.x,0,obj_pos.z - translation.z).normalized()
		grabbed_obj.apply_move_tween(forward_dir*move_obj_dir)
		apply_move_obj_tween(forward_dir*move_obj_dir)

func process_movement(delta):
	var input_dir = Vector3.ZERO
	input_dir.x = int(Input.is_action_pressed("move_left")) - int(Input.is_action_pressed("move_right"))
	input_dir.z = int(Input.is_action_pressed("move_up")) - int(Input.is_action_pressed("move_down"))
	input_dir = input_dir.normalized()
	if input_dir == Vector3.ZERO:
		apply_friction(stop_accel * delta)
	else:
		var input_rotated = Vector2(input_dir.x,input_dir.z).rotated(-$CameraRig.rotation.y)
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
	if $CameraRig.mouse_delta.x != 0:
		var rot = $CameraRig.mouse_delta.x * $CameraRig.look_sensitivity * delta
		rotation_degrees.y -= rot

func find_grab_pos():
	var obj_pos = grabbed_obj.translation
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

func release_obj():
	var new_mat = SpatialMaterial.new()
	new_mat.albedo_color = Color(1.0,0.6,1.0)
	grabbed_obj.get_node("MeshInstance").material_override = new_mat
	grabbed_obj = null

func apply_align_tween():
	in_align_tween = true
	var obj_pos = grabbed_obj.global_transform.origin
	var align_rot = atan2(-obj_pos.z+grab_pos.z,obj_pos.x-grab_pos.x)
	$AlignTween.interpolate_property(
		self, "translation", translation, grab_pos, Global.ALIGN_TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$AlignRotTween.start()
	$AlignTween.start()

func on_align_tween_completed(object,key):
	in_align_tween = false
	align_tween_complete = true

func move_player_against_obj(delta):
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

func determine_movement_keys():
	# determine which keys move the object along the axis
	var forward_input = ""
	var backward_input = ""
	var obj_pos = grabbed_obj.global_transform.origin
	var forward_dir = (Vector2(translation.x,translation.z) - Vector2(obj_pos.x,obj_pos.z)).normalized()
	var camera_dir = Vector2(sin($CameraRig.rotation.y),cos($CameraRig.rotation.y))
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

func apply_move_obj_tween(target):
	in_move_obj_tween = true
	$MoveObjTween.interpolate_property(
		self, "translation", translation, translation+target, Global.MOVE_TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$MoveObjTween.start()

func on_move_obj_tween_completed(object,key):
	in_move_obj_tween = false
	move_obj_tween_complete = true
