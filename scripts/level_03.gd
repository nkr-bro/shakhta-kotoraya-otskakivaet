extends LevelBase
## Chapter 3 — the stone worm. Three phases. The worm attacks in a rhythm:
## after every attack it is winded and one crack opens for a few seconds.
## Attacks: blasts at the lift (deflect with the small crystal), rockfall
## (boulders become temporary obstacles), and a double blast in phase 3.

@onready var worm: StoneWorm = $Worm
@onready var elevator: Elevator = $Elevator
@onready var crystal_a: Reflector = $CrystalA
@onready var crystal_b: Reflector = $CrystalB
@onready var npcs: Array = [$Brother, $Worker1, $Worker2]

const PHASE_GOALS := [
	"",
	"Фаза 1/3. После атаки червь выдыхается — бей рикошетом в трещину под аркой тела (3 удара)",
	"Фаза 2/3. Трещина под челюстью. Червь гасит фонари и сбивает кристалл (3 удара)",
	"Фаза 3/3. Червь в ярости! Трещина у основания шеи, двойные залпы (3 удара)",
]
const ATTACKS := [[], ["blast", "rocks", "spin"], ["blast", "dark", "rocks", "spin"], ["double", "spin", "rocks", "dark", "double"]]
var worm_hp := 9
var hits_in_phase := 0
var dark_layer: CanvasModulate
const EXPOSE_TIME := [0.0, 9.0, 8.0, 7.0]

var phase := 0
var fighting := false
var telegraphing := false
var tele_lines: Array = []
var tele: Node2D
var attacks := 0
var attack_interval := 0.0   # extra delay between cycles (used by tests)
var _phase_hit := false
var _cycle_running := false
## Places on the left side where the rockfall can throw the miner.
const MINER_SPOTS := [Vector2(190, 488), Vector2(250, 162)]
var spot := 0


func setup_level() -> void:
	lanterns = [Vector2(225,115),Vector2(125,270),Vector2(405,125),Vector2(493,430),Vector2(572,430),Vector2(372,590),Vector2(1617,170),Vector2(1645,580)]
	crystal_glows = [Vector2(60,450),Vector2(190,680),Vector2(340,300),Vector2(100,850),Vector2(740,540),Vector2(1260,880),Vector2(1640,430)]
	miner = $Miner
	reflectors = [crystal_a, crystal_b]
	default_aim = (crystal_a.global_position - miner.strike_origin()).normalized()
	tele = Node2D.new()
	tele.z_index = 45
	tele.draw.connect(_draw_tele)
	add_child(tele)
	elevator.damaged.connect(_on_damaged)
	elevator.destroyed.connect(_on_lost)


func begin() -> void:
	set_objective("")
	await worm.roar()
	game.shake(10.0, 0.6)
	await say([
		["Брат", "Брат! Ты пришёл! Червь обвился вокруг подъёмника — мы не можем сесть в клеть!"],
		["Шахтёр", "Его броню волна не пробьёт. Но после каждого рывка он выдыхается — и трещины раскрываются."],
		["Брат", "Щит подъёмника выдержит три удара. Поворачивай малый кристалл у клети, чтобы отбивать залпы!"],
	])
	elevator.set_shield(true)
	_update_hp()
	fighting = true
	Sfx.music("boss_music")
	_set_phase(1)
	input_enabled = true
	_fight_loop()


func _set_phase(p: int) -> void:
	phase = p
	worm.sway = [1.0, 1.0, 2.0, 3.0][p]
	# The crack is always aimable (preview shows a hit), but it only breaks
	# while the worm is winded after an attack.
	worm.activate_weak_point(p - 1)
	set_objective(PHASE_GOALS[p])
	_update_hp()


func _update_hp() -> void:
	game.hud.set_hp("Червь: %d/9   Щит подъёмника: %d/3" % [maxi(0, worm_hp), elevator.hp])


func _fight_loop() -> void:
	_cycle_running = true
	var first := true
	while fighting:
		await _attack(first)
		first = false
		if not fighting:
			break
		await _expose()
		if attack_interval > 0.0:
			await wait(attack_interval)
	_cycle_running = false


func _expose() -> void:
	_phase_hit = false
	worm.set_exposed(true)
	toast("Червь выдохся — трещина раскрыта! Бей!", 1.6)
	var t := 0.0
	var dur: float = EXPOSE_TIME[phase]
	while fighting and t < dur and not _phase_hit:
		if not is_inside_tree():
			return
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	# let a wave already in flight finish before the crack closes
	while fighting and wave_active and not _phase_hit:
		if not is_inside_tree():
			return
		await get_tree().physics_frame
	if fighting and not _phase_hit:
		worm.set_exposed(false)


func _attack(first: bool) -> void:
	if not fighting:
		return
	attacks += 1
	var list: Array = ATTACKS[phase]
	var kind: String = list[attacks % list.size()]
	if first:
		kind = "blast"
	match kind:
		"rocks":
			await _rockfall()
		"spin":
			await _spin_crystal()
		"dark":
			await _darkness()
		"double":
			await _blast([0, 1], 4.0)
		_:
			await _blast([0], 9.0 if first else maxf(3.0, 5.0 - phase * 0.6))


func _blast(origins: Array, dur: float) -> void:
	telegraphing = true
	Sfx.play("charge")
	if dur > 6.0:
		toast("Червь заряжает залп по подъёмнику! Поверни малый кристалл поперёк красной линии", 5.0)
	elif origins.size() > 1:
		toast("Двойной залп!", 1.6)
	var t := 0.0
	while t < dur and fighting:
		worm.charge = t / dur
		worm.charge2 = t / dur if origins.size() > 1 else 0.0
		if not is_inside_tree():
			return
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	if not fighting:
		_clear_tele()
		return
	await worm.lunge()
	worm.charge = 0.0
	worm.charge2 = 0.0
	var orbs := []
	for o in origins:
		var orb: EnergyWave = WAVE_SCENE.instantiate()
		orb.hostile = true
		orb.speed = 320.0 + phase * 40.0
		orb.max_bounces = 3
		orb.lifetime = 6.0
		orb.color = Color(1.0, 0.35, 0.8)
		add_child(orb)
		orb.launch(worm.attack_origin(o), _attack_dir(o))
		orbs.append(orb)
		Sfx.play("blast")
		if origins.size() > 1:
			await wait(0.9)
	_clear_tele()
	for orb in orbs:
		if is_instance_valid(orb) and orb.alive:
			var res: Array = await orb.finished
			if fighting and not (res[1] is Node and (res[1] as Node).is_in_group("shield")):
				toast("Залп отбит!", 1.2)


func _clear_tele() -> void:
	telegraphing = false
	tele_lines = []
	tele.queue_redraw()
	worm.charge = 0.0
	worm.charge2 = 0.0


func _rockfall() -> void:
	toast("Червь бьёт хвостом — обвал!", 1.6)
	await worm.slam()
	game.shake(14.0, 0.7)
	Sfx.play("crumble")
	var n := 2 + phase
	for i in n:
		var r := FallingRock.new()
		r.radius = randf_range(22.0, 32.0)
		r.position = Vector2(randf_range(620.0, 1080.0), -40.0 - i * 60.0)
		r.life = 7.0 + phase
		add_child(r)
	await _knock_miner()
	await wait(0.8)


## The quake throws the miner to another ledge: his strike point changes,
## so the shot has to be found again.
func _knock_miner() -> void:
	while wave_active:
		if not is_inside_tree():
			return
		await get_tree().physics_frame
	var choices := []
	for i in MINER_SPOTS.size():
		if i != spot:
			choices.append(i)
	spot = choices[randi() % choices.size()]
	drag_mode = ""
	var was := input_enabled
	input_enabled = false
	await miner.knocked_to(MINER_SPOTS[spot])
	aim_dir = (crystal_a.global_position - miner.strike_origin()).normalized()
	toast("Шахтёра отбросило обвалом! Найди новый угол удара", 2.4)
	input_enabled = was and fighting


## The worm lashes the big crystal and sends it spinning to a new angle.
func _spin_crystal() -> void:
	toast("Червь хлестнул хвостом — большой кристалл раскручен!", 2.0)
	await worm.lunge()
	game.shake(6.0, 0.3)
	Sfx.play("ricochet", 0.0, 0.6)
	var from := crystal_a.angle_deg
	var to := randf_range(crystal_a.min_angle, crystal_a.max_angle)
	var tw := create_tween()
	tw.tween_method(func(a: float): crystal_a.set_angle(wrapf(a, -90.0, 90.0), false), from, from + 540.0 + (to - from), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	crystal_a.set_angle(clampf(to, crystal_a.min_angle, crystal_a.max_angle), false)


## Roar puts out the lanterns: the aiming preview shrinks for a while.
func _darkness() -> void:
	await worm.roar()
	toast("Червь погасил фонари! Предпросмотр укоротился", 2.2)
	if dark_layer == null:
		dark_layer = CanvasModulate.new()
		dark_layer.color = Color(1, 1, 1)
		add_child(dark_layer)
	darkness = true
	var tw := create_tween()
	tw.tween_property(dark_layer, "color", Color(0.45, 0.45, 0.6), 0.6)
	get_tree().create_timer(16.0, false).timeout.connect(func():
		darkness = false
		if is_instance_valid(dark_layer):
			create_tween().tween_property(dark_layer, "color", Color(1, 1, 1), 1.0))


func _attack_dir(i := 0) -> Vector2:
	# aim at the right half of the shield so every blast line passes within reach of crystal B
	return (elevator.global_position + elevator.shield_rect.get_center() + Vector2(60, 0) - worm.attack_origin(i)).normalized()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if telegraphing:
		var space := get_world_2d().direct_space_state
		tele_lines = []
		var n := 2 if worm.charge2 > 0.0 else 1
		for i in n:
			var r := WaveTracer.trace(space, worm.attack_origin(i), _attack_dir(i), 2, WaveTracer.HOSTILE_MASK, 900.0)
			tele_lines.append(r.points)
		tele.queue_redraw()


func _draw_tele() -> void:
	var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 80.0)
	for pts in tele_lines:
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			var L := a.distance_to(b)
			var d := (b - a) / maxf(L, 0.001)
			var s := 0.0
			while s < L:
				tele.draw_line(a + d * s, a + d * minf(s + 14.0, L), Color(1.0, 0.3, 0.45, 0.5 + 0.4 * k), 3.0)
				s += 24.0


func on_target_hit(t: Node) -> void:
	if not fighting:
		return
	var idx := worm.weak_points.find(t)
	if idx != phase - 1:
		return
	if not worm.exposed:
		fails += 1
		fails_changed.emit(fails)
		Sfx.play("miss")
		toast("Прицел верный, но трещина закрыта — бей, когда червь выдохнется после атаки", 2.4)
		return
	_phase_hit = true
	worm.set_exposed(false)
	var dmg := 2 if Pickaxes.has("storm") else 1
	worm_hp -= dmg
	hits_in_phase += dmg
	worm.crack_level = mini(hits_in_phase, 3)
	worm.hurt()
	worm.shatter(t.global_position)
	game.shake(12.0, 0.5)
	miner.cheer()
	_update_hp()
	if worm_hp > 0 and hits_in_phase < 3:
		toast("Трещина расширяется! Ещё %d" % (3 - hits_in_phase), 1.8)
		Sfx.play("roar", -6.0, 1.3)
		return
	hits_in_phase = 0
	worm.crack_level = 0
	worm.activate_weak_point(-1)
	if worm_hp > 0 and phase < 3:
		input_enabled = false
		await worm.roar()
		if phase == 1:
			await worm.move_to_pose(Vector2(-30, -60), -10.0)
			await say([["Брат", "Есть! Панцирь треснул! Он поднимает голову — целься ниже челюсти!"]])
		else:
			await worm.move_to_pose(Vector2(-60, -20), 6.0)
			await say([["Шахтёр", "Он в ярости! Ещё одна трещина — и он уйдёт под землю!"]])
		_set_phase(phase + 1)
		input_enabled = true
	else:
		await _victory()


func _on_damaged(hp: int) -> void:
	_update_hp()
	game.shake(8.0, 0.4)
	if hp > 0:
		toast("Щит подъёмника повреждён!")


func _on_lost() -> void:
	if not fighting:
		return
	fighting = false
	Sfx.stop_music()
	input_enabled = false
	_clear_tele()
	set_objective("")
	game.hud.show_overlay("Щит разрушен", "Червь пробил защиту подъёмника. Попробуй ещё раз: поворачивай малый кристалл поперёк красной линии атаки.", [
		{"text": "Начать бой заново", "accent": true, "cb": func(): game.hud.hide_overlay(); game.restart_level()},
		{"text": "В главное меню", "cb": game.go_menu},
	])


func _victory() -> void:
	fighting = false
	darkness = false
	if is_instance_valid(dark_layer):
		dark_layer.color = Color(1, 1, 1)
	Sfx.stop_music()
	_clear_tele()
	input_enabled = false
	set_objective("")
	game.hud.set_hp("")
	for c in get_children():
		if c is FallingRock:
			c.life = minf(c.life, 0.8)
	await worm.roar()
	game.shake(18.0, 1.6)
	await worm.defeat()
	Sfx.play("victory")
	elevator.set_shield(false)
	await say([
		["Брат", "Он уходит под землю! Все в клеть, быстро!"],
	])
	Sfx.play("machine")
	var tw := create_tween()
	tw.tween_property(elevator, "position:y", elevator.position.y + 166.0, 1.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	for i in npcs.size():
		npcs[i].walk_to(1215.0 + i * 52.0, 120.0)
	await wait(2.6)
	for n in npcs:
		n.face(1)
		n.z_index = 3
	Sfx.play("machine")
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(elevator, "position:y", -300.0, 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for n in npcs:
		tw2.tween_property(n, "position:y", n.position.y - 902.0, 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw2.finished
	await say([
		["Шахтёр", "Подъёмник наверху. Теперь моя очередь — по лестнице к свету."],
	])
	completed.emit()
