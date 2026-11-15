class_name UiStyle
## Shared look for buttons and panels (dark wood/brass, readable Cyrillic).

static func panel(alpha := 0.82) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.06, 0.09, alpha)
	s.border_color = Color(0.85, 0.62, 0.28, 0.9)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func button(b: Button, size := 24, accent := false) -> Button:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.11, 0.08, 0.92) if not accent else Color(0.05, 0.32, 0.33, 0.95)
	normal.border_color = Color(0.9, 0.66, 0.3) if not accent else Color(0.5, 1.0, 0.95)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.18)
	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.3)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.12, 0.12, 0.12, 0.7)
	disabled.border_color = Color(0.4, 0.4, 0.4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func label(text: String, size := 24, color := Color(1.0, 0.95, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func volume_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var mute := UiStyle.button(Button.new(), 20)
	mute.toggle_mode = true
	mute.button_pressed = not Save.muted
	mute.text = "Sound: on" if not Save.muted else "Sound: off"
	mute.toggled.connect(func(on):
		Save.muted = not on
		mute.text = "Sound: on" if on else "Sound: off"
		Sfx.apply_settings()
		Save.save_data())
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Save.volume
	s.custom_minimum_size = Vector2(260, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v):
		Save.volume = v
		Sfx.apply_settings())
	s.drag_ended.connect(func(_c): Save.save_data())
	h.add_child(mute)
	h.add_child(UiStyle.label("Volume", 20))
	h.add_child(s)
	return h
