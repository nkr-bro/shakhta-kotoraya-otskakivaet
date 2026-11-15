extends LevelBase
## Chapter 2 — the mechanic behind the rubble. Stage 1: bounce off the lower
## crystal into the crack of the wall. Stage 2: a second crystal appears;
## send the wave into the lift's power socket.

@onready var crystal_a: Reflector = $CrystalA
@onready var crystal_b: Reflector = $CrystalB
@onready var weak: WaveTarget = $WeakPoint
@onready var socket: WaveTarget = $PowerSocket
@onready var wall: BreakableWall = $Wall
@onready var mechanic: Npc = $Mechanic
@onready var pulley: Sprite2D = $Pulley

var stage := 1
var power := 0.0
var cable: Node2D


func setup_level() -> void:
	lanterns = [Vector2(240,150),Vector2(1347,195)]
	crystal_glows = [Vector2(530,40),Vector2(520,345),Vector2(205,750),Vector2(995,790),Vector2(1540,870),Vector2(1600,40)]
	miner = $Miner
	reflectors = [crystal_a, crystal_b]
	crystal_b.set_enabled(false)
	default_aim = (crystal_a.global_position - miner.strike_origin()).normalized()
	cable = Node2D.new()
	cable.z_index = 4
	cable.draw.connect(_draw_cable)
	add_child(cable)


func begin() -> void:
	set_objective("")
	await wait(0.4)
	Sfx.play("knocks")
	await wait(1.6)
	await say([
		["Голос за стеной", "Эй! Кто там? Я механик, меня завалило!"],
		["Шахтёр", "Держись! Кристалл внизу на вагонетке — поймаю момент и отражу волну в завал."],
	])
	set_objective("Кристалл едет на вагонетке! Поймай момент и отрази волну в трещину завала")
	charges = 6 + (2 if Pickaxes.has("drill") else 0)
	score_changed.emit(score, gems_got, gems_total)
	input_enabled = true


func on_target_hit(t: Node) -> void:
	if t == weak and stage == 1:
		await _break_wall()
	elif t == socket and stage == 2:
		await _power_on()


func _break_wall() -> void:
	input_enabled = false
	stage = 0
	weak.set_active(false)
	set_objective("")
	miner.cheer()
	wall.break_apart(weak.global_position)
	await wall.broken
	await say([
		["Механик", "Свобода! Спасибо, парень. Твой брат с остальными — на дне шахты, у большого подъёмника."],
		["Механик", "Эту клеть я подлатаю, но лебёдке нужен ток. Подожди-ка..."],
	])
	var chunk := FallingRock.new()
	chunk.radius = 34.0
	chunk.floor_y = 672.0
	chunk.life = 1.0e9
	chunk.position = Vector2(1205, 470)
	add_child(chunk)
	await wait(1.2)
	await mechanic.walk_to(1475.0, 110.0)
	mechanic.face(1)
	mechanic.mode = "work"
	Sfx.play("machine", -10.0)
	await wait(1.0)
	crystal_b.set_enabled(true)
	crystal_b.modulate.a = 0.0
	create_tween().tween_property(crystal_b, "modulate:a", 1.0, 0.6)
	Sfx.play("select")
	await say([
		["Механик", "Поставил тебе кристалл на нижний уступ. Щиток питания — под настилом, на опоре."],
		["Механик", "Только глыба от завала застряла под уступом. Прямо волна не пройдёт — веди её через оба кристалла!"],
	])
	socket.set_active(true)
	charges = maxi(charges, 0) + 5
	score_changed.emit(score, gems_got, gems_total)
	stage = 2
	set_objective("Дай питание: проведи волну через оба кристалла в щиток на опоре")
	input_enabled = true


func _power_on() -> void:
	input_enabled = false
	stage = 3
	socket.set_active(false)
	set_objective("")
	miner.cheer()
	Sfx.play("machine")
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "power", 1.0, 0.8)
	tw.tween_property(pulley, "rotation", TAU * 3.0, 3.0).set_trans(Tween.TRANS_SINE)
	mechanic.mode = "cheer"
	await wait(2.4)
	await say([
		["Механик", "Есть ток! Лебёдка крутится!"],
		["Механик", "Подожди! Над пропастью руна-маяк. Зажги её — и лебёдка выдержит спуск."],
	])
	charges = maxi(charges, 0) + 4
	score_changed.emit(score, gems_got, gems_total)
	await move_miner(Vector2(90, 428), "Шахтёр отошёл к краю уступа — угол удара другой")
	await run_challenge(Vector2(931, 391), "Задание 3: с нового места зажги руну над пропастью — вагонетка всё ещё едет!")
	await say([["Механик", "Спускаемся к подъёмнику. Слышишь? Это червь. Он не даст им уйти..."]])
	completed.emit()


func reset_puzzle() -> void:
	super.reset_puzzle()


func _process(delta: float) -> void:
	super._process(delta)
	if power > 0.0:
		cable.queue_redraw()


func _draw_cable() -> void:
	if power <= 0.0:
		return
	var pts := PackedVector2Array([Vector2(1440, 594), Vector2(1488, 560), Vector2(1490, 450), Vector2(1600, 430), Vector2(1610, 120), Vector2(1540, 102)])
	var k := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 90.0)
	cable.draw_polyline(pts, Color(0.4, 1.0, 0.95, 0.35 * power), 9.0)
	cable.draw_polyline(pts, Color(0.75, 1.0, 1.0, 0.9 * power * k), 3.0)
