extends StaticBody

var size_x: int = 1
var size_z : int = 1
var in_move_tween : bool = false
var in_rot_tween : bool = false
var rot_tween_complete : bool = false
var grab_points : Array = []

onready var push_ray_cast = $PushRayCast

func _ready():
	$MoveTween.connect("tween_completed", self, "on_move_tween_completed")
	$RotTween.connect("tween_completed", self, "on_rot_tween_completed")
	init_size()
	init_grab_points()

func init_size(x=1,z=1):
	size_x = x
	size_z = z
	$CollisionShape.shape.extents = Vector3(x/2.0,0.5,z/2.0)
	$DefaultMeshInstance.mesh.size = Vector3(x,1,z)

func init_grab_points():
	var start_x = -(size_x/2.0) + 0.5
	for i in range(size_x):
		grab_points.append(Vector3(start_x+i,0,0.5+(size_z/2.0)))
		grab_points.append(Vector3(start_x+i,0,-0.5-(size_z/2.0)))
	var start_z = -(size_z/2.0) + 0.5
	for i in range(size_z):
		grab_points.append(Vector3(0.5+(size_x/2.0),0,start_z+i))
		grab_points.append(Vector3(-0.5-(size_x/2.0),0,start_z+i))
	
func apply_move_tween(target):
	in_move_tween = true
	$MoveTween.interpolate_property(
		self, "translation", translation, translation+target, Global.MOVE_TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$MoveTween.start()

func on_move_tween_completed(object,key):
	in_move_tween = false

func apply_rot_tween(target):
	in_rot_tween = true
	$CollisionShape.disabled = true
	$RotTween.interpolate_property(
		self, "rotation", rotation, Vector3(0,rotation.y+target,0), Global.ROT_TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$PushRayCast.rotation.y -= target
	$RotTween.start()

func on_rot_tween_completed(object,key):
	in_rot_tween = false
	rot_tween_complete = true
	$CollisionShape.disabled = false
