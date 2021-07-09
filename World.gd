extends Node2D

var current_index = -1
const PlayerClassic = preload("res://Player/Classic/Player.tscn")
const PlayerCustom = preload("res://Player/Custom/PlayerCustom.tscn")
#var player_position := Vector2(-198, -146)
var player_position := Vector2(-499.372375, -273.656891)
var slow_mo := [1.0, 0.05, 0.005]
var slow_mo_idx = 0
var platform_msg = ""
var tmp_air_friction = Global.AIR_FRICTION

func _ready() -> void:
	$Level/Base/CollisionPolygon2D.polygon = $Level/Base/Polygon2D.polygon
	$CanvasLayer/Control/ItemList.select(0)
	set_mode(0)

func _physics_process(_delta: float) -> void:
	if not $Player: return
	var linear_vel : Vector2 = (player_position - $Player.global_position) / get_physics_process_delta_time()
	player_position = $Player.global_position
	
	$CanvasLayer/Control/Label.text = "FPS " + str(Engine.get_frames_per_second()) + '\n'
	$CanvasLayer/Control/Label.text += "Position " + str($Player.global_position) + '\n'
	$CanvasLayer/Control/Label.text += "Linear Vel " + str(linear_vel) + ' Length %.3f \n' % linear_vel.length()
	$CanvasLayer/Control/Label.text += $Player.get_velocity_str() + '\n'
	$CanvasLayer/Control/Label.text += "State: " + $Player.get_state_str()
	if $Player.raycast.is_colliding():
		$CanvasLayer/Control/Label.text += "\nSlope angle: %.3f°" % rad2deg(acos($Player.raycast.get_collision_normal().dot(Vector2.UP)))
	if Engine.time_scale != 1.0:
		$CanvasLayer/Control/Label.text += "\nTime scale : %.3f" % Engine.time_scale
	$CanvasLayer/Control/Label.text += "\nPlatform: " + platform_msg

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed('slow'):
		slow_mo_idx += 1
		Engine.time_scale = slow_mo[slow_mo_idx % slow_mo.size()]

func _on_ItemList_item_selected(index: int) -> void:
	set_mode(index)

func set_mode(index: int):
	if current_index != index:
		current_index = index
		var instance: KinematicBody2D
		if index == 0:
			instance = PlayerCustom.instance()
			ui_options(true)
		else:
			ui_options(false)
		if index == 1 or index == 2:
			instance = PlayerClassic.instance()
		if index == 2:
			instance.use_build_in = true
		if has_node("Player"):
			remove_child(get_node("Player"))
		if index == 0:
			var _silent = instance.connect("follow_platform", self, "on_platform_signal")
		add_child(instance)
		
		instance.position = player_position

func ui_options(visible: bool):
	$CanvasLayer/Control/ConstantSpeedBtn.visible = visible
	$CanvasLayer/Control/MoveOnFloorBtn.visible = visible
	$CanvasLayer/Control/SlideOnCeilingBtn.visible = visible

func on_platform_signal(message):
	platform_msg = message

func _on_StopSlopeBtn_toggled(button_pressed: bool) -> void:
	Global.STOP_ON_SLOPE = button_pressed


func _on_SnapBtn_toggled(button_pressed: bool) -> void:
	Global.APPLY_SNAP = button_pressed

func _on_ConstantSpeedBtn_toggled(button_pressed: bool) -> void:
	Global.CONSTANT_SPEED_ON_FLOOR = button_pressed

func _on_MoveOnFloorBtn_toggled(button_pressed: bool) -> void:
	Global.MOVE_ON_FLOOR_ONLY = button_pressed


func _on_JumpBtn_toggled(button_pressed: bool) -> void:
	Global.INFINITE_JUMP = button_pressed


func _on_SlideOnCeilingBtn_toggled(button_pressed: bool) -> void:
	Global.SLIDE_ON_CEILING = button_pressed


func _on_AirFrictionBtn_toggled(button_pressed: bool) -> void:
	if button_pressed:
		Global.AIR_FRICTION = tmp_air_friction
	else:
		Global.AIR_FRICTION = 0


func _on_SlowdownFallingWallBtn_toggled(button_pressed: bool) -> void:
	Global.SLOWDOWN_FALLING_WALL = button_pressed
