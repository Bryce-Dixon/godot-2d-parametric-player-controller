## Physics data [ParametricPlatformerController2D] uses for jumping.[br]
## Exposes values relevant to the player experience to the inspector which are used to derive the less intuitive physics-facing values.
class_name ParametricPlatformerController2DJumpData extends Resource

## Height to reach after pressing [member input_jump_action_name] for one frame
@export var min_height := 40.0:
  set(value):
    min_height = clampf(value, 0.0, max_height)
## Height to reach after holding [member input_jump_action_name] for as long as possible
@export var max_height := 120.0:
  set(value):
    max_height = maxf(value, min_height)
## Time it takes to reach [member jump_max_height] from holding [member input_jump_action_name]
@export var seconds_to_max_height := 1.0

## Derives velocity in units per second from [member max_height] and [member seconds_to_max_height]
func get_velocity() -> float:
  return (-2.0 * max_height) / seconds_to_max_height

## Derives the constant gravity to apply for the character to reach [member max_height] with velocity from [method get_velocity].[br]
## Used if the player keeps holding jump.
func get_max_height_gravity() -> float:
  return -get_velocity() / seconds_to_max_height

## Derives the constant gravity to apply for the character to reach [member min_height] with velocity from [method get_velocity].[br]
## Used if the player presses jump for only one frame (or otherwise releases it early).
func get_min_height_gravity() -> float:
  return get_max_height_gravity() * max_height / min_height
