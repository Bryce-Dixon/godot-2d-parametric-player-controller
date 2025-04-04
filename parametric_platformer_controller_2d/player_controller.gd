@tool
## A player controller intended for 2D platformers.[br]
## Allows designers to set various player-facing values which are more intuitive and better control the player experience compared to physics-facing ones.
class_name ParametricPlatformerController2D extends CharacterBody2D

## Allows easy access of the "current" [ParametricPlatformerController2D] [Node][br]
## Will automatically be set by [method _ready]
static var current: ParametricPlatformerController2D

## Emitted when the character begins accelerating horizontally.
signal started_accelerating_horizontally
## Emitted when the character begins decelerating horizontally.
signal started_decelerating_horizontally
## Emitted when the character begins moving horizontally.
signal started_moving_horizontally
## Emitted when the character stops moving horizontally.
signal stopped_moving_horizontally
## Emitted when the character goes from moving right to moving left.
signal faced_left
## Emitted when the character goes from moving left to moving right.
signal faced_right
## Emitted when the character goes from an aerial state to a grounded state.
signal landed
## Emitted when the character jumps (regardless of type).
signal jumped
## Emitted when the character jumps while grounded.
signal grounded_jump
## Emitted when the character jumps while in the air.
signal aerial_jump(index: int)
## Emitted when the character jumps while against a wall, but not grounded.
signal wall_jump
## Emitted when the character begins falling (their vertical velocity transitioned from up or neutral to down).
signal started_falling
## Emitted when the character has reached their max falling speed.
signal reached_terminal_velocity
## Emitted when a collision occurs.
signal collided(collision: KinematicCollision2D)

## Cached accessor for the [CollisionShape2D] used for collision.
var shape: CollisionShape2D:
  get:
    if not is_instance_valid(shape):
      shape = get_node_or_null(^"CollisionShape2D")
    return shape

## Cached accessor for the [Area2D] used for detecting if there's a wall left of the character.
var left_wall_sensor: Area2D:
  get:
    if not is_instance_valid(left_wall_sensor):
      left_wall_sensor = get_node_or_null(^"LeftWallSensor")
    return left_wall_sensor

## Cached accessor for the [Area2D] used for detecting if there's a wall right of the character.
var right_wall_sensor: Area2D:
  get:
    if not is_instance_valid(right_wall_sensor):
      right_wall_sensor = get_node_or_null(^"RightWallSensor")
    return right_wall_sensor

## Cached accessor for the [CollisionShape2D] used for detecting if there's a wall left of the character.
var left_wall_sensor_shape: CollisionShape2D:
  get:
    if not is_instance_valid(left_wall_sensor_shape):
      left_wall_sensor_shape = get_node_or_null(^"LeftWallSensor/CollisionShape2D")
    return left_wall_sensor_shape

## Cached accessor for the [CollisionShape2D] used for detecting if there's a wall right of the character.
var right_wall_sensor_shape: CollisionShape2D:
  get:
    if not is_instance_valid(right_wall_sensor_shape):
      right_wall_sensor_shape = get_node_or_null(^"RightWallSensor/CollisionShape2D")
    return right_wall_sensor_shape

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
    _update_collider_shapes()
  get:
    return shape.shape.radius
## Height of the [CapsuleShape2D] used by [member shape].[br]
## Setting this will automatically reposition [member shape] so its bottom is aligned to this node's position.
@export var collider_height := 30.0:
  set(value):
    shape.shape.height = value
    _update_collider_shapes()
  get:
    return shape.shape.height

## Internal use only; updates all collider shapes to match inspector values.
func _update_collider_shapes() -> void:
  if not shape:
    return
  shape.position = Vector2(0.0, shape.shape.height * -0.5)
  var main_shape_rectangle_height: float = shape.shape.height - shape.shape.radius * 2.0

  if not left_wall_sensor or not right_wall_sensor:
    return
  if not left_wall_sensor_shape or not right_wall_sensor_shape:
    return
  left_wall_sensor.position = Vector2(-shape.shape.radius, shape.position.y)
  var is_sideways := wall_jump_detection_thickness > main_shape_rectangle_height
  if not is_sideways:
    left_wall_sensor_shape.shape.radius = wall_jump_detection_thickness
    left_wall_sensor_shape.shape.height = main_shape_rectangle_height
    left_wall_sensor_shape.rotation = 0.0
    left_wall_sensor_shape.position.x = 0.0
  else:
    left_wall_sensor_shape.shape.radius = main_shape_rectangle_height * 0.5
    left_wall_sensor_shape.shape.height = wall_jump_detection_thickness
    left_wall_sensor_shape.rotation = PI * 0.5
    left_wall_sensor_shape.position.x = -left_wall_sensor_shape.shape.height * 0.5 + left_wall_sensor_shape.shape.radius

  right_wall_sensor.position = Vector2(shape.shape.radius, shape.position.y)
  right_wall_sensor_shape.shape.radius = left_wall_sensor_shape.shape.radius
  right_wall_sensor_shape.shape.height = left_wall_sensor_shape.shape.height
  right_wall_sensor_shape.rotation = left_wall_sensor_shape.rotation
  right_wall_sensor_shape.position.x = -left_wall_sensor_shape.position.x

  var right_wall_sensor_left_edge: float = (right_wall_sensor.position.x + right_wall_sensor_shape.position.x) - right_wall_sensor_shape.shape.radius
  if right_wall_sensor_left_edge < -shape.shape.radius:
    var new_thickness: float = shape.shape.radius * 2.0 - 0.01
    push_warning("Player controller's left and right wall sensors are overlapping, which will cause wall detection issues. Shrinking wall_jump_detection_thickness from %f to %f..." % [wall_jump_detection_thickness, new_thickness])
    wall_jump_detection_thickness = new_thickness

## If [code]true[/code], the character will teleport to the closest ground (if there is any) on [method _ready].
@export var spawn_grounded := true

## Replace this from code under different situations to enable different movement styles (eg: walking vs running vs crouched)
@export var movement_data := ParametricPlatformerController2DMovementData.new()
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

## Returns [code]true[/code] if the character's horizontal velocity magnitude is increasing
func is_accelerating_horizontally() -> bool:
  return (
    not pause_physics
    and signf(velocity.x) == signf(goal_horizontal_velocity)
    and absf(goal_horizontal_velocity) > 0.01
    and absf(goal_horizontal_velocity) > absf(velocity.x)
  )

## Returns [code]true[/code] if the character's horizontal velocity magnitude is decreasing
func is_decelerating_horizontally() -> bool:
  return (
    not pause_physics
    and (
      absf(goal_horizontal_velocity) < 0.01
      or signf(velocity.x) != signf(goal_horizontal_velocity)
      or absf(goal_horizontal_velocity) < absf(velocity.x)
    )
  )

@export_group("Inputs", "input_")
## Input data for moving the character left.
@export var input_left := ParametricPlatformerController2DInputData.new(&"ui_left", 1)
## Input data for moving the character right.
@export var input_right := ParametricPlatformerController2DInputData.new(&"ui_right", 1)
## Input data for having the character jump.
@export var input_jump := ParametricPlatformerController2DInputData.new(&"ui_jump", 8)
## Buffer of the character's grounded state to allow grounded-only actions (eg: jumping) to occur a short period after the character has left the ground.
@export var input_floor_coyote_time := ParametricPlatformerController2DBitBuffer.new()
## Arbitrary list of input actions which will be kept up to date and accessible in custom scripts.
@export var input_actions: Dictionary[StringName, ParametricPlatformerController2DInputData]
## If set to [code]true[/code], all inputs will be ignored and will retain their current buffer states.[br]
## Should usually be the same as [member pause_physics][br]
## If modified, it usually makes sense to call [method clear_input_buffers].
var pause_inputs := false
## If set to [code]true[/code], the character will not move.[br]
## Should usually be the same as [member pause_inputs].
var pause_physics := false

## Jump data to use when grounded.
@export var jump_data := ParametricPlatformerController2DJumpData.new()
## Internal use only; tracks the last jump data used to determine appropriate gravity.
var _last_jump_data: ParametricPlatformerController2DJumpData:
  get:
    if not is_instance_valid(_last_jump_data):
      _last_jump_data = jump_data
    return _last_jump_data
## Jump data to use when in the air (eg: double jump).[br]
## The first jump in the air after leaving the ground will be [code]aerial_jump_data[0][/code], the second would be [code]aerial_jump_data[1][/code], and so on.[br]
## This means the character will have [code]N[/code] aerial jumps where [code]N[/code] is the size of [member aerial_jump_data].
@export var aerial_jump_data: Array[ParametricPlatformerController2DJumpData]

@export_group("Wall Jump", "wall_jump_")
## Jump data to use when not grounded, but against a wall.[br]
## If [code]null[/code], wall jumping will be disabled.
@export var wall_jump_data: ParametricPlatformerController2DJumpData
## Ratio of [member movement_data] speed to use away from the wall while wall jumping.[br]
## If [code]1.0[/code], the character will immediately reach max movement speed away from the wall when wall jumping.[br]
## If [code]0.5[/code], the character will immediately reach half of their max movement speed away from the wall when wall jumping.[br]
## If [code]0.0[/code], the character will not gain any speed and hug the wall while wall jumping.
@export_range(0.0, 1.0, 0.01, "or_greater") var wall_jump_horizontal_velocity_ratio := 1.0
## The character will constantly have the velocity determined by [member wall_jump_horizontal_velocity_ratio] applied while rising from a wall jump foor this ratio of vertical speed.[br]
## If [code]1.0[/code], the character will continue moving away from the wall until they start falling.[br]
## If [code]0.5[/code], the character will continue moving away from the wall until they are only rising at half of their wall-jump speed.[br]
## If [code]0.0[/code], the character will only have the horizontal velocity applied for the frame of the jump.
@export_range(0.0, 1.0, 0.01) var wall_jump_rising_ratio_to_apply_horizontal_velocity := 1.0
## Thickness of the [Area2D]s used to determine if there's a wall able to be jumped off of
@export_range(0.1, 1000, 0.1, "or_greater", "hide_slider") var wall_jump_detection_thickness := 4.0:
  set(value):
    wall_jump_detection_thickness = value
    _update_collider_shapes()
## Similar to [member CollisionObject2D.collision_mask], used to determine which physics materials count as wall-jumpable surfaces
@export_flags_2d_physics var wall_jump_collision_mask: int = collision_mask:
  set(value):
    wall_jump_collision_mask = value
    if left_wall_sensor:
      left_wall_sensor.collision_mask = wall_jump_collision_mask
    if right_wall_sensor:
      right_wall_sensor.collision_mask = wall_jump_collision_mask
## Internal use only; holds the last collided wall's normal
var _last_wall_jump_normal: Vector2

## Usually used only by wall jumping, but can be overridden for custom behavior involving jumping setting the character's horizontal velocity.[br]
## Return [code]velocity.x[/code] to leave velocity unchanged.
func _get_jump_horizontal_velocity(_for_grounded_jump: bool, for_wall_jump: bool, _for_aerial_jump: bool) -> float:
  if for_wall_jump:
    var velocity_sign := signf(_last_wall_jump_normal.x)
    return wall_jump_horizontal_velocity_ratio * movement_data.velocity * velocity_sign
  return velocity.x

## Internal use only; determines if the player is currently holding a jump.
var _jumping := false
## Current index into [member aerial_jump_data][br]
## Reset to [code]0[/code] when becoming grounded. Incremented when [member input_jump] is pressed while in the air and [member _jumping] is [code]false[/code].
var aerial_jump_index := 0
## Maximum falling speed.[br]
## Instead of modifying this from another script, [method _get_terminal_velocity] should be overridden instead so the "default" value can be retained.
@export var terminal_velocity := 120.0
## If [code]true[/code], vertical velocity will be clamped to [member terminal_velocity] rather than smoothly lowering to it.[br]
## Improves responsiveness and player control, but also increases jerkiness.
@export var clamp_terminal_velocity := false
## Can be overridden to specify custom falling behavior (eg: fast-falling while holding down).
func _get_terminal_velocity() -> float:
  if is_wall_sliding():
    return terminal_velocity * wall_sliding_terminal_velocity_ratio
  return terminal_velocity

@export_group("Wall Sliding", "wall_sliding_")
## Multiplier to apply to [member terminal_velocity] while sliding on walls.[br]
## If [code]1.0[/code], the character will not slow down while sliding on walls.[br]
## If [code]0.5[/code], the character will have half the normal terminal velocity while sliding on walls.[br]
## If [code]0.0[/code], the character will not fall while sliding on a wall.
@export var wall_sliding_terminal_velocity_ratio := 1.0
## If [code]true[/code], vertical velocity will be clamped to [member terminal_velocity] rather than smoothly lowering to it.[br]
## Improves responsiveness and player control, but also increases jerkiness.
@export var wall_sliding_clamp_terminal_velocity := true

## Can be overridden to specify custom falling behavior (eg: fast-falling while holding down).
func _get_gravity() -> float:
  if pause_physics:
    return 0.0
  if not is_jumping() and is_rising():
    return _last_jump_data.get_min_height_gravity()
  return _last_jump_data.get_max_height_gravity()

func _ready() -> void:
  if Engine.is_editor_hint():
    return
  if is_instance_valid(current):
    push_warning("Created multiple ParametricPlatformerController2D simultaneously")
  else:
    current = self
  _update_collider_shapes()
  left_wall_sensor.collision_layer = collision_layer
  right_wall_sensor.collision_layer = collision_layer
  if (collision_layer & wall_jump_collision_mask) != 0:
    push_error("Player controller's collision_layer and collision_mask overlap in some way. This will prevent wall detection (and thus wall jumping) from working. Make sure the player character has their own collision layer which is unique to everything they can collide with.")
  left_wall_sensor.collision_mask = wall_jump_collision_mask
  right_wall_sensor.collision_mask = wall_jump_collision_mask
  if spawn_grounded:
    var raycast := RayCast2D.new()
    raycast.collision_mask = collision_mask
    raycast.target_position = Vector2(0, 10_000)
    add_child(raycast)
    raycast.force_raycast_update()
    if not raycast.is_colliding():
      push_warning("Cannot snap to ground below (%f, %f) as no ground was found below it." % [global_position.x, global_position.y])
    else:
      global_position = raycast.get_collision_point()
    raycast.queue_free()

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
    input_floor_coyote_time.push_state(is_on_floor())
    if not _was_grounded and is_grounded():
      aerial_jump_index = 0
      landed.emit()
      _last_jump_data = jump_data
    _was_grounded = is_grounded()
    if can_jump() and input_jump.was_pressed():
      _jumping = true
      input_jump.buffer.fill_state(true)
      if is_grounded(true):
        clear_coyote_time()
        _last_jump_data = jump_data
        _last_wall_jump_normal = Vector2.ZERO
        velocity.x = _get_jump_horizontal_velocity(true, false, false)
        grounded_jump.emit()
      elif is_instance_valid(wall_jump_data) and get_wall_side() != 0.0:
        _last_jump_data = wall_jump_data
        _last_wall_jump_normal = Vector2(-get_wall_side(), 0.0)
        velocity.x = _get_jump_horizontal_velocity(false, true, false)
        wall_jump.emit()
      else:
        aerial_jump_index += 1
        _last_jump_data = aerial_jump_data[aerial_jump_index]
        _last_wall_jump_normal = Vector2.ZERO
        velocity.x = _get_jump_horizontal_velocity(false, false, true)
        aerial_jump.emit()
      velocity.y = _last_jump_data.get_velocity()
      jumped.emit()
    if _last_wall_jump_normal.x != 0.0:
      var wall_jump_rising_ratio := 1.0 - velocity.y / wall_jump_data.get_velocity()
      if (
        wall_jump_rising_ratio > wall_jump_rising_ratio_to_apply_horizontal_velocity
      ):
        _last_wall_jump_normal = Vector2.ZERO
      else:
        var jump_velocity := _get_jump_horizontal_velocity(false, true, false)
        if jump_velocity < 0.0:
          velocity.x = minf(jump_velocity, velocity.x)
        else:
          velocity.x = maxf(jump_velocity, velocity.x)
  if _jumping and (
    pause_inputs
    or not input_jump.is_down()
  ):
    _jumping = false
  if not pause_physics:
    var was_falling := is_falling()
    _is_wall_sliding = (
      is_on_wall()
      and signf(get_wall_normal().x) != signf(velocity.x)
      and not is_zero_approx(velocity.x)
    )
    var current_terminal_velocity := _get_terminal_velocity()
    var was_at_terminal_velocity := is_at_terminal_velocity(current_terminal_velocity)
    if (
      was_at_terminal_velocity
      and (
        wall_sliding_clamp_terminal_velocity
        if is_wall_sliding() else
        clamp_terminal_velocity
      )
    ):
      velocity.y = current_terminal_velocity
    else:
      velocity.y = move_toward(velocity.y, current_terminal_velocity, delta * _get_gravity())
    var old_collisions := _active_slide_collisions.duplicate()
    if move_and_slide():
      for i: int in range(get_slide_collision_count()):
        var collision := get_slide_collision(i)
        var collider_id := collision.get_collider_id()
        old_collisions.remove_at(old_collisions.find(collider_id))
        if collider_id in _active_slide_collisions:
          continue
        _active_slide_collisions.push_back(collider_id)
        collided.emit(collision)
    for old_collision: int in old_collisions:
      _active_slide_collisions.remove_at(_active_slide_collisions.find(old_collision))

    if not was_falling and is_falling():
      started_falling.emit()
    if not was_at_terminal_velocity and is_at_terminal_velocity(current_terminal_velocity):
      reached_terminal_velocity.emit()

## Updates the current state for all input data.[br]
## Should only be called by [method _physics_process] if [member pause_inputs] is [code]false[/code]
func update_inputs() -> void:
  for input: ParametricPlatformerController2DInputData in [input_left, input_right, input_jump]:
    input.update_state()
  for input: ParametricPlatformerController2DInputData in input_actions.values():
    input.update_state()

## Resets all input buffers as though the user hasn't pressed any of their actions for their entire duration.[br]
## Useful for returning control to the player (eg: after a cutscene or screen transition)
func clear_input_buffers() -> void:
  for input: ParametricPlatformerController2DInputData in [input_left, input_right, input_jump]:
    input.buffer.fill_state(false)
  for input: ParametricPlatformerController2DInputData in input_actions.values():
    input.buffer.fill_state(false)

## Resets coyote time buffers as though the user hasn't touched the ground for its entire duration.[br]
## Useful for returning control to the player (eg: after a cutscene or screen transition)
func clear_coyote_time() -> void:
  input_floor_coyote_time.fill_state(false)

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

## Returns [code]true[/code] if the character is grounded according to [member input_floor_coyote_time].[br]
## Should be preferred over [method CharacterBody2D.is_on_floor].
func is_grounded(use_coyote_time := false) -> bool:
  return input_floor_coyote_time.any_high() if use_coyote_time else input_floor_coyote_time.is_high()

## Returns [code]true[/code] if the character is rising from a jump.[br]
## See also: [method is_jumping], [method is_rising], and [method is_falling]
func is_jumping_up() -> bool:
  return _jumping and is_rising()

## Returns [code]true[/code] if the character is mid-jump, rising or falling.[br]
## See also: [method is_jumping_up], [method is_rising], and [method is_falling]
func is_jumping() -> bool:
  return _jumping

## Returns [code]true[/code] if the character is rising.[br]
## See also: [method is_jumping_up], [method is_jumping], and [method is_falling]
func is_rising() -> bool:
  return velocity.y < 0.0

## Returns [code]true[/code] if the character is falling.[br]
## See also: [method is_jumping_up], [method is_jumping], [method is_at_terminal_velocity] and [method is_rising]
func is_falling() -> bool:
  return velocity.y > 0.0

## Returns [code]true[/code] if the character is falling at or above terminal velocity.[br]
## See also: [method is_falling]
func is_at_terminal_velocity(current_terminal_velocity := _get_terminal_velocity()) -> bool:
  return velocity.y >= current_terminal_velocity

## Returns the number of aerial jumps the character has left.
func remaining_aerial_jump_count() -> int:
  return aerial_jump_data.size() - aerial_jump_index

## Returns [code]true[/code] if the character in a state where jumping is permitted.
func can_jump() -> bool:
  return (
    not pause_inputs
    and not _jumping
    and (
      is_grounded(true)
      or aerial_jump_index < aerial_jump_data.size()
      or (is_instance_valid(wall_jump_data) and get_wall_side() != 0.0)
    )
  )

## Returns [code]-1[/code] if there is a wall only on the character's left.[br]
## Returns [code]1[/code] if there is a wall only on the character's right.[br]
## Returns [code]0[/code] if there is a wall on neither or both sides.
func get_wall_side() -> float:
  var left_detection := -1.0 if left_wall_sensor.get_overlapping_bodies().size() > 0 else 0.0
  var right_detection := 1.0 if right_wall_sensor.get_overlapping_bodies().size() > 0 else 0.0
  return left_detection + right_detection

## Internal use only; see [method is_wall_sliding].
var _is_wall_sliding := false
## Returns [code]true[/code] if the character is sliding on a wall.
func is_wall_sliding() -> bool:
  return _is_wall_sliding
