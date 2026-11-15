class_name Elevator
extends Node2D
## Lift cage with an energy shield (3 HP) that boss blasts can damage.
## Player waves pass the wooden cage; only blasts collide with the shield.

signal damaged(hp: int)
signal destroyed

@export var cage_texture: Texture2D = preload("res://assets/sprites/l3_cage.png")
@export var shield_rect := Rect2(0, 0, 218, 204)
var hp := 3
var shield_on := false
var cage: Sprite2D
var shield: StaticBody2D
var _hit_t := 0.0
var _t := 0.0


func _ready() -> void:
	cage = Sprite2D.new()
	cage.texture = cage_texture
	cage.centered = false
	add_child(cage)
	shield = StaticBody2D.new()
	shield.collision_layer = 0
	shield.collision_mask = 0
	shield.add_to_group("shield")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = shield_rect.size + Vector2(30, 30)
	cs.shape = r
	cs.position = shield_rect.get_center()
	shield.add_child(cs)
	add_child(shield)
	shield.set_meta("owner_elevator", self)


func set_shield(on: bool) -> void:
	shield_on = on
	shield.collision_layer = WaveTracer.L_SHIELD if on else 0
	queue_redraw()


func take_hit() -> void:
	if hp <= 0:
		return
	hp -= 1
	_hit_t = 0.6
	Sfx.play("damage")
	damaged.emit(hp)
	if hp <= 0:
		set_shield(false)
		destroyed.emit()


func _process(delta: float) -> void:
	_t += delta
	_hit_t = maxf(0.0, _hit_t - delta)
	if shield_on or _hit_t > 0.0:
		queue_redraw()


func _draw() -> void:
	if not shield_on:
		return
	var c := shield_rect.get_center()
	var rad := shield_rect.size.length() * 0.5 + 8.0
	var k := 0.5 + 0.5 * sin(_t * 2.0)
	var col := Color(0.4, 0.95, 1.0) if _hit_t <= 0.0 else Color(1.0, 0.35, 0.45)
	draw_circle(c, rad, Color(col, 0.07 + 0.03 * k + _hit_t * 0.3))
	for i in hp:
		draw_arc(c, rad - i * 7.0, 0, TAU, 64, Color(col, 0.55), 2.0)
