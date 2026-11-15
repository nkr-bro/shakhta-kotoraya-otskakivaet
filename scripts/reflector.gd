class_name Reflector
extends Node2D
## Rotatable crystal mirror. The stand stays still; only the crystal body
## (a StaticBody2D on the "reflectors" layer) rotates. Its rectangle is the
## real mirror surface used by all ray casts.

signal rotated(angle_deg: float)

const CRYSTAL := preload("res://assets/sprites/crystal.png")
const STAND := preload("res://assets/sprites/stand.png")

@export var length := 120.0
@export var thickness := 16.0
@export var sprite_scale := 0.5
@export var min_angle := -85.0
@export var max_angle := 85.0
@export var start_angle := 30.0
@export var stand_offset := Vector2(0, 22)
@export var stand_scale := 1.0
@export var show_stand := true
## Optional back-and-forth motion (e.g. riding a mine cart).
@export var track := Vector2.ZERO
@export var track_period := 4.0
@export var draw_cart := false

var body: StaticBody2D
var crystal: Sprite2D
var selected := false
var locked := false
var hovered := false
var angle_deg := 0.0
var _t := 0.0
var base_pos := Vector2.ZERO
var moving := true


func _ready() -> void:
	base_pos = position
	if show_stand:
		var st := Sprite2D.new()
		st.texture = STAND
		st.position = stand_offset
		st.scale = Vector2.ONE * stand_scale
		add_child(st)
	body = StaticBody2D.new()
	body.collision_layer = WaveTracer.L_REFLECTOR
	body.collision_mask = 0
	body.add_to_group("reflector")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, thickness)
	cs.shape = rect
	body.add_child(cs)
	crystal = Sprite2D.new()
	crystal.texture = CRYSTAL
	crystal.scale = Vector2.ONE * sprite_scale
	body.add_child(crystal)
	add_child(body)
	set_angle(start_angle, false)


func set_enabled(on: bool) -> void:
	visible = on
	body.collision_layer = WaveTracer.L_REFLECTOR if on else 0


func reset() -> void:
	set_angle(start_angle, false)


func set_angle(deg: float, emit := true) -> void:
	var a := clampf(deg, min_angle, max_angle)
	if is_equal_approx(a, angle_deg) and body.rotation_degrees == a:
		return
	angle_deg = a
	body.rotation_degrees = a
	queue_redraw()
	if emit:
		rotated.emit(a)


func handle_global() -> Vector2:
	return global_position + Vector2.from_angle(deg_to_rad(angle_deg)) * (length * 0.5 + 30.0)


func hit_test(p: Vector2) -> bool:
	var local := (p - global_position).rotated(-deg_to_rad(angle_deg))
	return absf(local.x) <= length * 0.5 + 10.0 and absf(local.y) <= thickness * 0.5 + 22.0


func handle_hit_test(p: Vector2) -> bool:
	return selected and p.distance_to(handle_global()) < 24.0


func _physics_process(_delta: float) -> void:
	if track != Vector2.ZERO and moving:
		position = base_pos + track * sin(Time.get_ticks_msec() / 1000.0 * TAU / track_period)


func _process(delta: float) -> void:
	_t += delta
	if draw_cart:
		queue_redraw()
	var glow := 1.0 + 0.12 * sin(_t * 3.0)
	crystal.modulate = Color(glow, glow, glow) if not locked else Color(0.85, 0.85, 0.9)
	if selected or hovered:
		queue_redraw()


func _draw() -> void:
	if draw_cart:
		_draw_cart()
	if not (selected or hovered):
		return
	var r := length * 0.5 + 14.0
	var c := Color(1.0, 0.92, 0.55, 0.9 if selected else 0.45)
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, 2.0)
	if not selected:
		return
	var dirv := Vector2.from_angle(deg_to_rad(angle_deg))
	var h := dirv * (length * 0.5 + 30.0)
	draw_line(dirv * (length * 0.5 + 4.0), h, c, 2.0)
	draw_circle(h, 11.0, Color(0.1, 0.08, 0.05, 0.85))
	draw_arc(h, 11.0, 0, TAU, 24, c, 2.5)
	draw_circle(h, 4.0, c)
	# allowed range
	draw_arc(Vector2.ZERO, r + 8.0, deg_to_rad(min_angle), deg_to_rad(max_angle), 32, Color(1, 1, 1, 0.18), 3.0)
	var font := ThemeDB.fallback_font
	var txt := "%d°" % roundi(-angle_deg)
	var tp := Vector2(-20, -r - 14)
	draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 20, 5, Color(0, 0, 0, 0.9))
	draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color(1, 0.95, 0.7))


func _draw_cart() -> void:
	var y := stand_offset.y + 8.0
	var rail_l := -track.x - position.x + base_pos.x - 60.0
	var rail_r := track.x - position.x + base_pos.x + 60.0
	draw_line(Vector2(rail_l, y + 22), Vector2(rail_r, y + 22), Color(0.45, 0.45, 0.5), 3.0)
	draw_rect(Rect2(-46, y - 6, 92, 24), Color(0.14, 0.08, 0.05))
	draw_rect(Rect2(-43, y - 3, 86, 18), Color(0.55, 0.33, 0.17))
	draw_rect(Rect2(-43, y - 3, 86, 4), Color(0.75, 0.5, 0.26))
	for x in [-28.0, 28.0]:
		var a := (position.x - base_pos.x) / 9.0
		draw_circle(Vector2(x, y + 20), 8.0, Color(0.12, 0.12, 0.14))
		draw_circle(Vector2(x, y + 20), 5.0, Color(0.5, 0.5, 0.56))
		draw_line(Vector2(x, y + 20), Vector2(x, y + 20) + Vector2.from_angle(a) * 5.0, Color(0.2, 0.2, 0.22), 2.0)
