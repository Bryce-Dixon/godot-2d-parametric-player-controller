@tool
class_name ParametricPlayerController2D extends CharacterBody2D

## Emitted when the character goes from an aerial state to a grounded state
signal landed
## Emitted when the character goes from an grounded state to a aerial state by jumping
signal jumped
## Emitted when the character begins falling (their vertical velocity transitioned from up or neutral to down)
signal started_falling
## Emitted when the character has reached their max falling speed
signal reached_terminal_velocity
## Emitted when the character begins accelerating horizontally
signal started_accelerating_horizontally
## Emitted when the character begins decelerating horizontally
signal started_decelerating_horizontally
## Emitted when the character begins moving horizontally
signal started_moving_horizontally
## Emitted when the character stops moving horizontally
signal stopped_moving_horizontally
## Emitted when a collision occurs
signal collided(other: CollisionObject2D)

var shape: CollisionShape2D:
  get:
    if not is_instance_valid(shape):
      shape = get_node_or_null(^"CollisionShape2D")
    return shape

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

@export var movement_data := ParametricPlayerController2DMovementData.new()
var goal_horizontal_velocity: float
## Can be overridden to specify custom acceleration behavior (eg: dashing)
func _get_horizontal_acceleration() -> float:
  if is_decelerating_horizontally():
    if is_on_floor():
      return movement_data.deceleration
    return movement_data.deceleration * movement_data.aerial_deceleration_ratio
  if is_on_floor():
    return movement_data.acceleration
  return movement_data.acceleration * movement_data.aerial_acceleration_ratio

func is_accelerating_horizontally() -> bool:
  return (
    sign(velocity.x) == sign(goal_horizontal_velocity)
    and absf(goal_horizontal_velocity) > 0.01
    and absf(goal_horizontal_velocity) > absf(velocity.x)
  )

func is_decelerating_horizontally() -> bool:
  return (
    absf(goal_horizontal_velocity) < 0.01
    or sign(velocity.x) != sign(goal_horizontal_velocity)
    or absf(goal_horizontal_velocity) < absf(velocity.x)
  )

@export_group("Inputs", "input_")
@export var input_left := ParametricPlayerController2dInputData.new(&"ui_left", 1)
@export var input_right := ParametricPlayerController2dInputData.new(&"ui_right", 1)
@export var input_jump := ParametricPlayerController2dInputData.new(&"ui_jump", 8)
## Buffer of the character's grounded state to allow grounded-only actions (eg: jumping) to occur a short period after the player has left the ground
@export var input_coyote_time := ParametricPlayerController2DBitBuffer.new()
## Arbitrary list of input actions which will be kept up to date and accessible in custom scripts
@export var input_actions: Dictionary[StringName, ParametricPlayerController2dInputData]

@export var jump_data := ParametricPlayerController2DJumpData.new()
var jumping := false
## Maximum falling speed
@export var terminal_velocity := 120.0
## Can be overridden to specify custom falling behavior (eg: fast-falling while holding down)
func _get_terminal_velocity() -> float:
  return terminal_velocity

## Can be overridden to specify custom falling behavior (eg: fast-falling while holding down)
func _get_gravity() -> float:
  if not jumping and velocity.y < 0.0:
    return jump_data.get_min_height_gravity()
  return jump_data.get_max_height_gravity()

func _ready() -> void:
  if Engine.is_editor_hint():
    return

var _was_grounded := false
func _physics_process(delta: float) -> void:
  if Engine.is_editor_hint():
    return
  var was_accelerationg_horizontally := is_accelerating_horizontally()
  var was_decelerationg_horizontally := is_decelerating_horizontally()
  goal_horizontal_velocity = Input.get_axis(input_left.action_name, input_right.action_name) * movement_data.velocity
  if is_accelerating_horizontally() and not was_accelerationg_horizontally:
    started_accelerating_horizontally.emit()
  if is_decelerating_horizontally() and not was_decelerationg_horizontally:
    started_decelerating_horizontally.emit()
  var was_moving_horizontally := absf(velocity.x) > 0.1
  velocity.x = move_toward(
    velocity.x,
    goal_horizontal_velocity,
    delta * _get_horizontal_acceleration()
  )
  if was_moving_horizontally:
    if absf(velocity.x) < 0.1:
      stopped_moving_horizontally.emit()
  elif absf(velocity.x) > 0.1:
    started_moving_horizontally.emit()

  update_inputs()

  input_coyote_time.push_state(is_on_floor())
  print(String.num_uint64(input_coyote_time.get_masked_buffer(), 2))
  if input_coyote_time.is_high():
    if not _was_grounded:
      _was_grounded = true
      landed.emit()
  else:
    if _was_grounded:
      _was_grounded = false
  if input_coyote_time.any_high():
    if input_jump.was_pressed():
      jumping = true
      velocity.y = jump_data.get_velocity()
      jumped.emit()
      input_coyote_time.fill_state(false)
  if jumping:
    if not input_jump.is_down() or velocity.y >= 0.0:
      jumping = false
  var was_falling := velocity.y > 0.0
  var current_terminal_velocity := _get_terminal_velocity()
  var was_at_terminal_velocity := velocity.y >= current_terminal_velocity
  velocity.y = minf(velocity.y + delta * _get_gravity(), current_terminal_velocity)
  move_and_slide()
  if not was_falling and velocity.y > 0.0:
    started_falling.emit()
  if not was_at_terminal_velocity and velocity.y >= current_terminal_velocity:
    reached_terminal_velocity.emit()

func update_inputs() -> void:
  for input: ParametricPlayerController2dInputData in [input_left, input_right, input_jump]:
    input.update_state()
  for input: ParametricPlayerController2dInputData in input_actions.values():
    input.update_state()
