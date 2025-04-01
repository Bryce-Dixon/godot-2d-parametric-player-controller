class_name ParametricPlayerController2DMovementData extends Resource

## Units per second
@export_range(0.0, 10_000.0, 0.01, "hide_slider", "or_greater") var velocity := 20.0
## Seconds it takes to reach [member velocity] from rest[br]
## Lower values lead to snappier movement, higher values lead to more sluggish movement
@export_range(0.0, 100.0, 0.01, "hide_slider", "or_greater") var acceleration_time := 0.25
## Units per second per second[br]
## Derived from [member velocity] and [member acceleration_time]
var acceleration: float:
  get:
    return velocity / acceleration_time
  set(_value):
    push_warning("ParametricPlayerController2DMovementData.acceleration cannot be set directly")

## Seconds it takes to arrive at rest from [member velocity] when no inputs are provided[br]
## Lower values lead to snappier movement, higher values lead to more sluggish movement
@export_range(0.0, 100.0, 0.01, "hide_slider", "or_greater") var deceleration_time := 0.125
## Units per second per second[br]
## Derived from [member velocity] and [member deceleration_time]
var deceleration: float:
  get:
    return velocity / deceleration_time
  set(_value):
    push_warning("ParametricPlayerController2DMovementData.deceleration cannot be set directly")
