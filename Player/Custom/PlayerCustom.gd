extends KinematicBody2D

onready var raycast := $RayCast2D

var velocity := Vector2(0, 0)
var gravity := Vector2(0, 2000)
var NORMAL_SPEED := 800
var RUN_SPEED := 1300
var AIR_FRICTION := 1000

var last_normal = Vector2.ZERO
var last_motion = Vector2.ZERO
var constant_speed = false
var move_on_floor_only = true

func _process(delta):
	update()

func _physics_process(delta: float) -> void:

	if  Input.is_action_just_pressed('ui_accept'):
		velocity.y = -1000
		
	var speed = RUN_SPEED if Input.is_action_pressed('run') and on_floor else NORMAL_SPEED
	var direction = _get_direction()
	if direction.x:
		velocity.x = direction.x * speed 
	else:
		velocity.x = move_toward(velocity.x, 0, AIR_FRICTION )

	velocity = custom_move_and_slide(velocity, Vector2.UP, true, 4, deg2rad(45), true, gravity, move_on_floor_only, constant_speed)

func _draw():
	var icon_pos = $icon.position
	icon_pos.y -= 50
	draw_line(icon_pos, icon_pos + velocity.normalized() * 50, Color.green, 1.5)
	draw_line(icon_pos, icon_pos + last_normal * 50, Color.red, 1.5)
	draw_line(icon_pos, icon_pos + last_motion * 50, Color.orange, 1.5)

var on_floor := false
var on_floor_body = RID()
var on_ceiling := false
var on_wall = false
var floor_normal := Vector2()
var floor_velocity := Vector2()
var FLOOR_ANGLE_THRESHOLD := 0.01
var accumated_gravity = Vector2.ZERO

func custom_move_and_slide(p_linear_velocity: Vector2, p_up_direction: Vector2, p_stop_on_slope: bool, p_max_slides: int, p_floor_max_angle: float, p_infinite_inertia: bool, gravity: Vector2, move_on_floor_only: bool, constant_speed: bool):
	gravity = gravity * get_physics_process_delta_time()

	if p_linear_velocity.y < 0: # to do: do not use y and same below
		accumated_gravity.y = 0
		p_linear_velocity.y =  min(0, p_linear_velocity.y + gravity.y)
	else:
		accumated_gravity += gravity

	var body_velocity = p_linear_velocity * get_physics_process_delta_time()
	var velocity = p_linear_velocity
	var velocity_normalized = velocity.normalized()
	
	var current_floor_velocity := floor_velocity
	if on_floor and on_floor_body:
		var bs := Physics2DServer.body_get_direct_state(on_floor_body)
		if bs:
			current_floor_velocity = bs.linear_velocity
			
	var original_motion = (current_floor_velocity + velocity + accumated_gravity) * get_physics_process_delta_time()
	var motion = original_motion
	
	var prev_on_floor = on_floor
	on_floor = false
	on_ceiling = false
	on_wall = false
	floor_normal = Vector2()
	floor_velocity = Vector2()
	
	var first_collision = true
	while (p_max_slides):
	
		var collision := move_and_collide(motion, p_infinite_inertia)

		if collision:
			motion = collision.remainder
			last_normal = collision.normal # for debug
			if constant_speed and first_collision and motion != Vector2.ZERO:
				var slide = motion.slide(collision.normal).normalized()
				first_collision = false
				if slide != Vector2.ZERO:
					motion = slide * (original_motion.length() - collision.travel.length())
			if p_up_direction == Vector2():
				# all is a wall
				on_wall = true;
				accumated_gravity = Vector2.ZERO
			else :
				if acos(collision.normal.dot(p_up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD:
					on_floor = true
					floor_normal = collision.normal
					floor_velocity = collision.collider_velocity
					if p_stop_on_slope:
						if p_linear_velocity == Vector2.ZERO:
							position -= collision.travel.slide(p_up_direction)
							motion = Vector2.ZERO

					velocity.y = 0
					accumated_gravity = Vector2.ZERO
				elif acos(collision.normal.dot(-p_up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD :
					on_ceiling = true
					velocity.y = 0
				else:
					if not move_on_floor_only:
						accumated_gravity = Vector2.ZERO
					if move_on_floor_only and prev_on_floor and original_motion.normalized().dot(collision.normal) < -0.5 :
						motion = ( floor_velocity + accumated_gravity) * get_physics_process_delta_time()
					on_wall = true

			motion = motion.slide(collision.normal)

		if motion != Vector2(): last_motion = motion.normalized() # debug
			
		if  not collision or motion == Vector2():
			break

		--p_max_slides
	
	return velocity

func get_state_str():
	if on_ceiling: return "ceil"
	if on_wall: return "wall"
	if on_floor: return "floor"
	return "air"
	
func get_velocity_str():
	return "Velocity " + str(velocity)
	
static func _get_direction() -> Vector2:
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return direction
	
#static func custom_slide(velocity: Vector2, normal: Vector2) -> Vector2:
#	velocity.y=0
#	return velocity - normal * velocity.dot(normal)
