class_name Gem
extends Area2D
## Optional collectible. The wave flies through it (it never stops a shot),
## so clever multi-bounce trajectories are rewarded.

signal collected(gem: Gem)

@export var gem_color := Color(0.55, 1.0, 0.9)
var taken := false
var _t := randf() * 5.0


func _ready() -> void:
	collision_layer = WaveTracer.L_TARGET
	collision_mask = 0
	monitoring = false
	add_to_group("gem")
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 15.0
	cs.shape = c
	add_child(cs)
	z_index = 9


func collect() -> void:
	if taken:
		return
	taken = true
	collision_layer = 0
	remove_from_group("gem")
	Sfx.play("hit", -4.0, 1.6)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 24
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = gem_color
	add_child(p)
	p.emitting = true
	collected.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.25)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if taken:
		return
	var bob := sin(_t * 2.5) * 4.0
	var k := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(Vector2(0, bob), 22.0, Color(gem_color, 0.12 + 0.1 * k))
	var pts := PackedVector2Array([Vector2(0, -14 + bob), Vector2(10, bob), Vector2(0, 14 + bob), Vector2(-10, bob)])
	draw_colored_polygon(pts, gem_color)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -14 + bob), Vector2(10, bob), Vector2(0, bob)]), gem_color.lightened(0.5))
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, Color(0.05, 0.1, 0.12), 2.0)
	var sp := Vector2(-4, -6 + bob)
	draw_line(sp + Vector2(-4, 0), sp + Vector2(4, 0), Color(1, 1, 1, k), 1.5)
	draw_line(sp + Vector2(0, -4), sp + Vector2(0, 4), Color(1, 1, 1, k), 1.5)
