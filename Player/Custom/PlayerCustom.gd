extends KinematicBody2D
signal follow_platform(message)

onready var raycast := $RayCast2D

var velocity := Vector2(0, 0)
var GRAVITY_FORCE := Vector2(0, 2000)
var NORMAL_SPEED := 800
var RUN_SPEED := 1300
var AIR_FRICTION := 1000

var last_normal = Vector2.ZERO
var last_motion = Vector2.ZERO
var CONSTANT_SPEED_ON_FLOOR = false
var MOVE_ON_FLOOR_ONLY = true

func _process(_delta):
	update()

func _physics_process(_delta: float) -> void:

	velocity.y += GRAVITY_FORCE.y * _delta

	if  on_floor and Input.is_action_just_pressed('ui_accept'):
		velocity.y += -1000
		
	var speed = RUN_SPEED if Input.is_action_pressed('run') and on_floor else NORMAL_SPEED
	var direction = _get_direction()
	if direction.x:
		velocity.x = direction.x * speed 
	else:
		velocity.x = move_toward(velocity.x, 0, AIR_FRICTION )

	custom_move_and_slide(velocity, Vector2.UP, true, 4, deg2rad(45), true, MOVE_ON_FLOOR_ONLY, CONSTANT_SPEED_ON_FLOOR)

#	custom_snap(Vector2.DOWN * 50, Vector2.UP, true, deg2rad(45), true)
	
	if on_floor: velocity.y = 0
	if on_ceiling and velocity.y < 0: velocity.y = 0
	

func _draw():
	var icon_pos = $icon.position
	icon_pos.y -= 50
	draw_line(icon_pos, icon_pos + velocity.normalized() * 50, Color.green, 1.5)
	draw_line(icon_pos, icon_pos + last_normal * 50, Color.red, 1.5)
	if last_motion != velocity.normalized():
		draw_line(icon_pos, icon_pos + last_motion * 50, Color.orange, 1.5)

var on_floor := false
var on_floor_body:=  RID()
var on_ceiling := false
var on_wall = false
var on_air = false
var floor_normal := Vector2()
var floor_velocity := Vector2()
var FLOOR_ANGLE_THRESHOLD := 0.01
var was_on_floor = false

func custom_move_and_slide(p_linear_velocity: Vector2, p_up_direction: Vector2, p_stop_on_slope: bool, p_max_slides: int, p_floor_max_angle: float, p_infinite_inertia: bool, move_on_floor_only: bool, constant_speed_on_floor: bool):
	
	var current_floor_velocity = Vector2.ZERO
	if on_floor:
		current_floor_velocity = floor_velocity
		if on_floor_body:
			var bs := Physics2DServer.body_get_direct_state(on_floor_body)
			if bs:
				current_floor_velocity = bs.linear_velocity

	if current_floor_velocity != Vector2.ZERO: # apply platform movement first
		position += current_floor_velocity * get_physics_process_delta_time()
		emit_signal("follow_platform", str(current_floor_velocity * get_physics_process_delta_time()))
	else:
		emit_signal("follow_platform", "/")
			
	var original_motion = p_linear_velocity * get_physics_process_delta_time()
	var motion = original_motion
	
	was_on_floor = on_floor
	on_floor = false
	on_floor_body = RID()
	on_ceiling = false
	on_wall = false
	on_air = false

	floor_normal = Vector2()
	floor_velocity = Vector2()
	
	var first_slide = true
	while (p_max_slides):
		var previous_pos = position
		var collision := move_and_collide(motion, p_infinite_inertia)

		if collision:
			motion = collision.remainder
			last_normal = collision.normal # for debug

			if p_up_direction == Vector2():
				on_wall = true;
			else :
				if acos(collision.normal.dot(p_up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD:
					on_floor = true
					floor_normal = collision.normal
					floor_velocity = collision.collider_velocity
					var collision_object := collision.collider as CollisionObject2D
					on_floor_body = collision_object.get_rid()
					
					if constant_speed_on_floor and first_slide and motion != Vector2.ZERO:
						var slide = motion.slide(collision.normal).normalized()
						first_slide = false
						if slide != Vector2.ZERO:
							motion = slide * (original_motion.slide(p_up_direction).length() - collision.travel.slide(p_up_direction).length())  # alternative use original_motion.length() to also take account of the y value
					
					if p_stop_on_slope:
						if (original_motion.normalized() + p_up_direction).length() < 0.01 :
							if collision.travel.length() < 1: # more precise but maybe useless
								position = previous_pos #
							else:
								position -= collision.travel.slide(p_up_direction)
							motion = Vector2.ZERO

				elif acos(collision.normal.dot(-p_up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD :
					on_ceiling = true
				else:
					var dot = original_motion.slide(p_up_direction).normalized().dot(collision.normal)
					if move_on_floor_only and was_on_floor and dot < -0.5 and p_linear_velocity.y >= 0 :
						if collision.travel.length() < 1:
							position = previous_pos
						else:
							position -= collision.travel.slide(p_up_direction)
						on_floor = true					
						motion = (original_motion.slide(Vector2(p_up_direction.y, p_up_direction.x))) * get_physics_process_delta_time()
					else:
						on_wall = true

			motion = motion.slide(collision.normal)
		
		# debug
		if not collision: 
			print("air")
			on_air = true
		else:
			print("--")
		if motion != Vector2(): last_motion = motion.normalized() 
			
		if  not collision or motion == Vector2():
			break

		p_max_slides -= 1
		first_slide = false

func custom_snap(p_snap: Vector2,  p_up_direction: Vector2, p_stop_on_slope: bool, p_floor_max_angle: float,  p_infinite_inertia: bool):
	if p_up_direction == Vector2.ZERO or on_floor or not was_on_floor: return
	
	var collision := move_and_collide(p_snap, p_infinite_inertia, false, true)
	if collision:
		if acos(collision.normal.dot(p_up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD:
			on_floor = true
			floor_normal = collision.normal
			floor_velocity = collision.collider_velocity
			var collision_object := collision.collider as CollisionObject2D
			on_floor_body = collision_object.get_rid()
			var travelled = collision.travel
			if p_stop_on_slope:
				# move and collide may stray the object a bit because of pre un-stucking,
				# so only ensure that motion happens on floor direction in this case.
				travelled = p_up_direction * p_up_direction.dot(travelled);
			
			position += travelled

func get_state_str():
	if on_ceiling: return "ceil"
	if on_wall: return "wall"
	if on_floor: return "floor"
	if on_air: return "air"
	return "unknow"
	
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
