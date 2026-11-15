class_name Pickaxes
## Craftable pickaxes. Each changes how the wave behaves.

const LIST := [
	{"id": "standard", "name": "Basic Pickaxe", "cost": 0, "color": Color(0.45, 1.0, 0.95),
		"desc": "Reliable. Preview shows one reflection."},
	{"id": "echo", "name": "Echo Pickaxe", "cost": 3, "color": Color(0.6, 1.0, 0.45),
		"desc": "The preview shows two reflections."},
	{"id": "drill", "name": "Drill Pickaxe", "cost": 5, "color": Color(1.0, 0.65, 0.25),
		"desc": "The wave pierces boulders and debris. +2 charges."},
	{"id": "storm", "name": "Storm Pickaxe", "cost": 8, "color": Color(0.8, 0.5, 1.0),
		"desc": "Fast wave. Double damage to the worm."},
]


static func get_info(id: String) -> Dictionary:
	for p in LIST:
		if p.id == id:
			return p
	return LIST[0]


static func equipped() -> Dictionary:
	return get_info(Save.equipped)


static func has(effect: String) -> bool:
	return Save.equipped == effect
