extends Node2D
## Final frame: everyone back at the mine entrance at sunset.

func _ready() -> void:
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/bg/level1.png")
	bg.centered = false
	add_child(bg)
	var hero := Miner.new()
	hero.position = Vector2(468, 306)
	hero.body_scale = 0.58
	add_child(hero)
	var sheets := ["npc_brother_sheet", "npc_mechanic_sheet", "npc_worker_sheet", "npc_worker_sheet"]
	var xs := [330.0, 270.0, 215.0, 160.0]
	for i in sheets.size():
		var n := Npc.new()
		n.sheet = load("res://assets/sprites/%s.png" % sheets[i])
		n.body_scale = 0.6 if i == 0 else 0.56
		n.facing = 1
		n.position = Vector2(xs[i], 306)
		add_child(n)
		n.mode = "cheer" if i % 2 == 0 else "idle"
