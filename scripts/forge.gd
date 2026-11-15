class_name Forge
## Forge panel: spend gems to craft pickaxes and choose the one to carry.

static func build(on_close: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel(0.95))
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(820, 0)
	p.add_child(v)
	_fill(v, root, on_close)
	return root


static func _fill(v: VBoxContainer, root: Control, on_close: Callable) -> void:
	for c in v.get_children():
		c.queue_free()
	var t := UiStyle.label("Кузница", 40, Color(1.0, 0.8, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var w := UiStyle.label("Самоцветов в кошельке: %d   (собирай их рикошетами на уровнях)" % Save.wallet, 22, Color(0.6, 1.0, 0.9))
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(w)
	for pick in Pickaxes.LIST:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var sw := ColorRect.new()
		sw.color = pick.color
		sw.custom_minimum_size = Vector2(26, 26)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var info := UiStyle.label("%s — %s" % [pick.name, pick.desc], 20)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		var b := UiStyle.button(Button.new(), 20, Save.equipped == pick.id)
		if Save.equipped == pick.id:
			b.text = "В руках"
			b.disabled = true
		elif Save.owned.has(pick.id):
			b.text = "Взять"
			b.pressed.connect(func():
				Save.equipped = pick.id
				Save.save_data()
				Sfx.play("select")
				_fill(v, root, on_close))
		else:
			b.text = "Выковать (%d)" % pick.cost
			b.disabled = Save.wallet < pick.cost
			b.pressed.connect(func():
				if Save.wallet >= pick.cost:
					Save.wallet -= pick.cost
					Save.owned.append(pick.id)
					Save.equipped = pick.id
					Save.save_data()
					Sfx.play("strike")
					_fill(v, root, on_close))
		b.custom_minimum_size = Vector2(190, 0)
		row.add_child(b)
		v.add_child(row)
	var close := UiStyle.button(Button.new(), 24, true)
	close.text = "Готово"
	close.pressed.connect(func():
		root.queue_free()
		on_close.call())
	v.add_child(close)
