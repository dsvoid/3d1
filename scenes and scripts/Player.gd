extends KinematicBody

var max_speed : float = 5.0
var move_accel : float = 40.0
var stop_accel : float = 40.0
var rot_accel : float = 8.0
var align_rot_accel : float = 12.0
var vel : Vector3 = Vector3()
var grabbed_obj : StaticBody = null
var grab_pos : Vector3 = Vector3()
var move_dir : Vector3 = Vector3()
var rot_obj_dir : float = 0.0
var look_dir : Vector3 = Vector3()
var pivot_diff : Vector3 = Vector3()
enum {IDLE,ALIGN_WITH_OBJ,HOLD_OBJ,MOVE_OBJ,ROT_OBJ,PIVOT_OBJ}
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
		ROT_OBJ:
			state_rot_obj(delta)
		PIVOT_OBJ:
			state_pivot_obj(delta)
	$CameraRig.global_transform.origin = global_transform.origin

func state_idle(delta):
	process_movement(delta)
	if Input.is_action_pressed("use_key") and $GrabRayCast.is_colliding():
		grabbed_obj = $GrabRayCast.get_collider()
		var new_mat = SpatialMaterial.new()
		new_mat.albedo_color = Color(0,0.7,0)
		grabbed_obj.get_node("DefaultMeshInstance").material_override = new_mat
		find_grab_pos()
		state = ALIGN_WITH_OBJ
		return

func state_align_with_obj(delta):
	var obj_pos = grabbed_obj.global_transform.origin
	# TODO: update formula for arbitrarily sized MovableObj
	if abs(obj_pos.x - grab_pos.x) > abs(obj_pos.z - grab_pos.z):
		if grab_pos.x < obj_pos.x:
			look_dir = Vector3(1,0,0)
		else:
			look_dir = Vector3(-1,0,0)
	else:
		if grab_pos.z < obj_pos.z:
			look_dir = Vector3(0,0,1)
		else:
			look_dir = Vector3(0,0,-1)
	var look_angle = atan2(-look_dir.z,look_dir.x)
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
	var rot_cw_input = inputs[2]
	var rot_ccw_input = inputs[3]
	var move_obj = false
	var rot_obj = false
	var pivot_obj = false
	var valid_player_back_movement = true
	var obj_pos = grabbed_obj.global_transform.origin
	grab_pos = global_transform.origin
	if Input.is_action_pressed(forward_input) or Input.is_action_pressed(backward_input):
		move_obj = true
		# check for potential collisions before allowing forward movement
		var valid_player_place = true
		if Input.is_action_pressed(forward_input):
			move_dir = Vector3(cos(rotation.y), 0, -sin(rotation.y))
		else:
			move_dir = Vector3(-cos(rotation.y), 0, sin(rotation.y))
			var behind_raycast = RayCast.new()
			add_child(behind_raycast)
			behind_raycast.global_transform.origin = global_transform.origin + move_dir
			behind_raycast.global_transform.origin.y = 2.5
			behind_raycast.set_cast_to(Vector3(0,-2,0))
			behind_raycast.set_collision_mask_bit(1,true)
			behind_raycast.set_collision_mask_bit(2,true)
			behind_raycast.set_enabled(true)
			behind_raycast.force_raycast_update()
			if behind_raycast.is_colliding():
				valid_player_back_movement = false
			behind_raycast.queue_free()
		var coll_points = []
		if(abs(move_dir.x) > abs(move_dir.z)):
			for z in grabbed_obj.size_z:
				var coll_x = obj_pos.x + (((grabbed_obj.size_x/2.0) + 0.5) * move_dir.x)
				var coll_z = obj_pos.z - (grabbed_obj.size_z/2.0) + 0.5 + z
				coll_points.append(Vector3(coll_x, 2.5, coll_z))
		else:
			for x in grabbed_obj.size_x:
				var coll_x = obj_pos.x - (grabbed_obj.size_x/2.0) + 0.5 + x
				var coll_z = obj_pos.z + (((grabbed_obj.size_z/2.0) + 0.5) * move_dir.z)
				coll_points.append(Vector3(coll_x, 2.5, coll_z))
		for coll_point in coll_points:
			var raycast = RayCast.new()
			add_child(raycast)
			raycast.global_transform.origin = coll_point
			raycast.set_cast_to(Vector3(0,-2,0))
			raycast.set_collision_mask_bit(1,true)
			raycast.set_collision_mask_bit(2,true)
			raycast.set_enabled(true)
			raycast.force_raycast_update()
			if raycast.is_colliding():
				move_obj = false
				raycast.queue_free()
				break
			raycast.queue_free()
	elif Input.is_action_pressed(rot_cw_input) or Input.is_action_pressed(rot_ccw_input):
		if Input.is_action_pressed(rot_cw_input):
			rot_obj_dir = -PI/2
		elif Input.is_action_pressed(rot_ccw_input):
			rot_obj_dir = PI/2
		if grabbed_obj.size_x == grabbed_obj.size_z:
			rot_obj = true
		else:
			pivot_obj = true
			# determine if collision would occur before pivoting
			var perp_dir = look_dir.rotated(Vector3.UP,rot_obj_dir)
			var coll_points = []
			if(grabbed_obj.size_x > grabbed_obj.size_z):
				var add_z = sign(rot_obj_dir) * sign(grab_pos.x - obj_pos.x)
				if look_dir.x != 0:
					add_z = perp_dir.z
				for x in range(grabbed_obj.size_x):
					var coll_x = obj_pos.x - 0.5 + x
					var coll_z = obj_pos.z + add_z
					coll_points.append(Vector3(coll_x, 2.5, coll_z))
			else:
				var add_x = sign(rot_obj_dir) * -sign(grab_pos.z - obj_pos.z)
				if look_dir.z != 0:
					add_x = perp_dir.x
				for z in range(grabbed_obj.size_z):
					var coll_x = obj_pos.x + add_x
					var coll_z = obj_pos.z - 0.5 + z
					coll_points.append(Vector3(coll_x, 2.5, coll_z))
			for coll_point in coll_points:
				var raycast = RayCast.new()
				add_child(raycast)
				raycast.global_transform.origin = coll_point
				raycast.set_cast_to(Vector3(0,-2,0))
				raycast.set_collision_mask_bit(0,true)
				raycast.set_collision_mask_bit(1,true)
				raycast.set_collision_mask_bit(2,true)
				raycast.set_exclude_parent_body(false)
				raycast.set_enabled(true)
				raycast.force_raycast_update()
				if raycast.is_colliding():
					pivot_obj = false
					raycast.queue_free()
					break
				raycast.queue_free()
			# modify origin point of object for simple rotation appearance
			if pivot_obj:
				var pivot_point = grab_pos + look_dir
				pivot_diff = obj_pos - pivot_point
				pivot_diff.y = 0
				grabbed_obj.global_transform.origin -= pivot_diff
				grabbed_obj.get_node("CollisionShape").global_transform.origin += pivot_diff
				grabbed_obj.get_node("DefaultMeshInstance").global_transform.origin += pivot_diff
	if move_obj and valid_player_back_movement:
		state = MOVE_OBJ
	elif rot_obj:
		state = ROT_OBJ
	elif pivot_obj:
		state = PIVOT_OBJ

func state_move_obj(delta):
	if move_obj_tween_complete:
		move_obj_tween_complete = false
		state = HOLD_OBJ
		return
	if not in_move_obj_tween:
		var obj_pos = grabbed_obj.global_transform.origin
		var forward_dir = Vector3(cos(rotation.y), 0, -sin(rotation.y))
		grabbed_obj.apply_move_tween(move_dir)
		apply_move_obj_tween(move_dir)

func state_rot_obj(delta):
	if grabbed_obj.rot_tween_complete:
		grabbed_obj.rot_tween_complete = false
		state = HOLD_OBJ
		return
	if not grabbed_obj.in_rot_tween:
		grabbed_obj.apply_rot_tween(rot_obj_dir)

func state_pivot_obj(delta):
	if grabbed_obj.rot_tween_complete:
		var post_diff = pivot_diff.rotated(Vector3.UP,rot_obj_dir)
		grabbed_obj.global_transform.origin += post_diff
		grabbed_obj.get_node("CollisionShape").translation = Vector3.ZERO
		grabbed_obj.get_node("DefaultMeshInstance").translation = Vector3.ZERO
		var mid = grabbed_obj.size_x
		grabbed_obj.size_x = grabbed_obj.size_z
		grabbed_obj.size_z = mid
		grabbed_obj.rot_tween_complete = false
		state = HOLD_OBJ
		return
	if not grabbed_obj.in_rot_tween:
		grabbed_obj.apply_rot_tween(rot_obj_dir)
	
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
	rotation.y = lerp_angle(rotation.y, atan2(-dir.z,dir.x), delta*rot_accel)
	if $CameraRig.mouse_delta.x != 0:
		var rot = $CameraRig.mouse_delta.x * $CameraRig.look_sensitivity * delta
		rotation_degrees.y -= rot

func find_grab_pos():
	var obj_pos = grabbed_obj.global_transform.origin
	var grab_points = []
	for x in range(grabbed_obj.size_x):
		var grab_x = obj_pos.x - (grabbed_obj.size_x/2.0) + 0.5 + x
		var grab_z_north = obj_pos.z - (grabbed_obj.size_z/2.0) - 0.5
		var grab_z_south = obj_pos.z + (grabbed_obj.size_z/2.0) + 0.5
		grab_points.append(Vector3(grab_x, 0, grab_z_north))
		grab_points.append(Vector3(grab_x, 0, grab_z_south))
	for z in range(grabbed_obj.size_z):
		var grab_z = obj_pos.z - (grabbed_obj.size_z/2.0) + 0.5 + z
		var grab_x_west = obj_pos.x - (grabbed_obj.size_x/2.0) - 0.5
		var grab_x_east = obj_pos.x + (grabbed_obj.size_x/2.0) + 0.5
		grab_points.append(Vector3(grab_x_west, 0, grab_z))
		grab_points.append(Vector3(grab_x_east, 0, grab_z))
	var grab_distances = []
	for i in range(grab_points.size()):
		grab_distances.append(global_transform.origin.distance_to(grab_points[i]))
	grab_pos = grab_points[grab_distances.find(grab_distances.min())]

func release_obj():
	vel = Vector3.ZERO
	var new_mat = SpatialMaterial.new()
	new_mat.albedo_color = Color(1.0,0.6,1.0)
	grabbed_obj.get_node("DefaultMeshInstance").material_override = new_mat
	grabbed_obj = null

func apply_align_tween():
	in_align_tween = true
	var obj_pos = grabbed_obj.global_transform.origin
	var align_rot = atan2(-obj_pos.z+grab_pos.z,obj_pos.x-grab_pos.x)
	$AlignTween.interpolate_property(
		self, "translation", translation, grab_pos, Global.ALIGN_TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$AlignTween.start()

func on_align_tween_completed(object,key):
	in_align_tween = false
	align_tween_complete = true

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
		#		   [forward input, backward input, rotate cw input, rotate ccw input]
		if dot_cam > 0:
			return ["move_down", "move_up", "move_right", "move_left"]
		else:
			return ["move_up", "move_down", "move_left", "move_right"]
	else:
		if dot_perp > 0:
			return ["move_right", "move_left", "move_up", "move_down"]
		else:
			return ["move_left", "move_right", "move_down", "move_up"]

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
