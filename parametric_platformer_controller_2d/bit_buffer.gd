## Contains a history of [bool] state values packed into a 64-bit integer
class_name ParametricPlatformerController2DBitBuffer extends Resource

## How many frames to "buffer" a state.
@export_range(1, 64) var buffer_size := 4 :
  set(value):
    if value > 64:
      push_warning("buffer_size cannot be larger than 64")
    if value < 1:
      push_warning("buffer_size cannot be lower than 1")
    buffer_size = clampi(value, 1, 64)

## Holds the history of [member action_name] being pressed.[br]
## Bits with a value of [code]1[/code] are when the action was down, bits with a value of [code]0[/code] are when the action was up.[br]
## This is not limited to [member buffer_size]. Accessor methods within this class should be used to query data.
var buffer: int = 0

## Gets the size-masked buffer of states as a string of binary digits.
func get_buffer_string() -> String:
  return String.num_uint64(get_masked_buffer(), 2).pad_zeros(buffer_size)

## Gets a bitmask to apply to [member buffer] which will effectively shrink it to the requested [member buffer_size].
func get_buffer_size_mask() -> int:
  return ~(~0 << buffer_size)

## Gets [member buffer] shrunken to [member buffer_size] by applying the result of [method get_buffer_size_mask].
func get_masked_buffer() -> int:
  return buffer & get_buffer_size_mask()

## Pushes a new [bool] [param state] into [member buffer], shifting all other values.
func push_state(state: bool) -> void:
  buffer <<= 1
  if state:
    buffer |= 1

## Fills all bits of [member buffer] with the given [bool] [param state].
func fill_state(state: bool) -> void:
  if state:
    buffer = ~0
  else:
    buffer = 0

## Returns a mask of [member buffer] with bits set when the state went from [code]0[/code] to [code]1[/code] within [member buffer_size] states
func get_transition_high_bit_mask() -> int:
  return ((buffer >> 1) ^ buffer) & get_masked_buffer()

## Returns [code]true[/code] if the state went from [code]0[/code] to [code]1[/code] within [member buffer_size] states
func transitioned_high() -> bool:
  return get_transition_high_bit_mask() != 0

## Returns [code]true[/code] if the state is currently [code]1[/code]
func is_high() -> bool:
  return buffer & 1 == 1

## Returns [code]true[/code] if the state is currently [code]0[/code]
func is_low() -> bool:
  return buffer & 1 == 0

## Returns [code]true[/code] if any state in the buffer is [code]1[/code]
func any_high() -> bool:
  return get_masked_buffer() != 0

## Returns [code]true[/code] if any state in the buffer is [code]0[/code]
func any_low() -> bool:
  return get_masked_buffer() != get_buffer_size_mask()

## Returns the number of times the state transitioned from [code]0[/code] to [code]1[/code] within the input buffer window
func transition_high_count() -> int:
  var transition_mask := get_transition_high_bit_mask()
  var transition_count := 0
  while transition_mask > 0:
    if transition_mask & 1 == 1:
      transition_count += 1
    transition_mask >>= 1
  return transition_count
