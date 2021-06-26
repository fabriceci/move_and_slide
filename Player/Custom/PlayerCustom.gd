extends KinematicBody2D
signal follow_platform(message)

onready var raycast := $RayCast2D

var velocity := Vector2(0, 0)
var last_normal = Vector2.ZERO
var last_motion = Vector2.ZERO

var snap = Vector2.ZERO

func _process(_delta):
	update()

func _physics_process(delta: float) -> void:
	velocity += Global.GRAVITY_FORCE * delta
	if Global.APPLY_SNAP:
		snap = Global.SNAP_FORCE
	else:
		snap = Vector2.ZERO
	if Input.is_action_just_pressed('ui_accept') and (Global.INFINITE_JUMP or on_floor):
		velocity.y += Global.JUMP_FORCE
		snap = Vector2.ZERO

	var speed = Global.RUN_SPEED if Input.is_action_pressed('run') and on_floor else Global.NORMAL_SPEED
	var direction = _get_direction()
	if direction.x:
		velocity.x = direction.x * speed 
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0, Global.GROUND_FRICTION)
	else:
		velocity.x = move_toward(velocity.x, 0, Global.AIR_FRICTION)

	velocity = custom_move_and_slide(velocity, Global.UP_DIRECTION, Global.STOP_ON_SLOPE, 4, deg2rad(Global.MAX_ANGLE_DEG), true, Global.MOVE_ON_FLOOR_ONLY, Global.CONSTANT_SPEED_ON_FLOOR, [1])	

	if on_floor: 
		velocity.y = 0
	if on_ceiling and velocity.y < 0: 
		velocity.y = 0
	
func _draw():
	var icon_pos = $icon.position
	icon_pos.y -= 50
	draw_line(icon_pos, icon_pos + velocity.normalized() * 50, Color.green, 1.5)
	draw_line(icon_pos, icon_pos + last_normal * 50, Color.red, 1.5)
	if last_motion != velocity.normalized():
		draw_line(icon_pos, icon_pos + last_motion * 50, Color.orange, 1.5)

var on_floor := false
var on_floor_body:=  RID()
var on_floor_layer:int
var on_ceiling := false
var on_wall = false
var on_air = false
var floor_normal := Vector2()
var floor_velocity := Vector2()
var FLOOR_ANGLE_THRESHOLD := 0.01
var was_on_floor = false

func custom_move_and_slide(p_linear_velocity: Vector2, p_up_direction: Vector2, p_stop_on_slope: bool, p_max_slides: int, p_floor_max_angle: float, p_infinite_inertia: bool, move_on_floor_only: bool, constant_speed_on_floor: bool, exclude_body_layer := []):
	var current_floor_velocity = Vector2.ZERO
	if on_floor:
		var excluded = false
		for layer in exclude_body_layer:
			if on_floor_layer & (1 << layer) != 0:
				excluded = true
		if not excluded:
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
	
	var prev_floor_velocity = floor_velocity
	var prev_floor_body = on_floor_body
	var prev_floor_normal = floor_normal
	was_on_floor = on_floor
	on_floor = false
	on_floor_body = RID()
	on_ceiling = false
	on_wall = false
	on_air = false

	floor_normal = Vector2()
	floor_velocity = Vector2()
	
	# No sliding on first attempt to keep floor motion stable when possible.
	var sliding_enabled := false
	var first_slide := true
	for i in range(p_max_slides):
		var continue_loop = false
		var previous_pos = position
		var collision := move_and_collide(motion, p_infinite_inertia, true, false, not sliding_enabled)

		if collision:
			last_normal = collision.normal # for debug

			if p_up_direction == Vector2():
				on_wall = true;
			else :
				if acos(collision.normal.dot(p_up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD:
					on_floor = true
					floor_normal = collision.normal
					floor_velocity = collision.collider_velocity
					on_floor_layer = collision.collider.get_collision_layer()
					var collision_object := collision.collider as CollisionObject2D
					on_floor_body = collision_object.get_rid()
					
					if p_stop_on_slope:
						if (original_motion.normalized() + p_up_direction).length() < 0.01 :
							position -= collision.travel # if we slide UP we will slide on a moving plateform (because this will switch the state to wall)
							return Vector2()

				elif acos(collision.normal.dot(-p_up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD :
					on_ceiling = true
				else:
					on_wall = true
			
			# compute motion
			if motion != Vector2.ZERO:
				# constant speed
				if on_floor and constant_speed_on_floor and first_slide:
					var slide = motion.slide(collision.normal).normalized()
					first_slide = false
					if slide != Vector2.ZERO:
						motion = slide * (original_motion.slide(p_up_direction).length() - collision.travel.slide(p_up_direction).length())  # alternative use original_motion.length() to also take account of the y value
				# prevent to move on wall
				if on_wall and move_on_floor_only:
					var dot = collision.remainder.slide(collision.normal).normalized().dot(collision.normal)
					if was_on_floor and dot < 0 and p_linear_velocity.y >= 0 : # prevent the move against wall
						print(collision.travel)
						position -= collision.travel
						on_wall = false
						on_floor = true
						on_floor_body = prev_floor_body	
						floor_velocity = prev_floor_velocity
						floor_normal = prev_floor_normal
						return Vector2.ZERO
					elif move_on_floor_only  and dot < 0: # prevent to move against the wall in the air
						motion = collision.remainder.slide(collision.normal)
						motion.x = 0
					else: # normal motion
						motion = collision.remainder.slide(collision.normal)
				elif sliding_enabled or not on_floor:
					motion = collision.remainder.slide(collision.normal)
				else:
					motion = collision.remainder
		else:
			if snap != Vector2.ZERO and was_on_floor:
				var apply_constant_speed : bool = constant_speed_on_floor and prev_floor_normal != Vector2.ZERO and first_slide
				var tmp_position = position
				if apply_constant_speed:
					position = previous_pos
				custom_snap(snap, p_up_direction, p_stop_on_slope, p_floor_max_angle, p_infinite_inertia)
				if apply_constant_speed and on_floor and motion != Vector2.ZERO:
					var slide = motion.slide(prev_floor_normal).normalized()
					if slide != Vector2.ZERO:
						motion = slide * (original_motion.slide(p_up_direction).length())  # alternative use original_motion.length() to also take account of the y value
						continue_loop = true
				elif apply_constant_speed:
					position = tmp_position
		
		sliding_enabled = true
		if not collision and not on_floor: 
			on_air = true

		# debug
		if motion != Vector2(): last_motion = motion.normalized() 
			
		if not continue_loop and (not collision or motion == Vector2()):
			break

		first_slide = false
	
	# Is there a reason (a use case) where this would not be desired?
	# However this will only work with basic up direction (left-right-up-down)
	#if on_floor: 
	#	if p_up_direction.x == 0:
	#		p_linear_velocity.y = 0
	#	else:
	#		p_linear_velocity.x = 0
	#if on_ceiling:
	#	if p_up_direction.x == 0 and p_up_direction.y < 0 and p_linear_velocity.y < 0:
	#		p_linear_velocity.y = 0
	#	elif p_up_direction.x == 0 and p_up_direction.y > 0 and p_linear_velocity.y > 0:
	#		p_linear_velocity.y = 0
	#	elif p_up_direction.y == 0 and p_up_direction.x < 0 and p_linear_velocity.x < 0:
	#		p_linear_velocity.x = 0
	#	elif p_up_direction.y == 0 and p_up_direction.x > 0 and p_linear_velocity.x > 0:
	#		p_linear_velocity.x = 0
		
	if not on_floor:
		return p_linear_velocity + current_floor_velocity # Add last floor velocity when just left a moving platform
	else:
		return p_linear_velocity

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
