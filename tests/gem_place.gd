extends Node
## Picks gem spots that a wave reaches only after a reflection.
func _ready() -> void:
	var out := []
	for path in ["res://scenes/Level01.tscn", "res://scenes/Level02.tscn", "res://scenes/Level03.tscn"]:
		var lv = load(path).instantiate()
		add_child(lv)
		for g in lv.find_children("*", "Gem", true, false):
			g.collision_layer = 0
		if lv.has_node("Wall"):
			lv.get_node("Wall").collision_layer = 0
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
				var res = WaveTracer.trace(space, o, Vector2.from_angle(i * TAU / 360.0), 3, WaveTracer.PLAYER_MASK)
				var pts = res.points
				for k in range(2, pts.size()):
					var A: Vector2 = pts[k - 1]
					var B: Vector2 = pts[k]
					var L := A.distance_to(B)
					var s := 120.0
					while s < L - 40.0:
						var p := A.lerp(B, s / L)
						if p.x > 330 and p.x < 1610 and p.y > 90 and p.y < 840:
							var h = WaveTracer.cast(space, o, p, WaveTracer.PLAYER_MASK)
							if not h.is_empty() and h.position.distance_to(p) > 30.0:
								cands.append(p)
						s += 140.0
			a += 4.0
		var picked := []
		if cands.size() > 0:
			picked.append(cands[cands.size() / 2])
			while picked.size() < 3:
				var best = null
				var bd := -1.0
				for c in cands:
					var d := 1e9
					for q in picked:
						d = minf(d, c.distance_to(q))
					if d > bd and d < 1e9:
						bd = d
						best = c
				picked.append(best)
		var arr := []
		for p in picked:
			arr.append([roundi(p.x), roundi(p.y)])
		print(path.get_file(), " candidates ", cands.size(), " picked ", arr)
		out.append(arr)
		lv.queue_free()
		await get_tree().process_frame
	print("GEMS=", JSON.stringify(out))
	get_tree().quit()
