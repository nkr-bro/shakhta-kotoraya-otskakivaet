class_name BreakableWall
extends StaticBody2D
## Stone plug with one weak crack. The body blocks waves (terrain layer);
## only the WeakPoint target can break it.

signal broken

@export var wall_size := Vector2(128, 372)
var sprite: Sprite2D
var shape: CollisionShape2D
var cracks: Array = []
var _crack_t := -1.0
var chunks: Array = []


func _ready() -> void:
	collision_layer = WaveTracer.L_TERRAIN
	collision_mask = 0
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/l2_wall.png")
	sprite.centered = false
	add_child(sprite)
	shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = wall_size
	shape.shape = r
	shape.position = wall_size * 0.5
	add_child(shape)


func break_apart(from: Vector2) -> void:
	# Cracks spread from the impact, then the stones fall.
	var local := from - global_position
	for i in 7:
		var pts := [local]
		var p := local
		var ang := randf_range(-1.2, 1.2) + (0.0 if i % 2 == 0 else PI * 0.0)
		for k in 6:
			p += Vector2.from_angle(ang + randf_range(-0.6, 0.6)) * randf_range(14, 30) * Vector2(1, 1.6)
			p.x = clampf(p.x, 4, wall_size.x - 4)
			p.y = clampf(p.y, 32, wall_size.y - 4)
			pts.append(p)
		cracks.append(pts)
	_crack_t = 0.0
	Sfx.play("crumble")
	var tw := create_tween()
	for i in 6:
		tw.tween_property(sprite, "position", Vector2(randf_range(-4, 4), randf_range(-2, 2)), 0.05)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.05)
	await tw.finished
	await get_tree().create_timer(0.35).timeout
	shape.set_deferred("disabled", true)
	collision_layer = 0
	var tex := sprite.texture
	for y in range(30, int(wall_size.y), 38):
		for x in range(0, int(wall_size.x), 42):
			var s := Sprite2D.new()
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(x, y, 42, 38)
			s.texture = at
			s.position = Vector2(x + 21, y + 19)
			add_child(s)
			chunks.append({"n": s, "v": Vector2(randf_range(-160, 60), randf_range(-160, 0)), "w": randf_range(-6, 6)})
	sprite.visible = false
	cracks.clear()
	queue_redraw()
	await get_tree().create_timer(1.6).timeout
	for c in chunks:
		c.n.queue_free()
	chunks.clear()
	broken.emit()


func _process(delta: float) -> void:
	for c in chunks:
		c.v.y += 900.0 * delta
		c.n.position += c.v * delta
		c.n.rotation += c.w * delta
		c.n.modulate.a = maxf(0.0, c.n.modulate.a - delta * 0.6)
	if _crack_t >= 0.0:
		_crack_t += delta
		queue_redraw()


func _draw() -> void:
	var k := clampf(_crack_t / 0.4, 0.0, 1.0)
	for pts in cracks:
		var n := int(ceil((pts.size() - 1) * k))
		for i in range(1, n + 1):
			draw_line(pts[i - 1], pts[i], Color(0.5, 1.0, 0.95, 0.9), 3.0)
			draw_line(pts[i - 1], pts[i], Color(0.05, 0.05, 0.1), 1.0)
