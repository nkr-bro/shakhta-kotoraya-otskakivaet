extends Node
## Chapter 2 with the moving cart: is the crack reachable at several cart positions?
func _ready() -> void:
	var lv = load("res://scenes/Level02.tscn").instantiate()
	add_child(lv)
	await get_tree().physics_frame
	var r = lv.crystal_a
	r.moving = false
	var space = lv.get_world_2d().direct_space_state
	var o = lv.miner.strike_origin()
	var wp = lv.weak
	for dx in [-140.0, -70.0, 0.0, 70.0, 140.0]:
		r.position = r.base_pos + Vector2(dx, 0)
		var found := 999.0
		var a := -85.0
		while a <= 85.0 and found == 999.0:
			r.set_angle(a, false)
			await get_tree().physics_frame
			var axis := Vector2.from_angle(deg_to_rad(a))
			var u := -60.0
			while u <= 60.0:
				var res = WaveTracer.trace(space, o, (r.global_position + axis * u - o).normalized(), 3, WaveTracer.PLAYER_MASK)
				if res.collider == wp:
					found = a
					break
				u += 3.0
			a += 1.0
		print("cart dx ", dx, " solvable at ", found)
	get_tree().quit()
