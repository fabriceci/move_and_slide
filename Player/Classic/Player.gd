extends KinematicBody2D

onready var raycast := $RayCast2D
var use_build_in = false

var velocity := Vector2(0, 0)

var last_normal = Vector2.ZERO
var snap = Vector2.ZERO
var was_on_floor = false

func _physics_process(delta: float) -> void:
	velocity += Global.GRAVITY_FORCE * delta
	if Global.APPLY_SNAP:
		snap = Global.SNAP_FORCE
	else:
		snap = Vector2.ZERO
	if Input.is_action_just_pressed('ui_accept') and (Global.INFINITE_JUMP or util_on_floor()):
		velocity.y += Global.JUMP_FORCE
		snap = Vector2.ZERO

	var speed = Global.RUN_SPEED if Input.is_action_pressed('run') and util_on_floor() else Global.NORMAL_SPEED
	var direction = _get_direction()
	if direction.x:
		velocity.x = direction.x * speed 
	elif util_on_floor():
		velocity.x = move_toward(velocity.x, 0, Global.GROUND_FRICTION)
	else:
		velocity.x = move_toward(velocity.x, 0, Global.AIR_FRICTION)

	if use_build_in:
		if Global.APPLY_SNAP:
			velocity = move_and_slide_with_snap(velocity, snap, Global.UP_DIRECTION, Global.STOP_ON_SLOPE, 4, deg2rad(Global.MAX_ANGLE_DEG), true)
		else:
			velocity = move_and_slide(velocity, Global.UP_DIRECTION, Global.STOP_ON_SLOPE, 4, deg2rad(Global.MAX_ANGLE_DEG), true)
		last_normal = get_floor_normal()
	else:
		velocity = gd_move_and_slide(velocity, Global.UP_DIRECTION, Global.STOP_ON_SLOPE, 4, deg2rad(Global.MAX_ANGLE_DEG), true)
		if Global.APPLY_SNAP:
			custom_snap(snap,  Global.UP_DIRECTION, Global.STOP_ON_SLOPE, deg2rad(Global.MAX_ANGLE_DEG), true)
		was_on_floor = util_on_floor()

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
 
	var motion: Vector2 = (current_floor_velocity + p_linear_velocity) * get_physics_process_delta_time()
 
	on_floor = false
	on_floor_body = RID()
	on_ceiling = false
	on_wall = false
	floor_normal = Vector2()
	floor_velocity = Vector2()
 
	# No sliding on first attempt to keep motion stable when possible.
	var sliding_enabled := false
	for i in range(p_max_slides):
		
		var found_collision := false
		var collision := move_and_collide(motion, p_infinite_inertia, true, false, not sliding_enabled)
		if not collision:
			motion = Vector2() #clear because no collision happened and motion completed
 
		if collision :
			last_normal = collision.normal # debug
			found_collision = true

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
						if (body_velocity_normal + up_direction).length() < 0.01:
							position -= collision.travel.slide(up_direction)
							return Vector2()
				elif (acos(collision.normal.dot(-up_direction)) <= p_floor_max_angle + FLOOR_ANGLE_THRESHOLD) : #ceiling
					on_ceiling = true;
				else:
					on_wall = true;
			if sliding_enabled or not on_floor:
				motion = collision.remainder.slide(collision.normal)
				body_velocity = body_velocity.slide(collision.normal)
			else:
				motion = collision.remainder
		sliding_enabled = true
		if  not found_collision or motion == Vector2():
			break

	return body_velocity

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
	if on_floor or is_on_floor(): return "floor"
	return "air"
	
func get_velocity_str():
	return "Velocity " + str(velocity)
	
static func _get_direction() -> Vector2:
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return direction
