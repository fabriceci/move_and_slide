extends KinematicBody2D


onready var tween = $Tween


func _ready() -> void:
	init()

func init():
	tween.interpolate_property(self, "position", Vector2.ZERO, Vector2(-500,-1000), 4, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.interpolate_property(self, "position", Vector2(-500,-1000), Vector2.ZERO,  4, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 4)
	tween.start()
