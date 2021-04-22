extends StaticBody

var size_x: int = 1
var size_z : int = 1
var in_rot_tween : bool = false
var rot_tween_complete : bool = false

func _ready():
	$RotTween.connect("tween_completed", self, "on_rot_tween_completed")
	size_x = $CollisionShape.shape.extents.x * 2.0
	size_z = $CollisionShape.shape.extents.z * 2.0

func apply_move_tween(target):
	$MoveTween.interpolate_property(
		self, "translation", translation, translation+target, Global.MOVE_TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$MoveTween.start()

func apply_rot_tween(target):
	in_rot_tween = true
	$CollisionShape.disabled = true
	$RotTween.interpolate_property(
		self, "rotation", rotation, Vector3(0,rotation.y+target,0), Global.ROT_TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$RotTween.start()

func on_rot_tween_completed(object,key):
	in_rot_tween = false
	rot_tween_complete = true
	$CollisionShape.disabled = false
