extends "res://tests/autotest.gd"
## Plays the whole worm fight: defends with crystal B, pre-computes the shot
## for the current spot, strikes whenever the crack opens.

func _ready() -> void:
	Save.next_chapter = 2
	game = load("res://scenes/Game.tscn").instantiate()
	game.pause_on_focus_loss = false
	add_child(game)
	dbg()

func dbg() -> void:
	await wait_playable()
	var lv = game.level
	var t0 := Time.get_ticks_msec()
	var sol := {}
	var sol_key := ""
	var shots := 0
	while lv.fighting or lv.phase == 0:
		await secs(0.2)
		if game.hud.is_dialogue_open():
			await key_space()
			continue
		if (Time.get_ticks_msec() - t0) > 420000:
			break
		if lv.phase == 0 or not lv.input_enabled or lv.miner.busy or lv.wave_active:
			continue
		var n := 2 if lv.phase == 3 else 1
		if not defends_now(lv, n):
			var da: float = await defend_angle(lv, n)
			lv.crystal_b.set_angle(da, false)
			print("phase ", lv.phase, " defend at ", da)
		var key := "%d-%s" % [lv.phase, str(lv.miner.position)]
		if key != sol_key:
			var wp = lv.worm.weak_points[lv.phase - 1]
			sol = await solve(lv, wp, [lv.crystal_a])
			sol_key = key
			print("phase ", lv.phase, " spot ", lv.miner.position, " solution ", sol.get("angle", "none"))
		if lv.worm.exposed and not sol.is_empty() and lv.input_enabled and not lv.wave_active and not lv.miner.busy:
			lv.crystal_a.set_angle(sol.angle, false)
			await get_tree().physics_frame
			lv.aim_dir = (sol.aim - lv.miner.strike_origin()).normalized()
			var ph_before: int = lv.phase
			lv.fire()
			await secs(0.1)
			if not lv.wave_active and not lv.miner.busy:
				continue
			shots += 1
			var w := 0.0
			while (lv.wave_active or lv.miner.busy) and w < 5.0:
				await secs(0.1)
				w += 0.1
			print("shot ", shots, " phase ", ph_before, " -> ", lv.phase, " hp ", lv.elevator.hp)
		if game.hud.is_dialogue_open():
			await key_space()
		if (Time.get_ticks_msec() - t0) > 400000:
			break
	print("RESULT fighting=", lv.fighting, " phase=", lv.phase, " hp=", lv.elevator.hp, " shots=", shots, " time=", (Time.get_ticks_msec() - t0) / 1000)
	get_tree().quit()

func key_space() -> void:
	await key(KEY_SPACE)
