@tool
class_name ParametricPlayerController2D extends CharacterBody2D

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

# Exported manually via _get_property_list
var input_left_action_name := &"ui_left"
var input_right_action_name := &"ui_right"
var input_jump_action_name := &"ui_up"

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

func _get_property_list() -> Array[Dictionary]:
  InputMap.load_from_project_settings()
  var property_list: Array[Dictionary] = [
    {
      name = &"Inputs",
      type = TYPE_NIL,
      hint_string = "input_",
      usage = PROPERTY_USAGE_GROUP
    },
    {
      name = &"input_left_action_name",
      type = TYPE_STRING_NAME,
      hint = PROPERTY_HINT_ENUM,
      hint_string = ",".join(InputMap.get_actions())
    },
    {
      name = &"input_right_action_name",
      type = TYPE_STRING_NAME,
      hint = PROPERTY_HINT_ENUM,
      hint_string = ",".join(InputMap.get_actions())
    },
    {
      name = &"input_jump_action_name",
      type = TYPE_STRING_NAME,
      hint = PROPERTY_HINT_ENUM,
      hint_string = ",".join(InputMap.get_actions())
    },
  ]
  return property_list

func _ready() -> void:
  if Engine.is_editor_hint():
    return

func _physics_process(delta: float) -> void:
  if Engine.is_editor_hint():
    return
  goal_horizontal_velocity = Input.get_axis(input_left_action_name, input_right_action_name) * movement_data.velocity
  velocity.x = move_toward(
    velocity.x,
    goal_horizontal_velocity,
    delta * _get_horizontal_acceleration()
  )
  ## TODO: Input buffering and coyote time for jumping
  if is_on_floor():
    if Input.is_action_just_pressed(input_jump_action_name):
      jumping = true
      velocity.y = jump_data.get_velocity()
  if jumping:
    if not Input.is_action_pressed(input_jump_action_name) or velocity.y >= 0.0:
      jumping = false
  velocity.y = minf(velocity.y + delta * _get_gravity(), _get_terminal_velocity())
  move_and_slide()
