class_name EnergyWave
extends Node2D
## Fast projectile. Every physics frame the whole travelled segment is ray-cast,
## so thin crystals cannot be skipped, and several reflections per frame are
## resolved with the remaining distance.

signal finished(success: bool, collider: Object)
signal bounced(point: Vector2)

@export var speed := 1100.0
@export var max_bounces := 8
@export var lifetime := 4.0
@export var hostile := false
@export var color := Color(0.45, 1.0, 0.95)

var pos := Vector2.ZERO
var dir := Vector2.RIGHT
var age := 0.0
var alive := true
var bounces_left := 8
var bounce_count := 0
var boosted := false
var trail: Array = []   # [{p, t}]
var flashes: Array = [] # [{p, t, c}]


func launch(origin: Vector2, direction: Vector2) -> void:
	top_level = true
	global_position = Vector2.ZERO
	pos = origin
	dir = direction.normalized()
	bounces_left = max_bounces
	trail = [{"p": pos, "t": 0.0}]


func _physics_process(delta: float) -> void:
	if not alive:
		age += delta
		_expire_effects()
		if trail.is_empty() and flashes.is_empty():
			queue_free()
		queue_redraw()
		return
	age += delta
	var mask := WaveTracer.HOSTILE_MASK if hostile else WaveTracer.PLAYER_MASK
	var space := get_world_2d().direct_space_state
	var r := WaveTracer.step(space, pos, dir, speed * delta, mask, bounces_left)
	for e in r.events:
		trail.append({"p": e.point, "t": age})
		if e.kind == "gem":
			if not hostile and e.collider.is_in_group("ring"):
				if not boosted:
					boosted = true
					speed *= 1.6
					color = Color(1.0, 0.85, 0.35)
					flashes.append({"p": e.point, "t": age, "c": Color(1, 0.85, 0.3), "r": 40.0})
					Sfx.play("ricochet", -2.0, 1.6)
			elif not hostile and e.collider.has_method("collect") and e.collider.is_in_group("gem"):
				e.collider.collect()
			continue
		if e.kind == "reflector" and not (r.stop and e == r.events[-1]):
			bounces_left -= 1
			bounce_count += 1
			flashes.append({"p": e.point, "t": age, "c": Color(1, 1, 1), "r": 26.0})
			bounced.emit(e.point)
			_sparks(e.point, e.normal)
			Sfx.play("ricochet", -4.0, randf_range(0.95, 1.1))
	pos = r.pos
	dir = r.dir
	trail.append({"p": pos, "t": age})
	if r.stop:
		var last: Dictionary = r.events[-1]
		_finish_hit(last)
	elif not WaveTracer.BOUNDS.has_point(pos) or age > lifetime:
		_end(false, null)
	_expire_effects()
	queue_redraw()


func _finish_hit(e: Dictionary) -> void:
	var c: Object = e.collider
	match e.kind:
		"target":
			flashes.append({"p": e.point, "t": age, "c": Color(1.0, 0.95, 0.6), "r": 60.0})
			if c.has_method("on_wave_hit"):
				c.on_wave_hit(self)
			_end(true, c)
		"shield":
			flashes.append({"p": e.point, "t": age, "c": Color(1.0, 0.3, 0.5), "r": 50.0})
			if c is Node and (c as Node).has_meta("owner_elevator"):
				(c as Node).get_meta("owner_elevator").take_hit()
			_end(true, c)
		_:
			flashes.append({"p": e.point, "t": age, "c": Color(0.6, 0.7, 0.8), "r": 16.0})
			if c != null and c.has_method("on_wave_blocked"):
				c.on_wave_blocked(self, e.point)
			Sfx.play("miss", -10.0)
			_end(false, c)


func _sparks(at: Vector2, normal: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 70.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color.lightened(0.4)
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


func _end(success: bool, collider: Object) -> void:
	alive = false
	finished.emit(success, collider)


func _expire_effects() -> void:
	var keep := 0.16 if not hostile else 0.28
	while trail.size() > 0 and age - float(trail[0].t) > keep:
		trail.pop_front()
	flashes = flashes.filter(func(f): return age - float(f.t) < 0.35)


func _draw() -> void:
	if trail.size() >= 2:
		for i in range(1, trail.size()):
			var a: Dictionary = trail[i - 1]
			var b: Dictionary = trail[i]
			var k := clampf(1.0 - (age - float(b.t)) / (0.28 if hostile else 0.16), 0.0, 1.0)
			draw_line(a.p, b.p, Color(color, 0.25 * k), 14.0 * k + 2.0)
			draw_line(a.p, b.p, Color(color, 0.9 * k), 4.0 * k + 1.0)
	if alive:
		draw_circle(pos, 13.0, Color(color, 0.25))
		draw_circle(pos, 7.0, Color(color, 0.85))
		draw_circle(pos, 3.5, Color(1, 1, 1))
	for f in flashes:
		var k := 1.0 - (age - float(f.t)) / 0.35
		var c: Color = f.c
		draw_circle(f.p, float(f.r) * (1.3 - k * 0.6), Color(c, 0.35 * k))
		for j in 6:
			var ang := j * TAU / 6.0 + float(f.t) * 7.0
			draw_line(f.p, f.p + Vector2.from_angle(ang) * float(f.r) * (1.2 - k * 0.5), Color(c, 0.8 * k), 2.0)
