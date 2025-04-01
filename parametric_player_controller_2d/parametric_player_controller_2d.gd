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

@export var movement_types: Dictionary[StringName, ParametricPlayerController2DMovementData] = {
  &"walking": null
}:
  set(value):
    for key: StringName in value.keys():
      if key in movement_types and value[key] == null:
        continue
      elif key.strip_edges().is_empty():
        continue
      movement_types[key] = ParametricPlayerController2DMovementData.new() if value[key] == null else value[key]
    for key: StringName in movement_types.keys():
      if key not in value:
        movement_types.erase(key)
    if movement_types.size() == 0:
      movement_types[&"walking"] = ParametricPlayerController2DMovementData.new()
    if default_movement_type_name not in movement_types.keys():
      default_movement_type_name = movement_types.keys().front()
    notify_property_list_changed()

var default_movement_type_name: StringName:
  set(value):
    if value not in movement_types.keys():
      push_warning("Attempting to set default_movement_type_name to an invalid value")
      return
    default_movement_type_name = value
  get:
    if default_movement_type_name not in movement_types.keys():
      return &""
    return default_movement_type_name

@onready var current_movement_type_name: StringName = default_movement_type_name:
  set(value):
    if value not in movement_types.keys():
      push_warning("Attempting to set current_movement_type_name to an invalid value")
      return
    current_movement_type_name = value
  get:
    if current_movement_type_name not in movement_types.keys():
      return default_movement_type_name
    return current_movement_type_name
var current_movement_type: ParametricPlayerController2DMovementData:
  get:
    return movement_types.get(current_movement_type_name, movement_types.get(default_movement_type_name))
  set(_value):
    push_warning("current_movement_type is read-only")

var input_left_action_name := &"ui_left"
var input_right_action_name := &"ui_right"
var input_jump_action_name := &"ui_up"

@export_group("Jumping", "jump_")
## Height to reach after pressing [member input_jump_action_name] for one frame
@export var jump_min_height := 40.0
## Height to reach after holding [member input_jump_action_name] for as long as possible
@export var jump_max_height := 40.0

func _get_property_list() -> Array[Dictionary]:
  var property_list: Array[Dictionary] = [
    {
      name = &"default_movement_type_name",
      type = TYPE_STRING,
      hint = PROPERTY_HINT_ENUM,
      hint_string = ",".join(movement_types.keys())
    },
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
  var goal_horizontal_velocity := Input.get_axis(input_left_action_name, input_right_action_name) * current_movement_type.velocity
  velocity.x = move_toward(
    velocity.x,
    goal_horizontal_velocity,
    delta * (current_movement_type.deceleration if is_zero_approx(goal_horizontal_velocity) else current_movement_type.acceleration)
  )
  move_and_slide()
  prints("velocity:", velocity)
