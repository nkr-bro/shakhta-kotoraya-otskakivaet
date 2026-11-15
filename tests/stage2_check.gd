extends "res://tests/autotest.gd"
func _ready() -> void:
	var lv = load("res://scenes/Level02.tscn").instantiate()
	add_child(lv)
	lv.get_node("Wall").collision_layer = 0
	lv.crystal_b.set_enabled(true)
	var chunk := FallingRock.new()
	chunk.radius = 34.0
	chunk.floor_y = 672.0
	chunk.life = 1.0e9
	chunk.position = Vector2(1205, 638)
	chunk.landed = true
	lv.add_child(chunk)
	lv.socket.set_active(true)
	lv.crystal_a.moving = false
	await get_tree().physics_frame
	for dx in [-140.0, 0.0, 140.0]:
		lv.crystal_a.position = lv.crystal_a.base_pos + Vector2(dx, 0)
		await get_tree().physics_frame
		var sol = await solve2(lv, lv.socket, lv.crystal_a, lv.crystal_b)
		print("stage2 cart dx ", dx, " -> ", "none" if sol.is_empty() else str([sol.settings[0][1], sol.settings[1][1]]))
	get_tree().quit()
