extends Node
## Picks rune spots reachable only via a ricochet, away from gems and targets.
func _ready() -> void:
	var want := [2, 1]
	var out := []
	var paths := ["res://scenes/Level01.tscn", "res://scenes/Level02.tscn"]
	for li in 2:
		var lv = load(paths[li]).instantiate()
		add_child(lv)
		var avoid := []
		for g in lv.find_children("*", "Gem", true, false):
			avoid.append(g.global_position)
			g.collision_layer = 0
		for t in lv.find_children("*", "WaveTarget", true, false):
			avoid.append(t.global_position)
		if lv.has_node("Wall"):
			lv.get_node("Wall").collision_layer = 0
		if lv.has_node("CrystalA"):
			lv.get_node("CrystalA").moving = false
		await get_tree().physics_frame
		var space = lv.get_world_2d().direct_space_state
		var o = lv.miner.strike_origin()
		var cands := []
		var r = lv.reflectors[0]
		var a := -80.0
		while a <= 80.0:
			r.set_angle(a, false)
			await get_tree().physics_frame
			for i in 360:
				var res = WaveTracer.trace(space, o, Vector2.from_angle(i * TAU / 360.0), 2, WaveTracer.PLAYER_MASK)
				var pts = res.points
				for k in range(2, pts.size()):
					var A: Vector2 = pts[k - 1]
					var B: Vector2 = pts[k]
					var L := A.distance_to(B)
					var s := 110.0
					while s < L - 50.0:
						var p := A.lerp(B, s / L)
						var ok := p.x > 330 and p.x < 1600 and p.y > 110 and p.y < 820
						for q in avoid:
							if p.distance_to(q) < 140.0:
								ok = false
						if ok:
							var h = WaveTracer.cast(space, o, p, WaveTracer.PLAYER_MASK)
							if not h.is_empty() and h.position.distance_to(p) > 40.0:
								cands.append(p)
						s += 120.0
			a += 4.0
		var picked := []
		if cands.size() > 0:
			picked.append(cands[cands.size() / 3])
			while picked.size() < want[li]:
				var best = null
				var bd := -1.0
				for c in cands:
					var d := 1e9
					for q in picked:
						d = minf(d, c.distance_to(q))
					if d > bd:
						bd = d
						best = c
				picked.append(best)
		var arr := []
		for p in picked:
			arr.append([roundi(p.x), roundi(p.y)])
		out.append(arr)
		lv.queue_free()
		await get_tree().process_frame
	print("RUNES=", JSON.stringify(out))
	get_tree().quit()
