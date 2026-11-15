class_name LevelBase
extends Node2D
## Shared puzzle loop: select a crystal, rotate it, aim, strike, watch the wave.
## Level scripts add their story beats and react to target hits.

signal objective_changed(text: String)
signal completed
signal fails_changed(count: int)
signal reflector_selected
signal reflector_turned
signal aim_set
signal wave_done(success: bool)

const WAVE_SCENE := preload("res://scenes/EnergyWave.tscn")
const PREVIEW_TAIL := 160.0
const HINT_AFTER := 4

var game: Node
var miner: Miner
var reflectors: Array = []
var selected: Reflector
var aim_dir := Vector2.RIGHT
var default_aim := Vector2.RIGHT
var input_enabled := false
var wave_active := false
var fails := 0
var hint_on := false
var preview_pts := PackedVector2Array()
var preview_kind := ""
var drag_mode := ""        # "", "rotate"
var drag_offset := 0.0
var aim_mouse := Vector2(-100, -100)
var darkness := false
var challenge: WaveTarget
signal challenge_hit
var objective := ""
var show_preview := true
var shots := 0
var lanterns: Array = []
var crystal_glows: Array = []
var ambience: Ambience
var score := 0
var charges := -1   # -1 = unlimited strikes
var streak := 0
var task_time := 0.0
var _locked_on := false
signal streak_changed(streak: int)
var gems_total := 0
var gems_got := 0
signal score_changed(score: int, gems_got: int, gems_total: int)

var _preview: Node2D


func _ready() -> void:
	_preview = Node2D.new()
	_preview.z_index = 50
	_preview.draw.connect(_draw_preview)
	add_child(_preview)
	setup_level()
	ambience = Ambience.new()
	ambience.lanterns = lanterns
	ambience.crystal_glows = crystal_glows
	add_child(ambience)
	for r in reflectors:
		r.rotated.connect(func(_a): reflector_turned.emit())
	for g in find_children("*", "Gem", true, false):
		gems_total += 1
		g.collected.connect(_on_gem)
	aim_dir = default_aim


## Override: collect nodes, set default aim.
func setup_level() -> void:
	pass


## Override: intro dialogue and tutorial, then enable input.
func begin() -> void:
	input_enabled = true


## Override: react to a target being hit.
func on_target_hit(_target: Node) -> void:
	pass


## Override for extra puzzle state.
func reset_puzzle() -> void:
	for r in reflectors:
		r.reset()
	aim_dir = default_aim
	select(null)


func set_objective(t: String) -> void:
	objective = t
	objective_changed.emit(t)


func select(r: Reflector) -> void:
	if selected == r:
		return
	if selected:
		selected.selected = false
		selected.queue_redraw()
	selected = r
	if r:
		r.selected = true
		r.queue_redraw()
		Sfx.play("select", -6.0)
		reflector_selected.emit()


func can_interact() -> bool:
	return input_enabled and not wave_active and not get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or get_tree().paused:
		return
	if event is InputEventMouseMotion:
		var mp: Vector2 = make_input_local(event).position
		for r in reflectors:
			var h: bool = r.visible and r.hit_test(mp)
			if h != r.hovered:
				r.hovered = h
				r.queue_redraw()
		if drag_mode == "aim" and not wave_active:
			set_aim_towards(mp)
		aim_mouse = mp
		if drag_mode == "rotate" and selected and not wave_active:
			var a := rad_to_deg((mp - selected.global_position).angle()) + drag_offset
			a = wrapf(a, -90.0, 90.0)
			selected.set_angle(a)
			Sfx.play("rotate", -14.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var mp: Vector2 = make_input_local(event).position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if wave_active:
					return
				if selected and selected.handle_hit_test(mp):
					_start_drag(selected, mp)
				else:
					var picked: Reflector = null
					for r in reflectors:
						if r.visible and r.hit_test(mp):
							picked = r
					if picked:
						select(picked)
						_start_drag(picked, mp)
					else:
						drag_mode = "aim"
						set_aim_towards(mp)
			else:
				drag_mode = ""
			get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if selected and not wave_active:
				var step := 0.5 if mb.shift_pressed else 1.0
				selected.set_angle(selected.angle_deg + (step if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -step))
				Sfx.play("rotate", -12.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_Q, KEY_E:
				if selected and not wave_active:
					var step := 0.25 if k.shift_pressed else 0.5
					selected.set_angle(selected.angle_deg + (-step if k.physical_keycode == KEY_Q else step))
					Sfx.play("rotate", -12.0)
				get_viewport().set_input_as_handled()
			KEY_TAB:
				_cycle_selection()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				if not k.echo:
					fire()
				get_viewport().set_input_as_handled()
			KEY_R:
				if not k.echo and not wave_active:
					reset_puzzle()
				get_viewport().set_input_as_handled()


func _cycle_selection() -> void:
	var vis := reflectors.filter(func(r): return r.visible)
	if vis.is_empty():
		return
	var i := vis.find(selected)
	select(vis[(i + 1) % vis.size()])


func _start_drag(r: Reflector, mp: Vector2) -> void:
	drag_mode = "rotate"
	drag_offset = r.angle_deg - rad_to_deg((mp - r.global_position).angle())


func set_aim_towards(p: Vector2) -> void:
	if wave_active:
		return
	var o := miner.strike_origin()
	if p.distance_to(o) < 8.0:
		return
	aim_dir = (p - o).normalized()
	miner.face_towards(p)
	aim_dir = (p - miner.strike_origin()).normalized()
	aim_set.emit()


func fire() -> void:
	if not can_interact() or miner.busy or charges == 0:
		return
	if charges > 0:
		charges -= 1
		score_changed.emit(score, gems_got, gems_total)
	wave_active = true
	drag_mode = ""
	for r in reflectors:
		r.locked = true
	miner.swing()
	await miner.struck
	var w: EnergyWave = WAVE_SCENE.instantiate()
	var pick := Pickaxes.equipped()
	w.color = pick.color
	if Pickaxes.has("storm"):
		w.speed = 1500.0
	add_child(w)
	w.launch(miner.strike_origin(), aim_dir)
	shots += 1
	var res: Array = await w.finished
	var success: bool = res[0]
	var collider: Object = res[1]
	var bounces: int = w.bounce_count
	var mult := (2 if w.boosted else 1) * maxi(1, streak + 1)
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.15, false).timeout
	for r in reflectors:
		r.locked = false
	wave_active = false
	if success and collider and collider.is_in_group("wave_target"):
		var speed_bonus := maxi(0, int(30.0 - task_time)) * 20
		score += speed_bonus
		if speed_bonus > 0 and game:
			game.hud.popup("Скорость! +%d" % speed_bonus, collider.global_position + Vector2(0, -50))
		streak += 1
		streak_changed.emit(streak)
		task_time = 0.0
	if success and collider and collider == challenge:
		score += 300 * maxi(1, bounces) * mult
		score_changed.emit(score, gems_got, gems_total)
		if game:
			game.hit_stop()
			game.hud.flash_hit()
			game.hud.popup("Руна зажжена!  +%d" % (300 * maxi(1, bounces)), collider.global_position)
		challenge_hit.emit()
	elif success and collider and collider.is_in_group("wave_target"):
		var pts := 300 * maxi(1, bounces) * mult
		score += pts
		score_changed.emit(score, gems_got, gems_total)
		if game:
			game.hit_stop()
			game.shake(7.0, 0.3)
			game.hud.flash_hit()
			if bounces >= 2:
				game.hud.popup("Рикошет ×%d!  +%d" % [bounces, pts], collider.global_position)
			else:
				game.hud.popup("+%d" % pts, collider.global_position)
		on_target_hit(collider)
	else:
		fails += 1
		fails_changed.emit(fails)
		if streak > 0 and game:
			game.hud.popup("Серия прервана", miner.global_position + Vector2(0, -140))
		streak = 0
		streak_changed.emit(streak)
		if game:
			game.flash_miss()
		if charges == 0 and game:
			input_enabled = false
			game.out_of_charges()
	wave_done.emit(success)


## Moves the hero to another ledge for the next exercise.
func move_miner(pos: Vector2, text := "") -> void:
	input_enabled = false
	drag_mode = ""
	Sfx.play("swing", -4.0, 0.8)
	await miner.hop_to(pos)
	if reflectors.size() > 0:
		default_aim = (reflectors[0].global_position - miner.strike_origin()).normalized()
		aim_dir = default_aim
		miner.face_towards(reflectors[0].global_position)
	if text != "":
		toast(text, 2.4)


## Bonus exercise: a rune that must be lit with a ricochet.
func run_challenge(pos: Vector2, text: String) -> void:
	challenge = WaveTarget.new()
	challenge.radius = 20.0
	challenge.marker_color = Color(0.7, 0.85, 1.0)
	challenge.position = pos
	challenge.z_index = 9
	add_child(challenge)
	var glyph := Node2D.new()
	glyph.draw.connect(func():
		var k := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 200.0)
		glyph.draw_circle(Vector2.ZERO, 16.0, Color(0.1, 0.12, 0.2, 0.9))
		glyph.draw_arc(Vector2.ZERO, 16.0, 0, TAU, 24, Color(0.7, 0.85, 1.0, k), 2.5)
		glyph.draw_line(Vector2(-7, 8), Vector2(0, -9), Color(0.7, 0.85, 1.0, k), 2.5)
		glyph.draw_line(Vector2(0, -9), Vector2(7, 8), Color(0.7, 0.85, 1.0, k), 2.5)
		glyph.draw_line(Vector2(-5, 2), Vector2(5, 2), Color(0.7, 0.85, 1.0, k), 2.5))
	challenge.add_child(glyph)
	glyph.set_process(true)
	var t := Timer.new()
	t.wait_time = 0.05
	t.autostart = true
	t.timeout.connect(glyph.queue_redraw)
	glyph.add_child(t)
	set_objective(text)
	input_enabled = true
	await challenge_hit
	input_enabled = false
	var c := challenge
	challenge = null
	c.set_active(false)
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2(2.5, 2.5), 0.4)
	tw.parallel().tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_callback(c.queue_free)
	miner.cheer()
	await wait(0.8)


func _on_gem(g: Gem) -> void:
	Save.wallet += 1
	Save.save_data()
	gems_got += 1
	score += 250
	if charges >= 0:
		charges += 1
	score_changed.emit(score, gems_got, gems_total)
	if game:
		game.hud.popup("Самоцвет %d/%d  +250%s" % [gems_got, gems_total, "  +1 удар" if charges >= 0 else ""], g.global_position)


func toggle_hint() -> void:
	hint_on = not hint_on


func _physics_process(_delta: float) -> void:
	if not (input_enabled and show_preview and miner):
		preview_pts = PackedVector2Array()
		_preview.queue_redraw()
		return
	var space := get_world_2d().direct_space_state
	var bounces := 6 if hint_on else (2 if Pickaxes.has("echo") else 1)
	var tail := 2400.0 if hint_on else PREVIEW_TAIL
	if darkness and not hint_on:
		bounces = 0
		tail = 260.0
	var r := WaveTracer.trace(space, miner.strike_origin(), aim_dir, bounces, WaveTracer.PLAYER_MASK, tail)
	preview_pts = r.points
	preview_kind = r.kind
	var lock: bool = r.kind == "target"
	if lock and not _locked_on and not wave_active:
		Sfx.play("select", -8.0, 1.5)
	_locked_on = lock
	_preview.queue_redraw()


func _draw_preview() -> void:
	if preview_pts.size() < 2 or wave_active:
		return
	var col := Color(1.0, 0.85, 0.3, 1.0) if preview_kind == "target" else Color(0.55, 1.0, 0.95, 0.85)
	var dash := 10.0
	var gap := 8.0
	var phase := fmod(Time.get_ticks_msec() / 40.0, dash + gap)
	for i in range(1, preview_pts.size()):
		var a := preview_pts[i - 1]
		var b := preview_pts[i]
		var seg := b - a
		var L := seg.length()
		if L < 0.5:
			continue
		var d := seg / L
		var fade := 1.0 if i == 1 else (0.75 if hint_on else 0.55)
		var s := -phase
		while s < L:
			var s0 := maxf(s, 0.0)
			var s1 := minf(s + dash, L)
			if s1 > s0:
				_preview.draw_line(a + d * s0, a + d * s1, Color(col, col.a * fade), 2.0)
			s += dash + gap
		if i < preview_pts.size() - 1:
			_preview.draw_circle(b, 4.0, Color(1, 1, 1, 0.8))
	var end := preview_pts[preview_pts.size() - 1]
	if preview_kind == "target":
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 70.0)
		_preview.draw_arc(end, 14.0 + 8.0 * k, 0, TAU, 24, Color(1.0, 0.9, 0.4, 0.9), 3.0)
		_preview.draw_arc(end, 30.0 + 10.0 * k, 0, TAU, 32, Color(1.0, 0.8, 0.3, 0.4), 2.0)
	elif preview_kind == "wall":
		_preview.draw_line(end + Vector2(-5, -5), end + Vector2(5, 5), Color(1, 0.5, 0.4, 0.8), 2.0)
		_preview.draw_line(end + Vector2(-5, 5), end + Vector2(5, -5), Color(1, 0.5, 0.4, 0.8), 2.0)
	_preview.draw_circle(miner.strike_origin(), 4.0, Color(col, 0.9))
	if drag_mode == "aim":
		var m := aim_mouse
		_preview.draw_arc(m, 14.0, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)
		for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			_preview.draw_line(m + v * 8.0, m + v * 20.0, Color(1, 1, 1, 0.8), 2.0)


func _process(_delta: float) -> void:
	if input_enabled and not wave_active:
		task_time += _delta
	if preview_pts.size() > 1:
		_preview.queue_redraw()


func say(lines: Array) -> void:
	if game:
		await game.say(lines)


func toast(t: String, dur := 2.4) -> void:
	if game:
		game.toast(t, dur)


func wait(sec: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(sec, false).timeout
