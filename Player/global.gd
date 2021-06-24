extends Node

# player
var GRAVITY_FORCE := Vector2(0, 2000)
var NORMAL_SPEED := 800
var RUN_SPEED := 1300
var GROUND_FRICTION := 1000
var AIR_FRICTION := 1000
var JUMP_FORCE := -1000
var INFINITE_JUMP := false
# move and slide
var APPLY_SNAP := true
var SNAP_FORCE := Vector2.UP * -50
var CONSTANT_SPEED_ON_FLOOR := true
var MOVE_ON_FLOOR_ONLY := true
var STOP_ON_SLOPE := true
var MAX_ANGLE_DEG := 45.0
var UP_DIRECTION := Vector2.UP
