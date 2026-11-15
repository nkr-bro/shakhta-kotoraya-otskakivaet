class_name WaveTarget
extends Area2D
## Something the wave must touch: a jammed latch, a crack, a power socket.
## It only reacts when a real trajectory intersects its shape.

signal hit

@export var radius := 20.0
@export var rect_size := Vector2.ZERO
@export var active := true
@export var marker_color := Color(1.0, 0.85, 0.35)
@export var show_marker := true

var _t := 0.0
var shape_node: CollisionShape2D


func _ready() -> void:
	collision_layer = WaveTracer.L_TARGET
	collision_mask = 0
	monitoring = false
	monitorable = true
	shape_node = CollisionShape2D.new()
	if rect_size != Vector2.ZERO:
		var r := RectangleShape2D.new()
		r.size = rect_size
		shape_node.shape = r
	else:
		var c := CircleShape2D.new()
		c.radius = radius
		shape_node.shape = c
	add_child(shape_node)
	set_active(active)


func set_active(on: bool) -> void:
	active = on
	if on:
		add_to_group("wave_target")
	elif is_in_group("wave_target"):
		remove_from_group("wave_target")
	shape_node.set_deferred("disabled", not on)
	collision_layer = WaveTracer.L_TARGET if on else 0
	visible = on or not show_marker
	queue_redraw()


func on_wave_hit(_wave: Node) -> void:
	if not active:
		return
	Sfx.play("hit", -2.0)
	hit.emit()


func _process(delta: float) -> void:
	_t += delta
	if active and show_marker:
		queue_redraw()


func _draw() -> void:
	if not (active and show_marker):
		return
	var k := 0.5 + 0.5 * sin(_t * 4.0)
	var r := radius if rect_size == Vector2.ZERO else rect_size.length() * 0.5
	draw_arc(Vector2.ZERO, r + 6.0 + k * 5.0, 0, TAU, 32, Color(marker_color, 0.35 + 0.4 * k), 2.0)
	draw_arc(Vector2.ZERO, r * 0.45, 0, TAU, 24, Color(marker_color, 0.7), 2.0)
