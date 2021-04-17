extends StaticBody

var in_tween : bool = false

func _ready():
	$Tween.connect("tween_completed", self, "on_tween_completed")
	pass

func apply_tween(target):
	in_tween = true
	$Tween.interpolate_property(
		self, "translation", translation, translation+target, Global.TWEEN_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT
	)
	$Tween.start()

func on_tween_completed(object,key):
	in_tween = false
