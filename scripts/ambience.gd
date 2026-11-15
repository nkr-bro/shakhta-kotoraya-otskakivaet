class_name Ambience
extends Node2D
## Living background: floating dust, flickering lantern glow and drifting
## crystal motes. Purely decorative, never collides.

var lanterns: Array = []
var crystal_glows: Array = []
var _t := 0.0
var _seed := randf() * 10.0


func _ready() -> void:
	z_index = 20
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	var dust := CPUParticles2D.new()
	dust.amount = 70
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(900, 500)
	dust.position = Vector2(836, 470)
	dust.direction = Vector2(1, -0.3)
	dust.spread = 60.0
	dust.gravity = Vector2(0, -4)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 16.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.7, 0.0))
	g.add_point(0.5, Color(1.0, 0.9, 0.7, 0.35))
	g.set_color(1, Color(1.0, 0.9, 0.7, 0.0))
	dust.color_ramp = g
	dust.use_parent_material = true
	add_child(dust)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for i in lanterns.size():
		var p: Vector2 = lanterns[i]
		var f := 0.75 + 0.15 * sin(_t * 7.0 + i * 1.7) + 0.1 * sin(_t * 17.0 + i * 3.1 + _seed)
		draw_circle(p, 46.0 * f, Color(1.0, 0.6, 0.25, 0.07 * f))
		draw_circle(p, 22.0 * f, Color(1.0, 0.75, 0.4, 0.12 * f))
	for i in crystal_glows.size():
		var c: Vector2 = crystal_glows[i]
		var k := 0.5 + 0.5 * sin(_t * 1.6 + i * 2.3)
		draw_circle(c, 34.0, Color(1.0, 0.3, 0.8, 0.05 + 0.06 * k))
		var sp := c + Vector2(sin(_t * 0.7 + i) * 20.0, -fmod(_t * 14.0 + i * 13.0, 50.0))
		draw_circle(sp, 1.8, Color(1.0, 0.7, 1.0, 0.6 * (1.0 - fmod(_t * 14.0 + i * 13.0, 50.0) / 50.0)))
