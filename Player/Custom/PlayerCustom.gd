extends KinematicBody2D
signal follow_platform(message)

onready var raycast := $RayCast2D

var velocity := Vector2(0, 0)
var last_normal = Vector2.ZERO
var last_motion = Vector2.ZERO

var snap = Vector2.ZERO

var auto = false

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

	if Input.is_action_just_pressed('ui_down'):
		auto = not auto
	if Input.is_action_just_pressed('ui_up'):
		position = Vector2(-499.372375, -273.656891)

	var speed = Global.RUN_SPEED if Input.is_action_pressed('run') and on_floor else Global.NORMAL_SPEED
	var direction = _get_direction()
	if direction.x:
		velocity.x = direction.x * speed 
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0, Global.GROUND_FRICTION)
	else:
		velocity.x = move_toward(velocity.x, 0, Global.AIR_FRICTION)

	if auto:
		velocity.x = 1300
		
	velocity = custom_move_and_slide(velocity, Global.UP_DIRECTION, Global.STOP_ON_SLOPE, 4, deg2rad(Global.MAX_ANGLE_DEG), true, Global.MOVE_ON_FLOOR_ONLY, Global.CONSTANT_SPEED_ON_FLOOR, Global.SLIDE_ON_CEILING, [1])	

	if on_floor: 
		velocity.y = 0
	#if on_ceiling and velocity.y < 0:
	#	velocity.y = 0
	
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

class CustomKinematicCollision2D:
	var position : Vector2
	var normal : Vector2
	var collider : Object
	var collider_velocity : Vector2
	var travel : Vector2
	var remainder : Vector2

func custom_move_and_collide(p_motion: Vector2, p_infinite_inertia: bool = true, p_exclude_raycast_shapes: bool = true , p_test_only: bool = false, p_cancel_sliding: bool = true):
	if Global.use_default_move:
		return move_and_collide(p_motion, p_infinite_inertia, p_exclude_raycast_shapes, p_test_only)
	else:
		var gt := get_global_transform()
		
		var margin = get_safe_margin()
		
		var result := Physics2DTestMotionResult.new()
		var colliding := Physics2DServer.body_test_motion(get_rid(), gt, p_motion, p_infinite_inertia, margin, result);
		
		var result_motion := result.motion
		var result_remainder := result.motion_remainder
		
		var motion_length := p_motion.length()
		if (motion_length > 0.00001):
			var precision := 0.001

			if (colliding and p_cancel_sliding):
				# Can't just use margin as a threshold because collision depth is calculated on unsafe motion,
				# so even in normal resting cases the depth can be a bit more than the margin.
				precision += motion_length * (result.collision_unsafe_fraction - result.collision_safe_fraction)

				if (result.collision_depth > margin + precision):
					p_cancel_sliding = false

			if (p_cancel_sliding):
				# Check depth of recovery.
				var motion_normal := p_motion / motion_length
				var dot := result.motion.dot(motion_normal)
				var recovery := result.motion - motion_normal * dot
				var recovery_length := recovery.length()
				# Fixes cases where canceling slide causes the motion to go too deep into the ground,
				# Becauses we're only taking rest information into account and not general recovery.
				if (recovery_length < margin + precision):
					# Apply adjustment to motion.
					result_motion = motion_normal * dot
					result_remainder = p_motion - result_motion
		
		if (!p_test_only):
			position += result_motion
		
		if colliding:
			var collision := CustomKinematicCollision2D.new()
			collision.position = result.collision_point
			collision.normal = result.collision_normal
			collision.collider = result.collider
			collision.collider_velocity = result.collider_velocity
			collision.travel = result_motion
			collision.remainder = result_remainder
			
			return collision
		else:
			return null

func custom_move_and_slide(p_linear_velocity: Vector2, p_up_direction: Vector2 = Vector2.ZERO, p_stop_on_slope: bool = false, p_max_slides: int = 4, p_floor_max_angle: float = deg2rad(45), p_infinite_inertia: bool = true , move_on_floor_only: bool = false, constant_speed_on_floor: bool = false, slide_on_ceiling: bool = true, exclude_body_layer := []):
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
		#print("move_and_collide")
		move_and_collide(current_floor_velocity * get_physics_process_delta_time(), p_infinite_inertia, true, false, true, [on_floor_body])
		#position += current_floor_velocity * get_physics_process_delta_time()
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
	var sliding_enabled := not p_stop_on_slope
	var first_slide := true
	var can_apply_constant_speed := false
	var prev_travel := Vector2()
	
	for _i in range(p_max_slides):
		var continue_loop = false
		var previous_pos = position
		var collision = move_and_collide(motion, p_infinite_inertia, true, false, not sliding_enabled)

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
					on_floor_body = collision.get_collider_rid()
					print(on_floor_body.get_id())
					
					if p_stop_on_slope and collision.remainder.slide(p_up_direction).length() <= 0.01:
						if (original_motion.normalized() + p_up_direction).length() < 0.01 :
							if collision.travel.length() > get_safe_margin():
								position -= collision.travel.slide(p_up_direction)
							else:
								position -= collision.travel
							return Vector2()

				elif acos(collision.normal.dot(-p_up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD:
					on_ceiling = true
				else:
					on_wall = true
			
			if not on_floor:
				sliding_enabled = true
			
			# compute motion
			# constant speed
			if on_floor and constant_speed_on_floor and can_apply_constant_speed:
					var slide: Vector2 = collision.remainder.slide(collision.normal).normalized()
					if not slide.is_equal_approx(Vector2.ZERO):
						motion = slide * (original_motion.slide(p_up_direction).length() - collision.travel.slide(p_up_direction).length() - prev_travel.slide(p_up_direction).length())  # alternative use original_motion.length() to also take account of the y value
			# prevent to move against wall
			elif on_wall and move_on_floor_only and original_motion.normalized().dot(collision.normal) < 0:
				if collision.travel.dot(p_up_direction) > 0 and was_on_floor and p_linear_velocity.dot(p_up_direction) <= 0 : # prevent the move against wall
					position -= p_up_direction * p_up_direction.dot(collision.travel) # remove the x from the vector when up direction is Vector2.UP
					on_wall = false
					on_floor = true
					on_floor_body = prev_floor_body	
					floor_velocity = prev_floor_velocity
					floor_normal = prev_floor_normal
					#custom_snap(snap, p_up_direction, p_stop_on_slope, p_floor_max_angle, p_infinite_inertia) # need to test if really needed
					return Vector2.ZERO
				elif move_on_floor_only and sliding_enabled: # prevent to move against the wall in the air
					motion = p_up_direction * p_up_direction.dot(collision.remainder)
					motion = motion.slide(collision.normal)
				else:
					motion = collision.remainder
			elif sliding_enabled and not (on_ceiling and not slide_on_ceiling and p_linear_velocity.dot(p_up_direction) > 0):
				motion = collision.remainder.slide(collision.normal)
				if slide_on_ceiling and on_ceiling and p_linear_velocity.dot(p_up_direction) > 0:
					p_linear_velocity = p_linear_velocity.slide(collision.normal)
				elif slide_on_ceiling and on_ceiling: # remove x when fall to avoid acceleration
					p_linear_velocity = p_up_direction * p_up_direction.dot(p_linear_velocity) 
			else:
				motion = collision.remainder
				if on_ceiling and not slide_on_ceiling and p_linear_velocity.dot(p_up_direction) > 0:
					p_linear_velocity = p_linear_velocity.slide(p_up_direction)
					motion = motion.slide(p_up_direction)
					
		else:
			can_apply_constant_speed = first_slide
			if snap != Vector2.ZERO and was_on_floor:
				var apply_constant_speed : bool = constant_speed_on_floor and prev_floor_normal != Vector2.ZERO and can_apply_constant_speed
				var tmp_position = position
				if apply_constant_speed:
					position = previous_pos
				custom_snap(snap, p_up_direction, p_stop_on_slope, p_floor_max_angle, p_infinite_inertia)
				if apply_constant_speed and on_floor and motion != Vector2.ZERO:
					var slide: Vector2 = motion.slide(prev_floor_normal).normalized()
					if not slide.is_equal_approx(Vector2.ZERO):
						motion = slide * (original_motion.slide(p_up_direction).length())  # alternative use original_motion.length() to also take account of the y value
						continue_loop = true
				elif apply_constant_speed:
					position = tmp_position
		
		sliding_enabled = true
		can_apply_constant_speed = not can_apply_constant_speed and sliding_enabled
		first_slide = false
		
		if collision:
			prev_travel = collision.travel

		if not collision and not on_floor: 
			on_air = true

		# debug
		if not motion.is_equal_approx(Vector2()): last_motion = motion.normalized() 
			
		if not continue_loop and (not collision or motion.is_equal_approx(Vector2())):
			break
		
	if not on_floor:
		return p_linear_velocity + current_floor_velocity # Add last floor velocity when just left a moving platform
	else:
		return p_linear_velocity

func custom_snap(p_snap: Vector2,  p_up_direction: Vector2, p_stop_on_slope: bool = false , p_floor_max_angle: float = deg2rad(45),  p_infinite_inertia: bool = true):
	if p_up_direction == Vector2.ZERO or on_floor or not was_on_floor: return
	
	var collision = move_and_collide(p_snap, p_infinite_inertia, false, true)
	if collision:
		if acos(collision.normal.dot(p_up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD:
			on_floor = true
			floor_normal = collision.normal
			floor_velocity = collision.collider_velocity
			on_floor_body = collision.get_collider_rid()
			var travelled = collision.travel
			if p_stop_on_slope:
				# move and collide may stray the object a bit because of pre un-stucking,
				# so only ensure that motion happens on floor direction in this case.
				if travelled.length() > get_safe_margin() :
					travelled = p_up_direction * p_up_direction.dot(travelled);
				else:
					travelled = Vector2.ZERO
			
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
