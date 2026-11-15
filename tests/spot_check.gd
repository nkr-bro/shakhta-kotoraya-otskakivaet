extends "res://tests/autotest.gd"
## For a rune challenge, which miner spots allow a ricochet-only solution?
func _ready() -> void:
	var cases := [
		["res://scenes/Level01.tscn", Vector2(705, 420), [Vector2(1000, 273), Vector2(900, 273), Vector2(1080, 273), Vector2(820, 273)]],
		["res://scenes/Level01.tscn", Vector2(735, 450), [Vector2(1000, 273), Vector2(900, 273), Vector2(820, 273)]],
	]
	for c in cases:
		var lv = load(c[0]).instantiate()
		add_child(lv)
		if lv.has_node("Wall"):
			lv.get_node("Wall").collision_layer = 0
		if lv.has_node("CrystalA"):
			lv.get_node("CrystalA").moving = false
		var t := WaveTarget.new()
		t.radius = 20.0
		t.position = c[1]
		lv.add_child(t)
		await get_tree().physics_frame
		for sp in c[2]:
			lv.miner.position = sp
			lv.miner.face_towards(lv.reflectors[0].global_position)
			await get_tree().physics_frame
			var d := direct_hit_possible(lv, t)
			var sol: Dictionary = await solve(lv, t)
			print(c[0].get_file(), " spot ", sp, " direct=", d, " solvable=", not sol.is_empty())
		lv.queue_free()
		await get_tree().process_frame
	get_tree().quit()
