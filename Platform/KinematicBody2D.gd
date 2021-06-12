extends KinematicBody2D

var last_position = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	yield(get_tree(), "physics_frame")
	last_position = position
	

func get_velocity():
	return (position - last_position) / get_physics_process_delta_time()
