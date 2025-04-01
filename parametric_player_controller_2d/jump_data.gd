class_name ParametricPlayerController2DJumpData extends Resource

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

func get_velocity() -> float:
  return (-2.0 * max_height) / seconds_to_max_height

func get_max_height_gravity() -> float:
  return -get_velocity() / seconds_to_max_height

func get_min_height_gravity() -> float:
  return get_max_height_gravity() * max_height / min_height
