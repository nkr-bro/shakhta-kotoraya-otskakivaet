class_name Hud
extends CanvasLayer
## In-game interface: goal, action buttons, dialogue, toasts, pause, overlays.
## Every panel stops mouse input, so clicks on UI never re-aim in the world.

signal strike_pressed
signal reset_pressed
signal hint_pressed
signal pause_pressed
signal resume_pressed
signal menu_pressed
signal retry_pressed
signal _advance

var root: Control
var goal_panel: PanelContainer
var goal_label: Label
var hp_label: Label
var btn_strike: Button
var btn_reset: Button
var btn_hint: Button
var btn_pause: Button
var actions: HBoxContainer
var dlg: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_catcher: Control
var toast_label: Label
var fade: ColorRect
var pause_panel: Control
var overlay: Control
var overlay_box: VBoxContainer
var card: Control
var card_tex: TextureRect
var card_title: Label
var card_sub: Label
var miss_flash: ColorRect
var score_label: Label
var streak_label: Label
var timer_label: Label
var btn_full: Button
var _shown_score := 0.0
var _target_score := 0
var _score_suffix := ""

var _typing := false
var _skip := false
var _in_dialogue := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	miss_flash = ColorRect.new()
	miss_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	miss_flash.color = Color(0.7, 0.2, 0.25, 0.0)
	miss_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(miss_flash)

	goal_panel = PanelContainer.new()
	goal_panel.add_theme_stylebox_override("panel", UiStyle.panel(0.72))
	goal_panel.position = Vector2(16, 14)
	goal_label = UiStyle.label("", 23, Color(1.0, 0.9, 0.62))
	goal_panel.add_child(goal_label)
	goal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	goal_panel.visible = false
	root.add_child(goal_panel)

	hp_label = UiStyle.label("", 24, Color(0.75, 1.0, 0.95))
	hp_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hp_label.position = Vector2(-150, 16)
	hp_label.size = Vector2(560, 40)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label.visible = false
	root.add_child(hp_label)

	score_label = UiStyle.label("", 22, Color(1.0, 0.9, 0.55))
	score_label.position = Vector2(20, 70)
	score_label.visible = false
	root.add_child(score_label)

	streak_label = UiStyle.label("", 40, Color(1.0, 0.6, 0.25))
	streak_label.position = Vector2(20, 104)
	streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(streak_label)
	timer_label = UiStyle.label("", 20, Color(0.8, 0.9, 1.0))
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(timer_label)
	btn_full = UiStyle.button(Button.new(), 20)
	btn_full.text = "На весь экран (F)"
	btn_full.pressed.connect(toggle_fullscreen)
	root.add_child(btn_full)

	btn_pause = UiStyle.button(Button.new(), 22)
	btn_pause.text = "Пауза"
	btn_pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_pause.position = Vector2(-120, 14)
	btn_pause.pressed.connect(func(): pause_pressed.emit())
	btn_pause.visible = false
	root.add_child(btn_pause)

	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	actions.position = Vector2(-16, -16)
	btn_hint = UiStyle.button(Button.new(), 22)
	btn_hint.text = "Подсказка"
	btn_hint.disabled = true
	btn_hint.tooltip_text = "Станет доступна после четырёх промахов"
	btn_hint.pressed.connect(func(): hint_pressed.emit())
	btn_reset = UiStyle.button(Button.new(), 22)
	btn_reset.text = "Сброс (R)"
	btn_reset.pressed.connect(func(): reset_pressed.emit())
	btn_strike = UiStyle.button(Button.new(), 30, true)
	btn_strike.text = "Удар (пробел)"
	btn_strike.pressed.connect(func(): strike_pressed.emit())
	actions.add_child(btn_hint)
	actions.add_child(btn_reset)
	actions.add_child(btn_strike)
	actions.visible = false
	root.add_child(actions)
	actions.resized.connect(_place_actions)

	toast_label = UiStyle.label("", 28, Color(0.8, 1.0, 0.95))
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-640, 112)
	toast_label.size = Vector2(1280, 50)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	# Dialogue
	dlg_catcher = Control.new()
	dlg_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	dlg_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	dlg_catcher.visible = false
	dlg_catcher.gui_input.connect(_on_dialogue_input)
	root.add_child(dlg_catcher)
	dlg = PanelContainer.new()
	dlg.add_theme_stylebox_override("panel", UiStyle.panel(0.88))
	dlg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dlg.custom_minimum_size = Vector2(980, 0)
	dlg.position = Vector2(-490, -200)
	dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	dlg.gui_input.connect(_on_dialogue_input)
	var v := VBoxContainer.new()
	dlg_name = UiStyle.label("", 22, Color(1.0, 0.75, 0.35))
	dlg_text = UiStyle.label("", 26)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(940, 70)
	var row := HBoxContainer.new()
	var hint := UiStyle.label("Щелчок / пробел — дальше", 16, Color(0.7, 0.7, 0.7))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skip := UiStyle.button(Button.new(), 18)
	skip.text = "Пропустить"
	skip.pressed.connect(func(): _skip = true; _advance.emit())
	row.add_child(hint)
	row.add_child(skip)
	v.add_child(dlg_name)
	v.add_child(dlg_text)
	v.add_child(row)
	dlg.add_child(v)
	dlg.visible = false
	root.add_child(dlg)

	# Chapter card
	card = Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.visible = false
	var cbg := ColorRect.new()
	cbg.color = Color.BLACK
	cbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(cbg)
	card_tex = TextureRect.new()
	card_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_tex.modulate = Color(0.75, 0.75, 0.75)
	card.add_child(card_tex)
	var cpanel := PanelContainer.new()
	cpanel.add_theme_stylebox_override("panel", UiStyle.panel(0.8))
	cpanel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cpanel.position = Vector2(-420, -230)
	cpanel.custom_minimum_size = Vector2(840, 0)
	var cv := VBoxContainer.new()
	card_title = UiStyle.label("", 44, Color(1.0, 0.85, 0.5))
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_sub = UiStyle.label("", 24)
	card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_sub.custom_minimum_size = Vector2(800, 0)
	cv.add_child(card_title)
	cv.add_child(card_sub)
	cpanel.add_child(cv)
	card.add_child(cpanel)
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_advance.emit())
	root.add_child(card)

	# Pause
	pause_panel = _make_modal()
	var pv: VBoxContainer = pause_panel.get_meta("box")
	pv.add_child(_center(UiStyle.label("Пауза", 40, Color(1.0, 0.85, 0.5))))
	var b1 := UiStyle.button(Button.new(), 26, true)
	b1.text = "Продолжить"
	b1.pressed.connect(func(): resume_pressed.emit())
	pv.add_child(b1)
	pv.add_child(_volume_row())
	var help := UiStyle.label("Мышь: щелчок по кристаллу — выбрать, тянуть ручку — повернуть,\nколесо или Q/E — точно, Tab — следующий кристалл.\nЩелчок по сцене — направление удара. Пробел — удар, R — сброс.", 18, Color(0.8, 0.8, 0.8))
	pv.add_child(help)
	var b2 := UiStyle.button(Button.new(), 22)
	b2.text = "В главное меню"
	b2.pressed.connect(func(): menu_pressed.emit())
	pv.add_child(b2)
	root.add_child(pause_panel)

	overlay = _make_modal()
	overlay_box = overlay.get_meta("box")
	root.add_child(overlay)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)


func _place_actions() -> void:
	actions.position = Vector2(-16, -16) - actions.size + Vector2(0, 0)
	actions.position = root.size - actions.size - Vector2(16, 16)


func _process(_d: float) -> void:
	if actions.visible:
		actions.position = root.size - actions.size - Vector2(16, 16)
	btn_pause.position = Vector2(root.size.x - btn_pause.size.x - 16, 14)
	btn_full.position = Vector2(btn_pause.position.x - btn_full.size.x - 10, 14)
	btn_full.visible = btn_pause.visible
	var lv = get_parent().level if get_parent() and "level" in get_parent() else null
	if lv and is_instance_valid(lv) and lv.input_enabled:
		timer_label.text = "Время задания: %d с%s" % [int(lv.task_time), "  (бонус за скорость!)" if lv.task_time < 30.0 else ""]
		timer_label.position = Vector2(20, root.size.y - 40)
		timer_label.visible = true
	else:
		timer_label.visible = false
	if absf(_shown_score - _target_score) > 0.5:
		_shown_score = move_toward(_shown_score, _target_score, maxf(8.0, absf(_target_score - _shown_score) * 0.12))
		score_label.text = "Очки: %d%s" % [int(_shown_score), _score_suffix]
	hp_label.position = Vector2(root.size.x - hp_label.size.x - 16, 66)
	dlg.position = Vector2((root.size.x - dlg.size.x) * 0.5, root.size.y - dlg.size.y - 24)


func _make_modal() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel(0.95))
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(560, 0)
	p.add_child(v)
	c.set_meta("box", v)
	return c


func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _volume_row() -> Control:
	return UiStyle.volume_row()


# ------------------------------------------------------------------ API
func set_play_ui(on: bool) -> void:
	goal_panel.visible = on
	score_label.visible = on and score_label.text != ""
	actions.visible = on
	btn_pause.visible = on


var charges_text := ""


func set_score(score: int, got: int, total: int) -> void:
	var lv = get_parent().level if get_parent() and "level" in get_parent() else null
	var ch := ""
	if lv and lv.charges >= 0:
		ch = "   Заряды кирки: %d" % lv.charges
	_target_score = score
	_score_suffix = "   Самоцветы: %d/%d%s" % [got, total, ch]
	score_label.text = "Очки: %d%s" % [int(_shown_score), _score_suffix]
	score_label.visible = true


## Floating text in world coordinates (the world view is 1:1 with the viewport).
func popup(text: String, world_pos: Vector2) -> void:
	var l := UiStyle.label(text, 30, Color(1.0, 0.95, 0.5))
	l.position = world_pos - Vector2(120, 40)
	l.size = Vector2(240, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.tween_callback(l.queue_free)


func set_streak(n: int) -> void:
	if n >= 2:
		streak_label.text = "СЕРИЯ ×%d" % (n + 1)
		streak_label.pivot_offset = Vector2(90, 24)
		var tw := create_tween()
		streak_label.scale = Vector2(1.6, 1.6)
		tw.tween_property(streak_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	else:
		streak_label.text = ""


func toggle_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func set_goal(t: String) -> void:
	var changed := t != goal_label.text
	goal_label.text = t
	goal_panel.visible = t != ""
	if changed and t != "":
		goal_panel.position.x = -goal_panel.size.x
		var tw := create_tween()
		tw.tween_property(goal_panel, "position:x", 16.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("select", -10.0, 0.8)


func set_hp(t: String) -> void:
	hp_label.text = t
	hp_label.visible = t != ""


func toast(t: String, dur := 2.4) -> void:
	toast_label.text = t
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	tw.tween_interval(dur)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func flash_hit() -> void:
	var tw := create_tween()
	miss_flash.color = Color(0.85, 1.0, 1.0, 0.35)
	tw.tween_property(miss_flash, "color:a", 0.0, 0.4)


func flash_miss() -> void:
	miss_flash.color = Color(0.7, 0.2, 0.25, 0.0)
	var tw := create_tween()
	miss_flash.color.a = 0.16
	tw.tween_property(miss_flash, "color:a", 0.0, 0.35)


func is_dialogue_open() -> bool:
	return _in_dialogue


func dialogue(lines: Array) -> void:
	_in_dialogue = true
	_skip = false
	dlg.visible = true
	dlg_catcher.visible = true
	for line in lines:
		if _skip:
			break
		dlg_name.text = str(line[0])
		dlg_text.text = str(line[1])
		dlg_text.visible_ratio = 0.0
		_typing = true
		var tw := create_tween()
		tw.tween_property(dlg_text, "visible_ratio", 1.0, maxf(0.25, dlg_text.text.length() * 0.022))
		tw.finished.connect(func(): _typing = false)
		await _advance
		if _typing:
			tw.kill()
			dlg_text.visible_ratio = 1.0
			_typing = false
			if not _skip:
				await _advance
	dlg.visible = false
	dlg_catcher.visible = false
	_in_dialogue = false


func _on_dialogue_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_advance.emit()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.pressed and not e.echo and e.physical_keycode == KEY_F:
		toggle_fullscreen()
	if (_in_dialogue or card.visible) and e.pressed and not e.echo and (e.physical_keycode == KEY_SPACE or e.physical_keycode == KEY_ENTER):
		_advance.emit()
		get_viewport().set_input_as_handled()


func chapter_card(tex: Texture2D, title: String, sub: String, hold := 3.5) -> void:
	card_tex.texture = tex
	card_title.text = title
	card_sub.text = sub
	card.modulate.a = 0.0
	card.visible = true
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.5)
	var timer := get_tree().create_timer(hold)
	timer.timeout.connect(func(): _advance.emit())
	await _advance
	var tw2 := create_tween()
	tw2.tween_property(card, "modulate:a", 0.0, 0.5)
	await tw2.finished
	card.visible = false


func fade_to(a: float, t := 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, t)
	await tw.finished


func show_pause(on: bool) -> void:
	pause_panel.visible = on


func show_overlay(title: String, text: String, buttons: Array) -> void:
	for c in overlay_box.get_children():
		c.queue_free()
	overlay_box.add_child(_center(UiStyle.label(title, 38, Color(1.0, 0.85, 0.5))))
	var l := _center(UiStyle.label(text, 24))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	overlay_box.add_child(l)
	for b in buttons:
		var btn := UiStyle.button(Button.new(), 26, b.get("accent", false))
		btn.text = b.text
		btn.pressed.connect(b.cb)
		overlay_box.add_child(btn)
	overlay.visible = true


func hide_overlay() -> void:
	overlay.visible = false
