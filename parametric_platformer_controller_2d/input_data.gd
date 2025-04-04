@tool
## Wrapper around [InputEventAction]s which provides easier inspector functionality and input buffering.
class_name ParametricPlatformerController2DInputData extends Resource

## Name of the action to query within the [InputMap].
var action_name := &""
## How many physics frames of input to allow the user to "buffer" inputs[br]
## For example, if set to [code]4[/code], the player could press [member action_name] up to [code]4[/code] frames before landing to jump on the first available frame.
## Higher values allow for more lenient input and can feel more responsive.
var buffer := ParametricPlatformerController2DBitBuffer.new():
  set(value):
    buffer = ParametricPlatformerController2DBitBuffer.new() if value == null else value

func _init(action := &"", buffer_size := 4) -> void:
  buffer.buffer_size = buffer_size
  action_name = action

func _to_string() -> String:
  if was_pressed():
    return '[&"%s"; %s; Pressed]' % [action_name, buffer.get_buffer_string()]
  if is_down():
    return '[&"%s"; %s; Held]' % [action_name, buffer.get_buffer_string()]
  return '[&"%s"; %s; Released]' % [action_name, buffer.get_buffer_string()]

## Should be called by [class ParametricPlatformerController2D]
func update_state() -> void:
  buffer.push_state(Input.is_action_pressed(action_name))

## Returns [code]true[/code] if the action was pressed within the input buffer window
func was_pressed() -> bool:
  return buffer.transitioned_high()

## Returns [code]true[/code] if the action is currently down
func is_down() -> bool:
  return buffer.is_high()

## Returns [code]true[/code] if the action is currently up
func is_up() -> bool:
  return buffer.is_low()

## Returns the number of times the input was pressed from a released state within the input buffer window
func buffered_press_count() -> int:
  return buffer.transition_high_count()

func _get(property: StringName) -> Variant:
  match property:
    &"buffer_window":
      return buffer.buffer_size
  return null

func _set(property: StringName, value: Variant) -> bool:
  match property:
    &"buffer_window":
      buffer.buffer_size = value
      return true
  return false

func _get_property_list() -> Array[Dictionary]:
  InputMap.load_from_project_settings()
  return [
    {
      name = &"action_name",
      type = TYPE_STRING_NAME,
      hint = PROPERTY_HINT_ENUM,
      hint_string = ",".join(InputMap.get_actions()),
      usage = PROPERTY_USAGE_DEFAULT
    },
    {
      name = &"buffer_window",
      type = TYPE_INT,
      hint = PROPERTY_HINT_RANGE,
      hint_string = "1,64,1",
      usage = PROPERTY_USAGE_DEFAULT
    }
  ]
