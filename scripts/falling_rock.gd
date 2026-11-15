class_name FallingRock
extends StaticBody2D
## Boulder knocked loose by the worm. While it rests it is real terrain and
## blocks waves; it crumbles after a few seconds.

var radius := 26.0
var vel := Vector2.ZERO
var landed := false
var life := 9.0
var shape: CollisionShape2D
var poly := PackedVector2Array()
var floor_y := 812.0


func _ready() -> void:
	collision_layer = WaveTracer.L_TERRAIN
	collision_mask = 0
	add_to_group("rock")
	shape = CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	add_child(shape)
	for i in 9:
		var a := i * TAU / 9.0
		poly.append(Vector2.from_angle(a) * radius * randf_range(0.85, 1.15))
	z_index = 7


func _physics_process(delta: float) -> void:
	if not landed:
		vel.y += 1400.0 * delta
		position += vel * delta
		rotation += delta * 3.0
		if position.y >= floor_y - radius:
			position.y = floor_y - radius
			landed = true
			Sfx.play("crumble", -8.0, randf_range(0.9, 1.2))
	else:
		life -= delta
		if life < 1.0:
			modulate.a = maxf(life, 0.0)
		if life <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(poly, Color(0.30, 0.29, 0.38))
	var inner := PackedVector2Array()
	for v in poly:
		inner.append(v * 0.72 + Vector2(-3, -3))
	draw_colored_polygon(inner, Color(0.45, 0.45, 0.56))
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Color(0.1, 0.09, 0.14), 3.0)
	if not landed:
		draw_line(Vector2(0, -radius - 4), Vector2(0, -radius - 40), Color(0.8, 0.8, 0.9, 0.3), 6.0)
