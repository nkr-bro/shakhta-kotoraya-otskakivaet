extends LevelBase
## Chapter 1 — mine entrance. Tutorial: one crystal on a signal pole above
## the fissure; the wave must drop through the fissure onto the jammed latch.

@onready var crystal: Reflector = $CrystalA
@onready var latch: WaveTarget = $Latch
@onready var clamp_sprite: Sprite2D = $Clamp
@onready var gear: Sprite2D = $Gear
@onready var cabin: Sprite2D = $Cabin

var chain_extra := 0.0
var chains: Node2D
var _aimed := false


func setup_level() -> void:
	lanterns = [Vector2(322,155),Vector2(163,430),Vector2(685,400),Vector2(1185,370),Vector2(960,605),Vector2(450,630),Vector2(800,600),Vector2(877,600)]
	crystal_glows = [Vector2(445,450),Vector2(240,700),Vector2(985,650),Vector2(1110,545),Vector2(1630,530),Vector2(1560,790),Vector2(115,790)]
	miner = $Miner
	reflectors = [crystal]
	default_aim = (crystal.global_position - miner.strike_origin()).normalized()
	chains = Node2D.new()
	chains.z_index = 1
	chains.draw.connect(_draw_chains)
	add_child(chains)
	aim_set.connect(func(): _aimed = true)


func begin() -> void:
	set_objective("")
	await wait(0.5)
	Sfx.play("knocks")
	await wait(1.2)
	await say([
		["Брат (стук из-под земли)", "Мы живы. Слышишь три удара — помоги нам выбраться."],
		["Шахтёр", "Кирка задела кристалл — и пошла волна! Отражу её в фиксатор подъёмника."],
	])
	input_enabled = true
	_tutorial()


func _tutorial() -> void:
	set_objective("1. Выбери кристалл — щёлкни по нему")
	await reflector_selected
	set_objective("2. Поверни отражатель — тяни за ручку, колесо мыши или Q/E")
	await reflector_turned
	await wait(1.2)
	set_objective("3. Направь волну в фиксатор: пунктир должен уйти в трещину к красному фиксатору")
	var t := 0.0
	while t < 4.0 and not _aimed and input_enabled:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		t += get_process_delta_time()
	if latch.active:
		set_objective("4. Нажми «Удар» (или пробел). Промах не страшен — поправь угол и бей снова")


func on_target_hit(t: Node) -> void:
	if t != latch:
		return
	input_enabled = false
	latch.set_active(false)
	set_objective("")
	miner.cheer()
	toast("Фиксатор сбит!")
	var tw := create_tween().set_parallel()
	tw.tween_property(clamp_sprite, "position", clamp_sprite.position + Vector2(30, 260), 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(clamp_sprite, "rotation", 3.5, 0.9)
	tw.tween_property(clamp_sprite, "modulate:a", 0.0, 0.9)
	await wait(0.6)
	Sfx.play("machine")
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(gear, "rotation", TAU * 2.5, 3.0).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(cabin, "position:y", cabin.position.y + 230.0, 3.0).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(self, "chain_extra", 230.0, 3.0).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	Sfx.play("knocks")
	await wait(1.6)
	await say([
		["Шахтёр", "Подъёмник пошёл вниз! Путь в нижнюю часть шахты открыт."],
		["Брат (стук снизу)", "Три удара... Ниже нас за завалом остался механик. Без него подъёмник не починить."],
	])
	await move_miner(Vector2(900, 273), "Шахтёр перепрыгнул на правый уступ — теперь бей отсюда")
	await run_challenge(Vector2(705, 420), "Задание 2: с правого уступа зажги руну в полости под трещиной — рикошетом от кристалла")
	completed.emit()


func _process(delta: float) -> void:
	super._process(delta)
	if chain_extra > 0.0:
		chains.queue_redraw()


func _draw_chains() -> void:
	if chain_extra <= 0.0:
		return
	for x in [823.0, 846.0]:
		var y := 536.0
		while y < 536.0 + chain_extra:
			chains.draw_rect(Rect2(x - 2, y, 4, 6), Color(0.62, 0.38, 0.18))
			chains.draw_rect(Rect2(x - 2, y + 6, 4, 2), Color(0.25, 0.14, 0.08))
			y += 8.0
