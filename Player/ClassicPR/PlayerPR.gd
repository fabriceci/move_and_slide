extends KinematicBody2D
signal follow_platform(message)

onready var raycast := $RayCast2D

var velocity := Vector2(0, 0)
var gravity := Vector2(0, 2000)
var NORMAL_SPEED := 800
var RUN_SPEED := 1300
var AIR_FRICTION := 1000

var last_normal = Vector2.ZERO

var cpt := 0.0
func _physics_process(delta: float) -> void:
	
	velocity.y += gravity.y * delta
	cpt += delta
	if on_floor and  Input.is_action_just_pressed('ui_accept'):
		
		print("JUMP : " + str(int(cpt)))
		velocity.y += -1000
		
	var speed = RUN_SPEED if Input.is_action_pressed('run') and util_on_floor() else NORMAL_SPEED
	var direction = _get_direction()
	if direction.x:
		velocity.x = direction.x * speed 
	else:
		velocity.x = move_toward(velocity.x, 0, AIR_FRICTION )

	velocity = gd_move_and_slide(velocity, Vector2.UP, true, 4, deg2rad(45), true)
	
	if util_on_floor():
		velocity.y = 0
	
var on_floor := false
var on_floor_body:=  RID()
var on_ceiling := false
var on_wall = false
var floor_normal := Vector2()
var floor_velocity := Vector2()
var FLOOR_ANGLE_THRESHOLD := 0.01
 
func gd_move_and_slide(p_linear_velocity: Vector2, p_up_direction: Vector2, p_stop_on_slope: bool, p_max_slides: int, p_floor_max_angle: float, p_infinite_inertia: bool):
	var body_velocity := p_linear_velocity
	var body_velocity_normal := body_velocity.normalized()
	var up_direction := p_up_direction.normalized()
 
	var current_floor_velocity := floor_velocity
	if on_floor and on_floor_body:
		var bs := Physics2DServer.body_get_direct_state(on_floor_body)
		if bs:
			current_floor_velocity = bs.linear_velocity
 
	if current_floor_velocity != Vector2.ZERO: # apply platform movement first
		position += current_floor_velocity * get_physics_process_delta_time()
		emit_signal("follow_platform", str(current_floor_velocity * get_physics_process_delta_time()))
	else:
		emit_signal("follow_platform", "/")
	
	var motion: Vector2 = (p_linear_velocity) * get_physics_process_delta_time()
 
	on_floor = false
	on_floor_body = RID()
	on_ceiling = false
	on_wall = false
	floor_normal = Vector2()
	floor_velocity = Vector2()
 
	while (p_max_slides):
		var collision : KinematicCollision2D
		var found_collision := false
 
		collision = move_and_collide(motion, p_infinite_inertia)
		if not collision:
			motion = Vector2() #clear because no collision happened and motion completed
 
		if collision :
			last_normal = collision.normal # debug
			found_collision = true
			motion = collision.remainder;
 
			if up_direction == Vector2():
				# all is a wall
				on_wall = true;
			else :
				if (acos(collision.normal.dot(up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD): # floor
 
					on_floor = true
					floor_normal = collision.normal
					var collision_object := collision.collider as CollisionObject2D
					on_floor_body = collision_object.get_rid()
					floor_velocity = collision.collider_velocity
				
					if p_stop_on_slope:
						if (body_velocity_normal + up_direction).length() < 0.01 and collision.travel.length() < 1 :
							position -= collision.travel.slide(up_direction)
							return Vector2()
				elif (acos(collision.normal.dot(-up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD) : #ceiling
					on_ceiling = true;
				else:
					on_wall = true;
 
			motion = motion.slide(collision.normal);
			body_velocity = body_velocity.slide(collision.normal);
 
		if  not found_collision or motion == Vector2():
			break
 
		if not collision: 
			print("air")
		else:
			print("--")
		p_max_slides -= 1
 
	return body_velocity

func _process(_delta):
	update()
	
func _draw():
	var icon_pos = $icon.position
	icon_pos.y -= 50
	draw_line(icon_pos, icon_pos + velocity.normalized() * 50, Color.green, 1.5)
	draw_line(icon_pos, icon_pos + last_normal * 50, Color.red, 1.5)
	
func util_on_floor():
	return is_on_floor() or on_floor

func get_state_str():
	if on_ceiling or is_on_ceiling(): return "ceil"
	if on_wall or is_on_wall(): return "wall"
	if on_floor or is_on_ceiling(): return "floor"
	return "air"
	
func get_velocity_str():
	return "Velocity " + str(velocity)
	
static func _get_direction() -> Vector2:
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return direction
