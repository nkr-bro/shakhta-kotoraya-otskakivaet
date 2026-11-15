extends Node
## Chapter flow: chapter card -> level -> story -> next chapter -> ending.

const PAR := [2, 3, 6]   # shots for three stars
const LEVELS := ["res://scenes/Level01.tscn", "res://scenes/Level02.tscn", "res://scenes/Level03.tscn"]
const CARDS := [
	["res://assets/art/reference1.png", "Chapter 1. Mine Entrance", "Miners dug up strange crystals and woke a stone worm. A cave-in cut them off from the exit."],
	["res://assets/art/reference3.png", "Chapter 2. Worker Behind the Rubble", "Down below, across the chasm, someone is knocking on a stone wall."],
	["res://assets/art/reference2.png", "Chapter 3. The Stone Worm", "Your brother and the workers wait at the lift. The worm won't let them leave."],
]

@onready var holder: Node2D = $LevelHolder
@onready var hud: Hud = $HUD

var level: LevelBase
var chapter := 0
var playing := false
var pause_on_focus_loss := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.strike_pressed.connect(func(): if level: level.fire())
	hud.reset_pressed.connect(func(): if level and not level.wave_active: level.reset_puzzle())
	hud.hint_pressed.connect(_on_hint)
	hud.pause_pressed.connect(func(): set_paused(true))
	hud.resume_pressed.connect(func(): set_paused(false))
	hud.menu_pressed.connect(go_menu)
	start_chapter(Save.next_chapter)


func start_chapter(i: int, with_card := true) -> void:
	chapter = clampi(i, 0, LEVELS.size() - 1)
	playing = false
	hud.set_play_ui(false)
	hud.set_hp("")
	hud.hide_overlay()
	if level:
		level.queue_free()
		level = null
	if with_card:
		hud.fade.color.a = 0.0
		await hud.chapter_card(load(CARDS[chapter][0]), CARDS[chapter][1], CARDS[chapter][2])
	level = load(LEVELS[chapter]).instantiate()
	level.game = self
	holder.add_child(level)
	level.objective_changed.connect(hud.set_goal)
	level.fails_changed.connect(func(n): hud.btn_hint.disabled = n < LevelBase.HINT_AFTER; if n == LevelBase.HINT_AFTER: toast("Hint available: it shows more of the trajectory"))
	level.completed.connect(_on_level_completed)
	level.score_changed.connect(hud.set_score)
	level.streak_changed.connect(hud.set_streak)
	hud.set_streak(0)
	hud.set_score(0, 0, level.gems_total)
	hud.btn_hint.disabled = true
	hud.btn_hint.text = "Hint"
	await hud.fade_to(0.0, 0.6)
	playing = true
	hud.set_play_ui(true)
	level.begin()


func restart_level() -> void:
	set_paused(false)
	Sfx.stop_music()
	await hud.fade_to(1.0, 0.3)
	start_chapter(chapter, false)


func _on_hint() -> void:
	if level:
		level.toggle_hint()
		hud.btn_hint.text = "Hint: on" if level.hint_on else "Hint"


func rating_for(shots: int) -> int:
	if shots <= PAR[chapter]:
		return 3
	if shots <= PAR[chapter] * 2:
		return 2
	return 1


func _on_level_completed() -> void:
	var shots := level.shots
	var rating := rating_for(shots)
	var was_best: int = Save.stars[chapter]
	Save.complete_chapter(chapter, rating)
	playing = false
	hud.set_play_ui(false)
	Sfx.play("victory", -4.0)
	var star_txt := "Stars: %d of 3   Score: %d   Gems: %d/%d" % [rating, level.score + rating * 500, level.gems_got, level.gems_total]
	Save.record(chapter, level.score + rating * 500, level.gems_got)
	var best := "  New record!" if rating > was_best and was_best > 0 else ""
	var res_done := [false]
	hud.show_overlay("Chapter %d complete" % (chapter + 1), "%s\nStrikes: %d (3 stars at %d or fewer)%s" % [star_txt, shots, PAR[chapter], best], [
		{"text": "Next", "accent": true, "cb": func(): res_done[0] = true},
		{"text": "Forge (gems: %d)" % Save.wallet, "cb": func(): hud.root.add_child(Forge.build(func(): pass))},
		{"text": "Replay chapter", "cb": func(): res_done[0] = true; hud.hide_overlay(); restart_level()},
	])
	while not res_done[0]:
		await get_tree().process_frame
	if not hud.overlay.visible:
		return
	hud.hide_overlay()
	await hud.fade_to(1.0, 0.8)
	if chapter + 1 < LEVELS.size():
		start_chapter(chapter + 1)
	else:
		show_ending()


func show_ending() -> void:
	if level:
		level.queue_free()
		level = null
	var end := preload("res://scenes/Ending.tscn").instantiate()
	holder.add_child(end)
	await hud.fade_to(0.0, 0.8)
	Sfx.play("victory")
	await say([
		["Brother", "We're on the surface. Everyone's alive — all thanks to you."],
		["Mechanic", "The lift held. And the worm will be licking its shell for a long time."],
		["Miner", "Three knocks — and we're home."],
	])
	hud.show_overlay("The End", "The miners made it to the surface.", [
		{"text": "New game", "accent": true, "cb": func(): hud.hide_overlay(); end.queue_free(); hud.fade.color.a = 1.0; start_chapter(0)},
		{"text": "Main menu", "cb": go_menu},
	])


func say(lines: Array) -> void:
	var prev := false
	if level:
		prev = level.input_enabled
		level.input_enabled = false
	hud.set_play_ui(false)
	await hud.dialogue(lines)
	if playing:
		hud.set_play_ui(true)
	if level and is_instance_valid(level):
		level.input_enabled = prev


var _shake := 0.0
var _shake_t := 0.0


func shake(strength: float, dur: float) -> void:
	_shake = maxf(_shake, strength)
	_shake_t = maxf(_shake_t, dur)


func _process(delta: float) -> void:
	if _shake_t > 0.0 and not get_tree().paused:
		_shake_t -= delta
		var k := _shake * clampf(_shake_t / 0.4, 0.0, 1.0)
		holder.position = Vector2(randf_range(-k, k), randf_range(-k, k))
		if _shake_t <= 0.0:
			_shake = 0.0
			holder.position = Vector2.ZERO


func toast(t: String, dur := 2.4) -> void:
	hud.toast(t, dur)


func flash_miss() -> void:
	hud.flash_miss()


func out_of_charges() -> void:
	hud.show_overlay("Pickaxe drained", "Out of charges. Gems give +1 strike — collect them with ricochets.", [
		{"text": "Try again", "accent": true, "cb": func(): hud.hide_overlay(); restart_level()},
		{"text": "Main menu", "cb": go_menu},
	])


## Short freeze-frame for impactful hits.
func hit_stop(dur := 0.09) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0


func set_paused(on: bool) -> void:
	if on and not playing:
		return
	get_tree().paused = on
	hud.show_pause(on)


func go_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Sfx.stop_music()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if hud.overlay.visible:
			return
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and playing and not get_tree().paused:
		set_paused(true)
