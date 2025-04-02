@tool
class_name ParametricPlayerController2D extends CharacterBody2D

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

var shape: CollisionShape2D:
  get:
    if not is_instance_valid(shape):
      shape = get_node_or_null(^"CollisionShape2D")
    return shape

var facing_right := true
var facing_left: bool:
  get:
    return not facing_right
  set(value):
    facing_right = not value

@export_group("Collider", "collider_")
@export var collider_radius := 10.0:
  set(value):
    shape.shape.radius = value
    shape.position.y = shape.shape.height * -0.5
  get:
    return shape.shape.radius
@export var collider_height := 30.0:
  set(value):
    shape.shape.height = value
    shape.position.y = shape.shape.height * -0.5
  get:
    return shape.shape.height

## Replace this from code under different situations to enable different movement styles (eg: walking vs running vs crouched)
@export var movement_data := ParametricPlayerController2DMovementData.new()
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
@export var input_left := ParametricPlayerController2DInputData.new(&"ui_left", 1)
@export var input_right := ParametricPlayerController2DInputData.new(&"ui_right", 1)
@export var input_jump := ParametricPlayerController2DInputData.new(&"ui_jump", 8)
## Buffer of the character's grounded state to allow grounded-only actions (eg: jumping) to occur a short period after the player has left the ground
@export var input_coyote_time := ParametricPlayerController2DBitBuffer.new()
## Arbitrary list of input actions which will be kept up to date and accessible in custom scripts
@export var input_actions: Dictionary[StringName, ParametricPlayerController2DInputData]
## If set to [code]true[/code], all inputs will be ignored and will retain their current buffer states.[br]
## Should usually be the same as [member pause_physics][br]
## If modified, it usually makes sense to call [method clear_input_buffers]
var pause_inputs := false
## If set to [code]true[/code], the character will not move.[br]
## Should usually be the same as [member pause_inputs]
var pause_physics := false

@export var jump_data := ParametricPlayerController2DJumpData.new()
var jumping := false
## Maximum falling speed
@export var terminal_velocity := 120.0
## Can be overridden to specify custom falling behavior (eg: fast-falling while holding down)
func _get_terminal_velocity() -> float:
  return terminal_velocity

## Can be overridden to specify custom falling behavior (eg: fast-falling while holding down)
func _get_gravity() -> float:
  if pause_physics:
    return 0.0
  if not jumping and velocity.y < 0.0:
    return jump_data.get_min_height_gravity()
  return jump_data.get_max_height_gravity()

func _ready() -> void:
  if Engine.is_editor_hint():
    return
  if is_instance_valid(current):
    push_warning("Created multiple ParametricPlayerController2D simultaneously")
  else:
    current = self

var _was_grounded := false
var _active_slide_collisions: PackedInt64Array = []
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
      faced_right.emit()
    elif velocity.x < 0.1 and facing_right:
      facing_left = true
      faced_left.emit()
    if was_moving_horizontally:
      if absf(velocity.x) < 0.1:
        stopped_moving_horizontally.emit()
    elif absf(velocity.x) > 0.1:
      started_moving_horizontally.emit()
  if not pause_inputs:
    update_inputs()
    input_coyote_time.push_state(is_on_floor())
    if input_coyote_time.is_high():
      if not _was_grounded:
        _was_grounded = true
        landed.emit()
    else:
      if _was_grounded:
        _was_grounded = false
  if not pause_inputs and input_coyote_time.any_high():
    if input_jump.was_pressed():
      jumping = true
      velocity.y = jump_data.get_velocity()
      jumped.emit()
      input_coyote_time.fill_state(false)
  if jumping:
    if pause_inputs or not input_jump.is_down() or velocity.y >= 0.0:
      jumping = false
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
