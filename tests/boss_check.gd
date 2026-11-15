extends Node
## Headless solvability check: every phase of the worm fight must be solvable
## (and need a ricochet) from every spot the miner can be thrown to.

func _ready() -> void:
	var lv = load("res://scenes/Level03.tscn").instantiate()
	add_child(lv)
	await get_tree().physics_frame
	var worm = lv.worm
	worm.breathing = false
	var poses := [[Vector2.ZERO, 0.0], [Vector2(-30, -60), -10.0], [Vector2(-60, -20), 6.0]]
	var bad := 0
	var cands := [["head", Vector2(-190, 238)], ["body", Vector2(1030, 548)], ["body", Vector2(965, 492)], ["body", Vector2(1095, 650)], ["head", Vector2(-110, 228)], ["head", Vector2(10, 120)]]
	if OS.get_environment("CANDS") == "1":
		worm.position = worm.base_pos + poses[2][0]
		worm.head.rotation = deg_to_rad(poses[2][1])
		var wp3 = worm.weak_points[2]
		worm.activate_weak_point(2)
		for c in cands:
			wp3.reparent(worm.head if c[0] == "head" else worm, false)
			wp3.position = c[1]
			var line := str(c)
			for si in lv.MINER_SPOTS.size():
				lv.miner.position = lv.MINER_SPOTS[si]
				for i in 3: await get_tree().physics_frame
				line += "  spot%d solve=%s direct=%s" % [si, str(await solve(lv, wp3)), str(direct(lv, wp3))]
			print("CAND ", line)
		get_tree().quit()
		return
	for ph in 3:
		worm.position = worm.base_pos + poses[ph][0]
		worm.head.rotation = deg_to_rad(poses[ph][1])
		worm.activate_weak_point(ph)
		for si in lv.MINER_SPOTS.size():
			lv.miner.position = lv.MINER_SPOTS[si]
			for i in 3: await get_tree().physics_frame
			var wp = worm.weak_points[ph]
			var r = await solve(lv, wp)
			var d = direct(lv, wp)
			print("phase ", ph + 1, " spot ", si, " solvable ", r, " direct ", d)
			if r == 999.0 or d:
				bad += 1
	print("BAD ", bad)
	get_tree().quit(bad)


func direct(lv, t) -> bool:
	var space = lv.get_world_2d().direct_space_state
	var o = lv.miner.strike_origin()
	for i in 3600:
		var res = WaveTracer.trace(space, o, Vector2.from_angle(i * TAU / 3600.0), 0, WaveTracer.PLAYER_MASK, 3000.0)
		if res.collider == t: return true
	return false


func solve(lv, t) -> float:
	var space = lv.get_world_2d().direct_space_state
	var o = lv.miner.strike_origin()
	var r = lv.crystal_a
	var a: float = r.min_angle
	while a <= r.max_angle:
		r.set_angle(a, false)
		await get_tree().physics_frame
		var axis := Vector2.from_angle(deg_to_rad(a))
		var u: float = -r.length * 0.45
		while u <= r.length * 0.45:
			var res = WaveTracer.trace(space, o, (r.global_position + axis * u - o).normalized(), 3, WaveTracer.PLAYER_MASK)
			if res.collider == t:
				return a
			u += 3.0
		a += 1.0
	return 999.0
