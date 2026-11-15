class_name Miner
extends Node2D
## The stationary hero. The node origin is the back boot; every frame of the
## sheet is aligned to it, so turning, breathing and swinging never move the feet.

signal struck

const FRAME_ANCHOR := Vector2(75.5, 170.0)
const PICK_TIP := Vector2(130.0, -110.0)  # top of the energy arc in the strike frame, sheet units

@export var sheet: Texture2D = preload("res://assets/sprites/miner_sheet.png")
@export var body_scale := 0.6
@export var facing := 1

var spr: Sprite2D
var busy := false
var _t := 0.0
var _cheer := 0.0


func _ready() -> void:
	spr = Sprite2D.new()
	spr.texture = sheet
	spr.hframes = 4
	spr.vframes = 2
	spr.centered = false
	spr.offset = -FRAME_ANCHOR
	spr.frame = 7
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
	scale = Vector2.ONE * body_scale
	_apply_facing()


func face_towards(p: Vector2) -> void:
	var f := 1 if p.x >= global_position.x else -1
	if f != facing:
		facing = f
		_apply_facing()


func _apply_facing() -> void:
	spr.scale.x = float(facing)


func strike_origin() -> Vector2:
	return global_position + Vector2(PICK_TIP.x * facing, PICK_TIP.y) * body_scale


func _process(delta: float) -> void:
	_t += delta
	var breathe := 1.0 + sin(_t * 2.4) * 0.014
	if _cheer > 0.0:
		_cheer -= delta
		breathe = 1.0 + absf(sin(_cheer * 9.0)) * 0.05
	spr.scale.y = breathe


func swing() -> void:
	if busy:
		return
	busy = true
	Sfx.play("swing", -2.0)
	spr.frame = 4
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.11, false).timeout
	spr.frame = 5
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.15, false).timeout
	spr.frame = 6
	Sfx.play("strike", -3.0)
	struck.emit()
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.28, false).timeout
	spr.frame = 7
	busy = false


func cheer() -> void:
	spr.frame = 5
	_cheer = 1.0
	if not is_inside_tree():
		return
	await get_tree().create_timer(1.0, false).timeout
	if not busy:
		spr.frame = 7


## Thrown by a quake: tumbles in an arc to a new standing point.
## Jumps to another standing point between exercises.
func hop_to(target: Vector2) -> void:
	await knocked_to(target, false)


func knocked_to(target: Vector2, tumble := true) -> void:
	busy = true
	spr.frame = 4
	if target.x < position.x:
		facing = -1
		_apply_facing()
	elif target.x > position.x:
		facing = 1
		_apply_facing()
	var start := position
	var peak := minf(start.y, target.y) - 90.0
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var x := lerpf(start.x, target.x, k)
		var y := lerpf(start.y, target.y, k) - sin(k * PI) * (minf(start.y, target.y) - peak)
		position = Vector2(x, y)
		spr.rotation = (sin(k * PI) * -0.6 * facing) if tumble else 0.0, 0.0, 1.0, 0.7)
	await tw.finished
	spr.rotation = 0.0
	spr.frame = 7
	Sfx.play("crumble", -6.0, 1.3)
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.amount = 18
	dust.lifetime = 0.8
	dust.explosiveness = 1.0
	dust.direction = Vector2(0, -1)
	dust.spread = 70.0
	dust.initial_velocity_min = 60.0
	dust.initial_velocity_max = 160.0
	dust.gravity = Vector2(0, 200)
	dust.scale_amount_min = 4.0
	dust.scale_amount_max = 9.0
	dust.color = Color(0.7, 0.65, 0.6, 0.6)
	dust.top_level = true
	add_child(dust)
	dust.global_position = global_position
	dust.emitting = true
	get_tree().create_timer(1.2).timeout.connect(dust.queue_free)
	busy = false
