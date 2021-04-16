extends KinematicBody


var moveSpeed : float = 5.0
var vel : Vector3 = Vector3()

onready var camera = get_node("CameraOrbit")

func _ready():
	pass

func _physics_process(delta):
	
	#movement input
	vel.x = 0
	vel.z = 0
	var input = Vector3()
	
	if Input.is_action_pressed("move_left"):
		input.x += 1
	if Input.is_action_pressed("move_right"):
		input.x -= 1
	if Input.is_action_pressed("move_up"):
		input.z += 1
	if Input.is_action_pressed("move_down"):
		input.z -= 1
	
	input = input.normalized()
	var dir = (transform.basis.z * input.z + transform.basis.x * input.x)
	
	vel.x = dir.x * moveSpeed
	vel.z = dir.z * moveSpeed
	vel = move_and_slide(vel,Vector3.UP)
