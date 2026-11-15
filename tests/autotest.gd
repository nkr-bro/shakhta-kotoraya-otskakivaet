extends Node
## Windowed end-to-end run. Drives the real game with synthetic mouse/keyboard
## events (the same path as a player), finds reflector angles with the real
## ray tracer, plays all chapters, checks misses, reset, losing and winning the
## boss fight, and saves screenshots to tests/screens/.

var game: Node
var log_lines: PackedStringArray = []
var shot_dir := "res://tests/screens/"
var failures := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	Save.progress = 0
	Save.next_chapter = 2 if OS.get_environment("AUTOTEST_BOSS") == "1" else 0
	game = load("res://scenes/Game.tscn").instantiate()
	game.pause_on_focus_loss = false
	add_child(game)
	run()


func note(t: String) -> void:
	print("[autotest] ", t)
	log_lines.append(t)


func check(cond: bool, what: String) -> void:
	if cond:
		note("PASS " + what)
	else:
		failures += 1
		note("FAIL " + what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func secs(t: float) -> void:
	await get_tree().create_timer(t).timeout


func key(code: int, shift := false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		e.shift_pressed = shift
		get_viewport().push_input(e, true)
		await get_tree().process_frame


func click(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	get_viewport().push_input(m, true)
	await get_tree().process_frame
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		get_viewport().push_input(e, true)
		await get_tree().process_frame


func drag(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = from
	get_viewport().push_input(e, true)
	await get_tree().process_frame
	for i in 10:
		var m := InputEventMouseMotion.new()
		m.position = from.lerp(to, (i + 1) / 10.0)
		get_viewport().push_input(m, true)
		await get_tree().process_frame
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = to
	get_viewport().push_input(u, true)
	await get_tree().process_frame


func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(shot_dir + name + ".png"))
	note("screenshot " + name)


## Waits until the level accepts input, advancing dialogue/cards like a player.
func wait_playable(timeout := 90.0) -> bool:
	var t := 0.0
	while t < timeout:
		var hud: Hud = game.hud
		if hud.overlay.visible:
			for c in hud.overlay_box.get_children():
				if c is Button and c.text == "Дальше":
					c.emit_signal("pressed")
			await secs(0.3)
			t += 0.3
			continue
		if hud.card.visible or hud.is_dialogue_open():
			await key(KEY_SPACE)
			await secs(0.25)
			t += 0.25
			continue
		if game.level and game.level.input_enabled and not game.level.wave_active:
			return true
		await secs(0.1)
		t += 0.1
	return false


func active_target() -> Node:
	for n in get_tree().get_nodes_in_group("wave_target"):
		if n.is_inside_tree() and n.active:
			return n
	return null


## Brute-force search over reflector angles and aim points using the real tracer.
func solve(level: LevelBase, target: Node, only: Array = []) -> Dictionary:
	var space := level.get_world_2d().direct_space_state
	var origin := level.miner.strike_origin()
	for r in level.reflectors:
		if not r.visible or (not only.is_empty() and not only.has(r)):
			continue
		var saved: float = r.angle_deg
		var a: float = r.min_angle
		var start: float = r.start_angle
		# keep the grid aligned with 0.5° key steps from the start angle
		a = start - floor((start - r.min_angle) / 0.5) * 0.5
		while a <= r.max_angle:
			r.set_angle(a, false)
			await get_tree().physics_frame
			var axis := Vector2.from_angle(deg_to_rad(a))
			var u: float = -r.length * 0.45
			while u <= r.length * 0.45:
				var p: Vector2 = r.global_position + axis * u
				var dir := (p - origin).normalized()
				var res := WaveTracer.trace(space, origin, dir, 4, WaveTracer.PLAYER_MASK)
				if res.collider == target and res.bounces >= 1:
					# robustness: neighbours must hit too
					var ok := 0
					for du in [-2.0, 2.0]:
						var d2: Vector2 = (r.global_position + axis * (u + du) - origin).normalized()
						if WaveTracer.trace(space, origin, d2, 4, WaveTracer.PLAYER_MASK).collider == target:
							ok += 1
					if ok == 2:
						r.set_angle(saved, false)
						await get_tree().physics_frame
						return {"reflector": r, "angle": a, "aim": p, "bounces": res.bounces}
				u += 3.0
			a += 0.5
		r.set_angle(saved, false)
		await get_tree().physics_frame
	return {}


## Two reflections r1 -> r2 -> target: sweep r1, then compute the r2 angle
## that would send the ray to the target and verify with the full trace.
func solve2(level: LevelBase, target: Node, r1: Reflector, r2: Reflector) -> Dictionary:
	var space := level.get_world_2d().direct_space_state
	var origin := level.miner.strike_origin()
	var a: float = r1.start_angle - floor((r1.start_angle - r1.min_angle) / 0.5) * 0.5
	while a <= r1.max_angle:
		r1.set_angle(a, false)
		await get_tree().physics_frame
		var axis := Vector2.from_angle(deg_to_rad(a))
		var u: float = -r1.length * 0.4
		while u <= r1.length * 0.4:
			var p: Vector2 = r1.global_position + axis * u
			var dir := (p - origin).normalized()
			var res := WaveTracer.trace(space, origin, dir, 1, WaveTracer.PLAYER_MASK, 2400.0)
			if res.bounces == 1 and res.points.size() >= 3:
				var hp: Vector2 = res.points[1]
				var d: Vector2 = (res.points[2] - hp).normalized()
				var to_c: Vector2 = r2.global_position - hp
				var along: float = to_c.dot(d)
				var miss: float = (to_c - d * along).length()
				if along > 0.0 and miss < r2.length * 0.3:
					var out: Vector2 = (target.global_position - r2.global_position).normalized()
					var n: Vector2 = (out - d).normalized()
					var ang: float = wrapf(rad_to_deg(n.angle()) + 90.0, -90.0, 90.0)
					ang = r2.start_angle + round((ang - r2.start_angle) / 0.5) * 0.5
					if ang >= r2.min_angle and ang <= r2.max_angle:
						for da in [0.0, 0.5, -0.5, 1.0, -1.0]:
							r2.set_angle(ang + da, false)
							await get_tree().physics_frame
							var full := WaveTracer.trace(space, origin, dir, 4, WaveTracer.PLAYER_MASK)
							if full.collider == target and full.bounces >= 2:
								return {"settings": [[r1, a], [r2, ang + da]], "aim": p, "reflector": r1, "angle": a, "bounces": 2}
			u += 4.0
		a += 0.5
	return {}


func direct_hit_possible(level: LevelBase, target: Node) -> bool:
	var space := level.get_world_2d().direct_space_state
	var origin := level.miner.strike_origin()
	for i in 3600:
		var dir := Vector2.from_angle(i * TAU / 3600.0)
		var res := WaveTracer.trace(space, origin, dir, 0, WaveTracer.PLAYER_MASK, 3000.0)
		if res.collider == target:
			return true
	return false


## Applies a solution through the player's controls: click the crystal, turn it
## with Q/E, click the scene to aim, press Space.
func set_crystal(level: LevelBase, r: Reflector, angle: float) -> void:
	while not level.input_enabled or level.wave_active or level.miner.busy:
		await secs(0.1)
	await click(r.global_position)
	await frames(2)
	check(level.selected == r, "click selects crystal %s" % r.name)
	var steps: int = roundi((angle - r.angle_deg) / 0.5)
	for i in absi(steps):
		await key(KEY_E if steps > 0 else KEY_Q)
	check(absf(r.angle_deg - angle) < 0.01, "Q/E rotates %s to %.1f° (now %.2f°)" % [r.name, angle, r.angle_deg])


func apply_and_fire(level: LevelBase, sol: Dictionary, fire := true) -> bool:
	var settings: Array = sol.get("settings", [[sol.reflector, sol.angle]])
	for st in settings:
		await set_crystal(level, st[0], st[1])
	var r: Reflector = sol.reflector
	var origin := level.miner.strike_origin()
	var aim_p: Vector2 = sol.aim
	var dist := origin.distance_to(aim_p)
	var dvec := (aim_p - origin).normalized()
	var click_p := origin + dvec * 25.0
	for dd in [25.0, 35.0, dist - r.length * 0.5 - 50.0, dist + 120.0, dist + 200.0, dist + 320.0]:
		var cp: Vector2 = origin + dvec * maxf(dd, 20.0)
		var free := Rect2(10, 120, 1650, 720).has_point(cp)
		for rr in level.reflectors:
			if rr.visible and rr.hit_test(cp):
				free = false
		if free:
			click_p = cp
			break
	await click(click_p)
	await frames(3)
	var want := (aim_p - origin).normalized()
	if level.aim_dir.dot(want) <= 0.99999:
		note("aim debug: input=%s wave=%s drag=%s click=%s origin=%s sel=%s" % [level.input_enabled, level.wave_active, level.drag_mode, str(click_p), str(origin), str(level.selected)])
	check(level.aim_dir.dot(want) > 0.99999, "click sets aim")
	await frames(2)
	if fire:
		await key(KEY_SPACE)
		await secs(0.45)
	return true


func wait_wave() -> bool:
	var res = await game.level.wave_done
	return bool(res)


func run() -> void:
	await secs(1.0)
	if OS.get_environment("AUTOTEST_BOSS") == "1":
		await run_boss()
		await wait_ending()
		return finish()
	# ------------------------------------------------ chapter 1
	check(await wait_playable(), "chapter 1 playable")
	var lv: LevelBase = game.level
	var miner_pos := lv.miner.global_position
	var target := active_target()
	check(target != null, "L1 target active")
	check(not direct_hit_possible(lv, target), "L1: no direct line from the pickaxe to the latch")
	# a deliberate miss with the starting crystal angle
	await key(KEY_SPACE)
	var ok: bool = await wait_wave()
	check(not ok and lv.fails == 1, "L1 starting angle misses (fails=%d)" % lv.fails)
	# reset check
	await click(lv.reflectors[0].global_position)
	for i in 10:
		await key(KEY_E)
	await key(KEY_R)
	await frames(2)
	check(is_equal_approx(lv.reflectors[0].angle_deg, lv.reflectors[0].start_angle), "R restores crystal angle")
	# drag handle rotation
	await click(lv.reflectors[0].global_position)
	var h0: Vector2 = lv.reflectors[0].handle_global()
	var before: float = lv.reflectors[0].angle_deg
	await drag(h0, lv.reflectors[0].global_position + (h0 - lv.reflectors[0].global_position).rotated(deg_to_rad(20)))
	check(absf(lv.reflectors[0].angle_deg - before - 20.0) < 1.5, "dragging handle turns crystal smoothly (%.1f -> %.1f)" % [before, lv.reflectors[0].angle_deg])
	await key(KEY_R)
	var sol: Dictionary = await solve(lv, target)
	check(not sol.is_empty(), "L1 solvable: %s" % str(sol.get("angle", "-")))
	if sol.is_empty():
		return finish()
	await apply_and_fire(lv, sol)
	await screenshot("level1_wave")
	ok = await wait_wave()
	check(ok, "L1 latch hit by real ricochet")
	check(lv.miner.global_position == miner_pos, "hero did not move")
	await secs(3.0)
	await screenshot("level1_mechanism")
	check(await wait_playable(), "L1 rune playable")
	target = active_target()
	sol = await solve(lv, target)
	check(not sol.is_empty(), "L1 rune solvable: %s" % str(sol.get("angle", "-")))
	if sol.is_empty():
		return finish()
	await apply_and_fire(lv, sol)
	check(await wait_wave(), "L1 rune lit")

	# ------------------------------------------------ chapter 2
	check(await wait_playable(), "chapter 2 playable")
	lv = game.level
	await secs(0.3)
	target = active_target()
	lv.crystal_a.moving = false
	check(not direct_hit_possible(lv, target), "L2: hanging beam blocks the direct line to the crack")
	sol = await solve(lv, target)
	check(not sol.is_empty(), "L2 stage 1 solvable: %s" % str(sol.get("angle", "-")))
	if sol.is_empty():
		return finish()
	await apply_and_fire(lv, sol)
	await screenshot("level2_wave")
	check(await wait_wave(), "L2 wall weak point hit")
	check(await wait_playable(), "L2 stage 2 playable")
	target = active_target()
	check(target != null and target.name == "PowerSocket", "L2 power socket active")
	check(not direct_hit_possible(lv, target), "L2: socket not reachable directly")
	await secs(1.5)
	sol = await solve(lv, target)
	check(sol.is_empty(), "L2 stage 2: no single-reflection solution (boulder blocks)")
	sol = await solve2(lv, target, lv.crystal_a, lv.crystal_b)
	check(not sol.is_empty(), "L2 stage 2 solvable with two reflections: %s" % str(sol.get("settings", "-")))
	if sol.is_empty():
		return finish()
	await apply_and_fire(lv, sol)
	await screenshot("level2_power")
	check(await wait_wave(), "L2 socket hit")
	lv.crystal_a.moving = false
	check(await wait_playable(), "L2 rune playable")
	target = active_target()
	sol = await solve(lv, target)
	check(not sol.is_empty(), "L2 rune solvable: %s" % str(sol.get("angle", "-")))
	if sol.is_empty():
		return finish()
	await apply_and_fire(lv, sol)
	check(await wait_wave(), "L2 rune lit")

	if OS.get_environment("SKIP_BOSS") == "1":
		return finish()
	await run_boss()
	await wait_ending()
	finish()


func wait_ending() -> void:
	var t := 0.0
	while t < 90.0:
		var is_end := false
		for c in game.hud.overlay_box.get_children():
			if c is Label and c.text == "Конец":
				is_end = true
			if c is Button and c.text == "Дальше" and game.hud.overlay.visible:
				c.emit_signal("pressed")
		if is_end and game.hud.overlay.visible:
			break
		if game.hud.is_dialogue_open():
			await key(KEY_SPACE)
		await secs(0.3)
		t += 0.3
	var title_ok := false
	for c in game.hud.overlay_box.get_children():
		if c is Label and c.text == "Конец":
			title_ok = true
	check(title_ok, "ending reached")
	await screenshot("ending")
	check(Save.progress == 3, "progress saved (%d)" % Save.progress)


func run_boss() -> void:
	var lv: LevelBase
	# ------------------------------------------------ chapter 3: lose first
	check(await wait_playable(), "chapter 3 playable")
	lv = game.level
	note("waiting for blasts to break the shield (crystal B left at its start angle)")
	var t := 0.0
	var shot_tele := false
	var saw_rocks := false
	while not game.hud.overlay.visible and t < 200.0:
		await secs(0.5)
		t += 0.5
		for c in lv.get_children():
			if c is FallingRock:
				saw_rocks = true
		if lv.telegraphing and not shot_tele and t > 4.0:
			shot_tele = true
			await screenshot("level3_telegraph")
	check(game.hud.overlay.visible, "L3 can be lost (shield destroyed after %.0fs)" % t)
	check(saw_rocks, "L3 rockfall attack happened")
	check(lv.attacks >= 3, "L3 worm attacked %d times" % lv.attacks)
	var retry: Button = null
	for c in game.hud.overlay_box.get_children():
		if c is Button and c.text.begins_with("Начать"):
			retry = c
	await click(retry.get_global_rect().get_center())
	await secs(1.0)
	check(await wait_playable(), "L3 restarts after loss")
	lv = game.level
	check(lv.elevator.hp == 3, "shield restored to 3")
	for ph in [1, 2, 3]:
		var ok_phase := await boss_phase(lv, ph)
		if not ok_phase:
			return
	await secs(1.5)
	await screenshot("level3_victory")


func defends_now(lv, n: int) -> bool:
	var space: PhysicsDirectSpaceState2D = lv.get_world_2d().direct_space_state
	for i in n:
		var res := WaveTracer.trace(space, lv.worm.attack_origin(i), lv._attack_dir(i), 2, WaveTracer.HOSTILE_MASK)
		if res.kind == "shield" or res.bounces < 1:
			return false
	return true


func defend_angle(lv, n := 2) -> float:
	var space: PhysicsDirectSpaceState2D = lv.get_world_2d().direct_space_state
	var b: Reflector = lv.crystal_b
	var best := 999.0
	var good: Array = []
	var cur: Array = []
	var a: float = b.start_angle - floor((b.start_angle - b.min_angle) / 0.5) * 0.5
	while a <= b.max_angle:
		b.set_angle(a, false)
		await get_tree().physics_frame
		var ok := true
		for i in n:
			var res := WaveTracer.trace(space, lv.worm.attack_origin(i), lv._attack_dir(i), 2, WaveTracer.HOSTILE_MASK)
			if res.kind == "shield" or res.bounces < 1:
				ok = false
		if ok:
			cur.append(a)
		else:
			if cur.size() > good.size():
				good = cur
			cur = []
		a += 0.5
	if cur.size() > good.size():
		good = cur
	if not good.is_empty():
		best = good[good.size() / 2]
	b.set_angle(b.start_angle, false)
	await get_tree().physics_frame
	return best


func boss_phase(lv, ph: int) -> bool:
	t_wait_phase(lv, ph)
	while lv.phase != ph or not lv.input_enabled:
		await secs(0.2)
	var wp: WaveTarget = lv.worm.weak_points[ph - 1]
	var n := 2 if ph == 3 else 1
	if not defends_now(lv, n):
		var da: float = await defend_angle(lv, n)
		check(da < 999.0, "phase %d: crystal B can deflect the blasts (%.1f°)" % [ph, da])
		await set_crystal(lv, lv.crystal_b, da)
	check(defends_now(lv, n), "phase %d: crystal B angle deflects the blasts" % ph)
	check(wp.active, "phase %d crack is aimable" % ph)
	await frames(3)
	var direct := direct_hit_possible(lv, wp)
	var sol: Dictionary = await solve(lv, wp, [lv.crystal_a])
	check(not direct, "phase %d weak point needs a ricochet" % ph)
	check(not sol.is_empty(), "phase %d solvable via big crystal: %s" % [ph, str(sol.get("angle", "-"))])
	if sol.is_empty():
		return false
	await apply_and_fire(lv, sol, false)
	var last_pos: Vector2 = lv.miner.position
	var t := 0.0
	while lv.phase == ph and t < 240.0 and lv.fighting:
		if lv.miner.position != last_pos and lv.input_enabled and not lv.miner.busy:
			note("miner was thrown to %s — searching a new angle" % str(lv.miner.position))
			last_pos = lv.miner.position
			var sol2: Dictionary = await solve(lv, wp, [lv.crystal_a])
			check(not sol2.is_empty(), "phase %d solvable from the new spot" % ph)
			if not sol2.is_empty():
				await apply_and_fire(lv, sol2, false)
			continue
		if lv.worm.exposed and lv.input_enabled and not lv.wave_active and lv.miner.position == last_pos:
			await key(KEY_SPACE)
			if ph == 1 and not FileAccess.file_exists(ProjectSettings.globalize_path(shot_dir + "level3_wave.png")):
				await secs(0.5)
				await screenshot("level3_wave")
			var _r = await lv.wave_done
			await secs(0.3)
		else:
			await secs(0.2)
			t += 0.2
		if lv.elevator.hp <= 0:
			break
	check(lv.phase > ph or not lv.fighting, "phase %d weak point broken (shield hp %d)" % [ph, lv.elevator.hp])
	return lv.phase > ph or (ph == 3 and not lv.fighting)


func t_wait_phase(_lv, _ph) -> void:
	pass


func finish() -> void:
	note("DONE failures=%d" % failures)
	var f := FileAccess.open(ProjectSettings.globalize_path("res://tests/autotest_log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	get_tree().quit(failures)
