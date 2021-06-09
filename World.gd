extends Node2D

onready var n_pol2D = $Level/StaticBody2D/Polygon2D
onready var n_collisionPol2d = $Level/StaticBody2D/CollisionPolygon2D
var current_index = -1
var mode = ["custom", "custom + const speed", "classic GDScript", "classic c++"]
const PlayerClassic = preload("res://Player/Classic/Player.tscn")
const PlayerCustom = preload("res://Player/Custom/PlayerCustom.tscn")
var player_position := Vector2(-198, -146)
var slow_mo := [1.0, 0.01, 0.005]
var slow_mo_idx = 0

func _ready() -> void:
	$Level/StaticBody2D/CollisionPolygon2D.polygon = $Level/StaticBody2D/Polygon2D.polygon
	$CanvasLayer/Control/ItemList.select(0)
	set_mode(0)

func _physics_process(delta: float) -> void:
	if not $Player: return
	var linear_vel : Vector2 = player_position - $Player.global_position
	player_position = $Player.global_position
	$CanvasLayer/Control/Label.text = "Position " + str($Player.global_position) + '\n'
	$CanvasLayer/Control/Label.text += "Linear Vel " + str(linear_vel) + ' Length %.3f \n' % linear_vel.length()
	$CanvasLayer/Control/Label.text += $Player.get_velocity_str() + '\n'
	$CanvasLayer/Control/Label.text += "Is on floor: " + str($Player.on_floor or $Player.is_on_floor())
	if $Player.raycast.is_colliding():
		$CanvasLayer/Control/Label.text += "\nSlope angle: %.3f°" % rad2deg(acos($Player.raycast.get_collision_normal().dot(Vector2.UP)))
	if Engine.time_scale != 1.0:
		$CanvasLayer/Control/Label.text += "\nTime scale : %.3f" % Engine.time_scale

func _process(delta: float) -> void:
	if Input.is_action_just_pressed('slow'):
		slow_mo_idx += 1
		Engine.time_scale = slow_mo[slow_mo_idx % slow_mo.size()]

		
func _on_ItemList_item_selected(index: int) -> void:
	set_mode(index)

func set_mode(index: int):
	$CanvasLayer/Control/ModeLabel.text = "Mode :" + mode[index]
	if current_index != index:
		current_index = index
		var instance: KinematicBody2D
		if index == 0 or index == 1:
			instance = PlayerCustom.instance()
		if index == 2 or index == 3:
			instance = PlayerClassic.instance()
		if index == 1:
			instance.constant_speed = true
		if index == 3:
			instance.use_build_in = true
		remove_child(get_node("Player"))
		add_child(instance)
		instance.position = player_position
