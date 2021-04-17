extends StaticBody

var in_move_tween : bool = false

func _ready():
	$MoveTween.connect("tween_completed", self, "on_move_tween_completed")
	pass

func apply_move_tween(target):
	in_move_tween = true
	$MoveTween.interpolate_property(
		self, "translation", translation, translation+target, Global.MOVE_TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$MoveTween.start()

func on_move_tween_completed(object,key):
	in_move_tween = false
