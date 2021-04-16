extends Position3D

var look_sensitivity : float = 10.0
var mouse_delta : Vector2 = Vector2()

onready var player = get_parent()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

func _process(delta):
	var rot = mouse_delta.x * look_sensitivity * delta
	rotation_degrees.y -= rot
	# clear mouse delta after processing
	mouse_delta = Vector2()
