class_name Pickaxes
## Craftable pickaxes. Each changes how the wave behaves.

const LIST := [
	{"id": "standard", "name": "Обычная кирка", "cost": 0, "color": Color(0.45, 1.0, 0.95),
		"desc": "Надёжная. Предпросмотр — одно отражение."},
	{"id": "echo", "name": "Кирка-эхо", "cost": 3, "color": Color(0.6, 1.0, 0.45),
		"desc": "Предпросмотр показывает два отражения."},
	{"id": "drill", "name": "Кирка-бур", "cost": 5, "color": Color(1.0, 0.65, 0.25),
		"desc": "Волна пробивает валуны и обломки. +2 заряда."},
	{"id": "storm", "name": "Кирка бури", "cost": 8, "color": Color(0.8, 0.5, 1.0),
		"desc": "Быстрая волна. Двойной урон по червю."},
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
