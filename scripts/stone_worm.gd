class_name StoneWorm
extends Node2D
## Boss. Built from the reference worm: body + head on a neck pivot, armour
## colliders that stop waves, weak points that move with their body part.
## All coordinates below are in the source image space (scaled by the node).

signal weak_point_hit(index: int)

const NECK := Vector2(700, 300)
const HEAD_POLY := [Vector2(170, 330), Vector2(250, 240), Vector2(400, 170), Vector2(560, 100), Vector2(690, 140), Vector2(722, 300), Vector2(660, 440), Vector2(560, 540), Vector2(420, 545), Vector2(300, 500), Vector2(200, 440)]
const BODY_POLY := [Vector2(700, 140), Vector2(820, 50), Vector2(1000, 60), Vector2(1160, 120), Vector2(1290, 230), Vector2(1360, 380), Vector2(1370, 560), Vector2(1320, 690), Vector2(1250, 800), Vector2(1210, 976), Vector2(1020, 976), Vector2(1060, 800), Vector2(1090, 660), Vector2(1050, 560), Vector2(980, 490), Vector2(880, 440), Vector2(760, 420), Vector2(700, 400)]
const ATTACK_ORIGIN := Vector2(1385, 330)
const ATTACK_ORIGIN_2 := Vector2(1362, 470)

var head: Node2D
var body_sprite: Sprite2D
var head_sprite: Sprite2D
var weak_points: Array[WaveTarget] = []
var attack_marker: Marker2D
var base_pos := Vector2.ZERO
var pose_offset := Vector2.ZERO
var pose_head_rot := 0.0
var charge := 0.0      # 0..1 glow at the attack origin
var _t := 0.0
var _hurt := 0.0
var alive := true
var breathing := true
var _fx: Node2D
var anim_rot := 0.0
var anim_lift := 0.0
var exposed := false
var sway := 1.0
var crack_level := 0


func _ready() -> void:
	base_pos = position
	body_sprite = Sprite2D.new()
	body_sprite.texture = preload("res://assets/sprites/worm_body.png")
	body_sprite.centered = false
	body_sprite.position = Vector2(0, 16)
	add_child(body_sprite)
	var body_armor := _armor(BODY_POLY)
	add_child(body_armor)
	head = Node2D.new()
	head.position = NECK
	add_child(head)
	head_sprite = Sprite2D.new()
	head_sprite.texture = preload("res://assets/sprites/worm_head.png")
	head_sprite.centered = false
	head_sprite.position = Vector2(157, 90) - NECK
	head.add_child(head_sprite)
	var hp := []
	for v in HEAD_POLY:
		hp.append(v - NECK)
	head.add_child(_armor(hp))
	# Weak points: crack under the body arc, then the throat under the jaw.
	weak_points.append(_weak(self, Vector2(935, 470), 30.0))
	weak_points.append(_weak(head, Vector2(-30, 160), 30.0))
	weak_points.append(_weak(head, Vector2(10, 120), 30.0))
	for w in weak_points:
		w.set_active(false)
	attack_marker = Marker2D.new()
	attack_marker.position = ATTACK_ORIGIN
	add_child(attack_marker)
	var fx := Node2D.new()
	fx.draw.connect(func(): _draw_charge(fx))
	fx.set_meta("fx", true)
	add_child(fx)
	_fx = fx


func _armor(poly: Array) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = WaveTracer.L_WORM
	b.collision_mask = 0
	var cp := CollisionPolygon2D.new()
	cp.polygon = PackedVector2Array(poly)
	b.add_child(cp)
	return b


func _weak(parent: Node, p: Vector2, r: float) -> WaveTarget:
	var w := WaveTarget.new()
	w.radius = r
	w.marker_color = Color(0.45, 1.0, 0.95)
	w.position = p
	parent.add_child(w)
	return w


func activate_weak_point(i: int) -> void:
	for k in weak_points.size():
		weak_points[k].set_active(k == i)


func attack_origin(i := 0) -> Vector2:
	if i == 1:
		return to_global(ATTACK_ORIGIN_2)
	return attack_marker.global_position


## Head pulls back and snaps forward (attack wind-up).
func lunge() -> void:
	var tw := create_tween()
	tw.tween_property(self, "anim_rot", -14.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "anim_rot", 9.0, 0.12)
	tw.tween_property(self, "anim_rot", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	await tw.finished


## Rears up and roars.
func roar() -> void:
	Sfx.play("roar")
	var tw := create_tween()
	tw.tween_property(self, "anim_rot", -18.0, 0.3)
	tw.parallel().tween_property(self, "anim_lift", -30.0, 0.3)
	tw.tween_interval(0.7)
	tw.tween_property(self, "anim_rot", 0.0, 0.5)
	tw.parallel().tween_property(self, "anim_lift", 0.0, 0.5)
	await tw.finished


## Slams down (rockfall attack).
func slam() -> void:
	var tw := create_tween()
	tw.tween_property(self, "anim_lift", -40.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "anim_lift", 30.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "anim_lift", 0.0, 0.6)
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.55, false).timeout


func set_exposed(on: bool) -> void:
	exposed = on


## Armour shards burst from a point.
func shatter(at_global: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 40
	p.lifetime = 1.4
	p.explosiveness = 0.95
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 11.0
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	p.color = Color(0.55, 0.55, 0.65)
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.75, 0.85))
	g.set_color(1, Color(0.35, 0.35, 0.45, 0.0))
	p.color_ramp = g
	p.top_level = true
	p.z_index = 30
	add_child(p)
	p.global_position = at_global
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta)
	if not alive or not breathing:
		return
	var sw := sway * (0.25 if exposed else 1.0)
	var bob := Vector2(sin(_t * 1.3) * 3.0, sin(_t * 2.1) * 4.0) * sw + Vector2(0, anim_lift)
	var shake := Vector2(randf_range(-6, 6), randf_range(-4, 4)) * (_hurt / 0.8)
	position = base_pos + pose_offset + bob + shake
	head.rotation = deg_to_rad(pose_head_rot + anim_rot + sin(_t * 1.7) * 1.5 * sw)
	body_sprite.scale.y = 1.0 + sin(_t * 2.1) * 0.006
	var flash := 1.0 + _hurt * 1.2
	modulate = Color(flash, flash * (1.0 - _hurt * 0.3), flash)
	if _fx:
		_fx.queue_redraw()


func hurt() -> void:
	_hurt = 0.8
	Sfx.play("worm_hurt")


func move_to_pose(offset: Vector2, head_rot: float, t := 1.6) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "pose_offset", offset, t).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "pose_head_rot", head_rot, t).set_trans(Tween.TRANS_SINE)
	await tw.finished


func defeat() -> void:
	alive = false
	activate_weak_point(-1)
	for c in get_children():
		if c is StaticBody2D:
			c.collision_layer = 0
	for c in head.get_children():
		if c is StaticBody2D:
			c.collision_layer = 0
	Sfx.play("roar")
	var tw := create_tween()
	for i in 8:
		tw.tween_property(self, "position", position + Vector2(randf_range(-10, 10), randf_range(-6, 6)), 0.06)
	tw.tween_property(self, "position", position + Vector2(60, 760), 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(head, "rotation", deg_to_rad(25), 2.0)
	await tw.finished
	visible = false


var charge2 := 0.0


func _draw_charge(c: Node2D) -> void:
	if charge2 > 0.0:
		var p2 := ATTACK_ORIGIN_2
		var r2 := 18.0 + 40.0 * charge2
		c.draw_circle(p2, r2 * 1.6, Color(1.0, 0.25, 0.75, 0.15 * charge2))
		c.draw_circle(p2, r2, Color(1.0, 0.35, 0.8, 0.45 * charge2))
	for w in weak_points:
		if w.active and crack_level > 0:
			var lp := to_local(w.global_position)
			for i in crack_level * 4:
				var a := i * 2.3999
				var p0 := lp + Vector2.from_angle(a) * 10.0
				var p1 := lp + Vector2.from_angle(a + 0.3) * (34.0 + crack_level * 16.0)
				var mid := p0.lerp(p1, 0.5) + Vector2.from_angle(a + 1.6) * 7.0
				c.draw_polyline(PackedVector2Array([p0, mid, p1]), Color(0.45, 1.0, 0.95, 0.9), 3.0)
	if exposed:
		for w in weak_points:
			if w.active:
				var k := 0.5 + 0.5 * sin(_t * 6.0)
				var lp := to_local(w.global_position)
				c.draw_circle(lp, 46.0 + 10.0 * k, Color(0.4, 1.0, 0.95, 0.12 + 0.1 * k))
	if charge > 0.0:
		var p := ATTACK_ORIGIN
		var r := 18.0 + 40.0 * charge
		c.draw_circle(p, r * 1.6, Color(1.0, 0.25, 0.75, 0.15 * charge))
		c.draw_circle(p, r, Color(1.0, 0.35, 0.8, 0.45 * charge))
		c.draw_circle(p, r * 0.4, Color(1, 0.9, 1, 0.9 * charge))
