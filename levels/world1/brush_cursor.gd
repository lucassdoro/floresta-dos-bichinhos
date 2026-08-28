class_name BrushCursor
extends Node2D

## Pincel: convida com bounce num ponto-ancora ate a crianca comecar, e entao
## segue o dedo com um leve balanco. A origem fica na ponta das cerdas.

enum State { HIDDEN, INVITE, FOLLOWING }

const INVITE_BOUNCE := 18.0
const INVITE_SPEED := 3.2
const TILT := -28.0
const WOBBLE_ANGLE := 6.0
const WOBBLE_SPEED := 14.0

var _state := State.HIDDEN
var _time := 0.0
var _invite_anchor := Vector2.ZERO
var _follow_target := Vector2.ZERO

@onready var _tip: Sprite2D = $Tip

func _ready() -> void:
	visible = false

func show_invite(color: Color, anchor: Vector2) -> void:
	_tip.modulate = color
	_invite_anchor = anchor
	_state = State.INVITE
	visible = true

func follow(global_point: Vector2) -> void:
	_follow_target = global_point
	_state = State.FOLLOWING

## So volta pro convite se estava seguindo: hide() e' terminal ate o proximo
## show_invite.
func release() -> void:
	if _state == State.FOLLOWING:
		_state = State.INVITE

func hide_brush() -> void:
	_state = State.HIDDEN
	visible = false

func _process(delta: float) -> void:
	_time += delta
	match _state:
		State.INVITE:
			position = _invite_anchor + Vector2(0, -sin(_time * INVITE_SPEED) * INVITE_BOUNCE)
			rotation_degrees = TILT
		State.FOLLOWING:
			position = _follow_target
			rotation_degrees = TILT + sin(_time * WOBBLE_SPEED) * WOBBLE_ANGLE
		State.HIDDEN:
			pass
