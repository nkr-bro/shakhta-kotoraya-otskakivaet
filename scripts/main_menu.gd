extends Control
## Title screen: animated art, start / continue, chapter select with stars,
## sound settings.

var bg: TextureRect
var title: Label
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg = TextureRect.new()
	bg.texture = load("res://assets/art/reference2.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.pivot_offset = Vector2(836, 470)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var dust := Ambience.new()
	dust.crystal_glows = [Vector2(700, 760), Vector2(150, 820), Vector2(1600, 470), Vector2(1280, 880)]
	add_child(dust)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(760, 0)
	center.add_child(v)
	title = UiStyle.label("BOUNCING MINE", 64, Color(1.0, 0.82, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 14)
	title.pivot_offset = Vector2(380, 40)
	v.add_child(title)
	var sub := UiStyle.label("One pickaxe strike. Three ricochets. A whole mine to save.", 24, Color(0.7, 1.0, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel(0.85))
	v.add_child(p)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	p.add_child(pv)
	var start := UiStyle.button(Button.new(), 32, true)
	start.text = "New game"
	start.pressed.connect(func(): _go(0))
	pv.add_child(start)
	if Save.progress > 0 and Save.progress < 3:
		var cont := UiStyle.button(Button.new(), 28)
		cont.text = "Continue (chapter %d)" % (Save.progress + 1)
		cont.pressed.connect(func(): _go(Save.progress))
		pv.add_child(cont)
	var names := ["1. Mine Entrance", "2. Worker Behind the Rubble", "3. The Stone Worm"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var b := UiStyle.button(Button.new(), 18)
		var st := "stars %d/3, gems %d/3\nbest %d" % [Save.stars[i], Save.best_gems[i], Save.best_score[i]] if i < Save.progress else "not completed"
		b.text = "%s\n%s" % [names[i], st if i <= Save.progress else "locked"]
		b.disabled = i > Save.progress
		b.custom_minimum_size = Vector2(240, 86)
		b.pressed.connect(func(): _go(i))
		row.add_child(b)
	var forge := UiStyle.button(Button.new(), 24)
	forge.text = "Forge — pickaxe: %s, gems: %d" % [Pickaxes.equipped().name, Save.wallet]
	forge.pressed.connect(func(): add_child(Forge.build(func(): get_tree().reload_current_scene())))
	pv.add_child(forge)
	pv.add_child(UiStyle.label("Chapters", 20, Color(0.85, 0.85, 0.85)))
	pv.add_child(row)
	pv.add_child(UiStyle.volume_row())
	var fs := UiStyle.button(Button.new(), 20)
	fs.text = "Fullscreen (F)"
	fs.pressed.connect(func():
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN))
	pv.add_child(fs)
	var help := UiStyle.label("Mouse: select and rotate crystals, hold LMB to aim.\nSpace — strike, R — reset, Esc — pause. Fewer strikes — more stars.", 18, Color(0.85, 0.85, 0.85))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(help)


func _process(delta: float) -> void:
	_t += delta
	bg.scale = Vector2.ONE * (1.04 + 0.03 * sin(_t * 0.15))
	bg.position = Vector2(sin(_t * 0.11) * 18.0, cos(_t * 0.09) * 10.0)
	title.scale = Vector2.ONE * (1.0 + 0.015 * sin(_t * 2.0))
	title.modulate = Color(1, 1, 1).lerp(Color(1.2, 1.1, 0.9), 0.5 + 0.5 * sin(_t * 2.0))


func _go(ch: int) -> void:
	Sfx.play("select")
	Save.next_chapter = ch
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
