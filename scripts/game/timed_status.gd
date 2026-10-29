class_name TimedStatus
extends RefCounted

## One named timed status on one enemy, with a separate timer per owner (a turret's source id; 0 for ownerless).
## The status is active while ANY owner's timer is above zero, and its remaining time is the longest of them, so one
## owner clearing its own timer never removes what another owner applied. Stacking in magnitude is not decided here:
## callers read `is_active()` once, so several owners never add up.

## owner id -> seconds left. Entries at or below zero are removed.
var _timers: Dictionary = {}

## Refreshes this owner's timer to the longer of what it has and `duration`.
func refresh(duration: float, owner: int = 0) -> void:
	if duration <= 0.0:
		return
	_timers[owner] = maxf(remaining_for(owner), duration)

## Adds `duration` to this owner's time left, up to `cap`; never shortens a timer that is already above the cap.
func extend(duration: float, cap: float, owner: int = 0) -> void:
	var current := remaining_for(owner)
	var next := maxf(current, minf(current + duration, cap))
	if next > 0.0:
		_timers[owner] = next

func remaining_for(owner: int = 0) -> float:
	return float(_timers.get(owner, 0.0))

## The longest timer across all owners.
func remaining() -> float:
	var longest := 0.0
	for value: float in _timers.values():
		longest = maxf(longest, value)
	return longest

func is_active() -> bool:
	return remaining() > 0.0

## Removes only this owner's timer.
func clear_owner(owner: int = 0) -> void:
	_timers.erase(owner)

func clear() -> void:
	_timers.clear()

func advance(delta: float) -> void:
	for owner: int in _timers.keys():
		var left := maxf(0.0, float(_timers[owner]) - delta)
		if left > 0.0:
			_timers[owner] = left
		else:
			_timers.erase(owner)
