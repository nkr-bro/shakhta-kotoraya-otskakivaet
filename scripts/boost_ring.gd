class_name BoostRing
extends Area2D
## Pass-through ring: the wave speeds up and the shot scores double.

var used := false
var _t := randf() * 4.0


func _ready() -> void:
	collision_layer = WaveTracer.L_TARGET
	collision_mask = 0
	monitoring = false
	add_to_group("gem")
	add_to_group("ring")
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 26.0
	cs.shape = c
	add_child(cs)
	z_index = 9


func collect() -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var k := 0.5 + 0.5 * sin(_t * 4.0)
	var col := Color(1.0, 0.8, 0.3)
	draw_arc(Vector2.ZERO, 26.0, 0, TAU, 32, Color(col, 0.35 + 0.3 * k), 6.0)
	draw_arc(Vector2.ZERO, 26.0, _t * 3.0, _t * 3.0 + 2.0, 12, col, 3.0)
	draw_arc(Vector2.ZERO, 26.0, _t * 3.0 + PI, _t * 3.0 + PI + 2.0, 12, col, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-12, 7), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.95, 0.7, 0.9))
