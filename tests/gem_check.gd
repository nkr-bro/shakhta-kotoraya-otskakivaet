extends Node
## Which gems can a wave reach (with up to 4 reflections) in each level?
func _ready() -> void:
	for path in ["res://scenes/Level01.tscn", "res://scenes/Level02.tscn", "res://scenes/Level03.tscn"]:
		var lv = load(path).instantiate()
		add_child(lv)
		if lv.has_node("Wall"):
			lv.get_node("Wall").collision_layer = 0
		if lv.has_node("CrystalB"):
			lv.get_node("CrystalB").set_enabled(true)
		await get_tree().physics_frame
		var space = lv.get_world_2d().direct_space_state
		var o = lv.miner.strike_origin()
		var found := {}
		var direct := {}
		for g in lv.find_children("*", "Gem", true, false):
			found[g.name] = 0
			direct[g.name] = false
		for i in 1440:
			var res = WaveTracer.trace(space, o, Vector2.from_angle(i * TAU / 1440.0), 0, WaveTracer.PLAYER_MASK, 3000.0)
			for g in res.gems: direct[g.name] = true
		var r = lv.reflectors[0]
		var a := -84.0
		while a <= 84.0:
			r.set_angle(a, false)
			await get_tree().physics_frame
			for i in 720:
				var res = WaveTracer.trace(space, o, Vector2.from_angle(i * TAU / 720.0), 4, WaveTracer.PLAYER_MASK)
				if res.bounces >= 1:
					for g in res.gems: found[g.name] += 1
			a += 3.0
		print(path.get_file(), " reach(bounce)=", found, " direct=", direct)
		lv.queue_free()
		await get_tree().process_frame
	get_tree().quit()
