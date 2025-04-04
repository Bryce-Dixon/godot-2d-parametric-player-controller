@tool
## A player controller intended for 2D platformers.[br]
## Allows designers to set various player-facing values which are more intuitive and better control the player experience compared to physics-facing ones.
class_name ParametricPlayerController2D extends CharacterBody2D

## Allows easy access of the "current" [ParametricPlayerController2D] [Node][br]
## Will automatically be set by [method _ready]
static var current: ParametricPlayerController2D

## Emitted when the character begins accelerating horizontally
signal started_accelerating_horizontally
## Emitted when the character begins decelerating horizontally
signal started_decelerating_horizontally
## Emitted when the character begins moving horizontally
signal started_moving_horizontally
## Emitted when the character stops moving horizontally
signal stopped_moving_horizontally
## Emitted when the character goes from moving right to moving left
signal faced_left
## Emitted when the character goes from moving left to moving right
signal faced_right
## Emitted when the character goes from an aerial state to a grounded state
signal landed
## Emitted when the character goes from an grounded state to a aerial state by jumping
signal jumped
## Emitted when the character begins falling (their vertical velocity transitioned from up or neutral to down)
signal started_falling
## Emitted when the character has reached their max falling speed
signal reached_terminal_velocity
## Emitted when a collision occurs
signal collided(collision: KinematicCollision2D)

## Cached accessor for the [CollisionShape2D] used
var shape: CollisionShape2D:
  get:
    if not is_instance_valid(shape):
      shape = get_node_or_null(^"CollisionShape2D")
    return shape

## Determines if the character is currently facing right
var facing_right := true:
  set(value):
    if facing_right == value:
      return
    facing_right = value
    if facing_right:
      faced_right.emit()
    else:
      faced_left.emit()
## Determines if the character is currently facing left[br]
## Automatically determined as the inverse of [member facing_right]
var facing_left: bool:
  get:
    return not facing_right
  set(value):
    facing_right = not value

@export_group("Collider", "collider_")
## Radius of the [CapsuleShape2D] used by [member shape]
@export var collider_radius := 10.0:
  set(value):
    shape.shape.radius = value
    shape.position.y = shape.shape.height * -0.5
  get:
    return shape.shape.radius
## Height of the [CapsuleShape2D] used by [member shape][br]
## Setting this will automatically reposition [member shape] so its bottom is aligned to this node's position.
@export var collider_height := 30.0:
  set(value):
    shape.shape.height = value
    shape.position.y = shape.shape.height * -0.5
  get:
    return shape.shape.height

## Replace this from code under different situations to enable different movement styles (eg: walking vs running vs crouched)
@export var movement_data := ParametricPlayerController2DMovementData.new()
## Value that [member CharacterBody2D.velocity][code].x[/code] is currently moving toward.
var goal_horizontal_velocity: float
## Can be overridden to specify custom acceleration behavior (eg: dashing)
func _get_horizontal_acceleration() -> float:
  if pause_physics:
    return 0.0
  if is_decelerating_horizontally():
    if is_on_floor():
      return movement_data.deceleration
    return movement_data.deceleration * movement_data.aerial_deceleration_ratio
  if is_on_floor():
    return movement_data.acceleration
  return movement_data.acceleration * movement_data.aerial_acceleration_ratio

## Returns [code]true[/code] if the player's horizontal velocity magnitude is increasing
func is_accelerating_horizontally() -> bool:
  return (
    not pause_physics
    and sign(velocity.x) == sign(goal_horizontal_velocity)
    and absf(goal_horizontal_velocity) > 0.01
    and absf(goal_horizontal_velocity) > absf(velocity.x)
  )

## Returns [code]true[/code] if the player's horizontal velocity magnitude is decreasing
func is_decelerating_horizontally() -> bool:
  return (
    not pause_physics
    and (
      absf(goal_horizontal_velocity) < 0.01
      or sign(velocity.x) != sign(goal_horizontal_velocity)
      or absf(goal_horizontal_velocity) < absf(velocity.x)
    )
  )

@export_group("Inputs", "input_")
## Input data for moving the character left.
@export var input_left := ParametricPlayerController2DInputData.new(&"ui_left", 1)
## Input data for moving the character right.
@export var input_right := ParametricPlayerController2DInputData.new(&"ui_right", 1)
## Input data for having the player jump.
@export var input_jump := ParametricPlayerController2DInputData.new(&"ui_jump", 8)
## Buffer of the character's grounded state to allow grounded-only actions (eg: jumping) to occur a short period after the player has left the ground.
@export var input_coyote_time := ParametricPlayerController2DBitBuffer.new()
## Arbitrary list of input actions which will be kept up to date and accessible in custom scripts.
@export var input_actions: Dictionary[StringName, ParametricPlayerController2DInputData]
## If set to [code]true[/code], all inputs will be ignored and will retain their current buffer states.[br]
## Should usually be the same as [member pause_physics][br]
## If modified, it usually makes sense to call [method clear_input_buffers].
var pause_inputs := false
## If set to [code]true[/code], the character will not move.[br]
## Should usually be the same as [member pause_inputs].
var pause_physics := false

## Jump data to use when grounded.
@export var jump_data := ParametricPlayerController2DJumpData.new()
## Jump data to use when in the air (eg: double jump).[br]
## The first jump in the air after leaving the ground will be [code]aerial_jump_data[0][/code], the second would be [code]aerial_jump_data[1][/code], and so on.[br]
## This means the player will have [code]N[/code] aerial jumps where [code]N[/code] is the size of [member aerial_jump_data].
@export var aerial_jump_data: Array[ParametricPlayerController2DJumpData]
## Internal use only; determines if the player is currently holding a jump.
var _jumping := false
## Current index into [member aerial_jump_data][br]
## Reset to [code]0[/code] when becoming grounded. Incremented when [member input_jump] is pressed while in the air and [member _jumping] is [code]false[/code].
var aerial_jump_index := 0
## Maximum falling speed.[br]
## Instead of modifying this from another script, [method _get_terminal_velocity] should be overridden instead so the "default" value can be retained.
@export var terminal_velocity := 120.0
## Can be overridden to specify custom falling behavior (eg: fast-falling while holding down).
func _get_terminal_velocity() -> float:
  return terminal_velocity

## Can be overridden to specify custom falling behavior (eg: fast-falling while holding down).
func _get_gravity() -> float:
  if pause_physics:
    return 0.0
  if not _jumping and velocity.y < 0.0:
    return jump_data.get_min_height_gravity()
  return jump_data.get_max_height_gravity()

func _ready() -> void:
  if Engine.is_editor_hint():
    return
  if is_instance_valid(current):
    push_warning("Created multiple ParametricPlayerController2D simultaneously")
  else:
    current = self

## Internal use only; determines if the character was on the floor during the last [method _physics_process] call.
var _was_grounded := false
## Internal use only; tracks the ongoing collisions from [method CharacterBody2D.move_and_slide] calls.
var _active_slide_collisions: PackedInt64Array
func _physics_process(delta: float) -> void:
  if Engine.is_editor_hint():
    return
  var was_accelerationg_horizontally := is_accelerating_horizontally()
  var was_decelerationg_horizontally := is_decelerating_horizontally()
  if not pause_inputs:
    goal_horizontal_velocity = Input.get_axis(input_left.action_name, input_right.action_name) * movement_data.velocity
  if is_accelerating_horizontally() and not was_accelerationg_horizontally:
    started_accelerating_horizontally.emit()
  if is_decelerating_horizontally() and not was_decelerationg_horizontally:
    started_decelerating_horizontally.emit()
  if not pause_physics:
    var was_moving_horizontally := absf(velocity.x) > 0.1
    velocity.x = move_toward(
      velocity.x,
      goal_horizontal_velocity,
      delta * _get_horizontal_acceleration()
    )
    if velocity.x > 0.1 and facing_left:
      facing_right = true
    elif velocity.x < -0.1 and facing_right:
      facing_left = true
    if was_moving_horizontally:
      if absf(velocity.x) < 0.1:
        stopped_moving_horizontally.emit()
    elif absf(velocity.x) > 0.1:
      started_moving_horizontally.emit()
  if not pause_inputs:
    update_inputs()
    input_coyote_time.push_state(is_on_floor())
    if not _was_grounded and is_grounded():
      aerial_jump_index = 0
      landed.emit()
    _was_grounded = is_grounded()
  if can_jump() and input_jump.was_pressed():
    _jumping = true
    input_jump.buffer.fill_state(true)
    if is_grounded():
      velocity.y = jump_data.get_velocity()
      input_coyote_time.fill_state(false)
    else:
      velocity.y = aerial_jump_data[aerial_jump_index].get_velocity()
      aerial_jump_index += 1
    jumped.emit()
  if _jumping and (
    pause_inputs
    or not input_jump.is_down()
    or velocity.y >= 0.0
  ):
    _jumping = false
  var was_falling := velocity.y > 0.0
  var current_terminal_velocity := _get_terminal_velocity()
  var was_at_terminal_velocity := velocity.y >= current_terminal_velocity
  velocity.y = move_toward(velocity.y, current_terminal_velocity, delta * _get_gravity())
  if not pause_physics:
    var old_collisions := _active_slide_collisions.duplicate()
    if move_and_slide():
      for i: int in range(get_slide_collision_count()):
        var collision := get_slide_collision(i)
        var collider_id := collision.get_collider_id()
        old_collisions.erase(collider_id)
        if collider_id in _active_slide_collisions:
          continue
        _active_slide_collisions.push_back(collider_id)
        collided.emit(collision)
    for old_collision: int in old_collisions:
      _active_slide_collisions.erase(old_collision)

  if not was_falling and velocity.y > 0.0:
    started_falling.emit()
  if not was_at_terminal_velocity and velocity.y >= current_terminal_velocity:
    reached_terminal_velocity.emit()

## Updates the current state for all input data.[br]
## Should only be called by [method _physics_process] if [member pause_inputs] is [code]false[/code]
func update_inputs() -> void:
  for input: ParametricPlayerController2DInputData in [input_left, input_right, input_jump]:
    input.update_state()
  for input: ParametricPlayerController2DInputData in input_actions.values():
    input.update_state()

## Resets all input buffers as though the user hasn't pressed any of their actions for their entire duration.[br]
## Useful for returning control to the player (eg: after a cutscene or screen transition)
func clear_input_buffers() -> void:
  for input: ParametricPlayerController2DInputData in [input_left, input_right, input_jump]:
    input.buffer.fill_state(false)
  for input: ParametricPlayerController2DInputData in input_actions.values():
    input.buffer.fill_state(false)

## Resets coyote time buffers as though the user hasn't touched the ground for its entire duration.[br]
## Useful for returning control to the player (eg: after a cutscene or screen transition)
func clear_coyote_time() -> void:
  input_coyote_time.fill_state(false)

## Temporarily pauses, then restores input handling after a given delay[br]
## Returns the [Signal] which will be emitted after the delay
func pause_inputs_for(seconds: float, clear_buffers_after_restore := true) -> Signal:
  pause_inputs = true
  var timer := get_tree().create_timer(seconds)
  timer.timeout.connect(set.bind(&"pause_inputs", false))
  if clear_buffers_after_restore:
    timer.timeout.connect(clear_input_buffers)
  return timer.timeout

## Temporarily pauses, then restores physics after a given delay[br]
## Returns the [Signal] which will be emitted after the delay
func pause_physics_for(seconds: float) -> Signal:
  pause_physics = true
  var timer := get_tree().create_timer(seconds)
  timer.timeout.connect(set.bind(&"pause_physics", false))
  return timer.timeout

## Temporarily pauses, then restores input handling and physics after a given delay[br]
## Returns the [Signal] which will be emitted after the delay
func pause_inputs_and_physics_for(seconds: float, clear_input_buffers_after_restore := true) -> Signal:
  pause_physics = true
  pause_inputs = true
  var timer := get_tree().create_timer(seconds)
  timer.timeout.connect(set.bind(&"pause_inputs", false))
  timer.timeout.connect(set.bind(&"pause_physics", false))
  if clear_input_buffers_after_restore:
    timer.timeout.connect(clear_input_buffers)
  return timer.timeout

## Returns [code]true[/code] if the character in a state where jumping is permitted.
func can_jump() -> bool:
  return (
    not pause_inputs
    and not _jumping
    and (
      input_coyote_time.any_high()
      or aerial_jump_index < aerial_jump_data.size()
    )
  )

## Returns [code]true[/code] if the character is grounded according to [member input_coyote_time]'s most recent state.[br]
## Should be preferred over [method CharacterBody2D.is_on_floor].
func is_grounded() -> bool:
  return input_coyote_time.is_high()
