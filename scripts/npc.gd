class_name Npc
extends Node2D
## Rescued miners. Same sheet layout as the hero, recoloured.

@export var sheet: Texture2D = preload("res://assets/sprites/npc_mechanic_sheet.png")
@export var body_scale := 0.8
@export var facing := -1

var spr: Sprite2D
var mode := "idle"
var _t := randf() * 3.0


func _ready() -> void:
	spr = Sprite2D.new()
	spr.texture = sheet
	spr.hframes = 4
	spr.vframes = 2
	spr.centered = false
	spr.offset = -Miner.FRAME_ANCHOR
	spr.frame = 7
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
	scale = Vector2.ONE * body_scale
	spr.scale.x = float(facing)


func _process(delta: float) -> void:
	_t += delta
	match mode:
		"idle":
			spr.frame = 7
			spr.scale.y = 1.0 + sin(_t * 2.1) * 0.015
		"walk":
			spr.frame = int(_t * 9.0) % 4
		"work":
			spr.frame = [4, 5, 6, 6][int(_t * 6.0) % 4]
		"cheer":
			spr.frame = 5
			spr.scale.y = 1.0 + absf(sin(_t * 8.0)) * 0.05


func walk_to(x: float, speed := 90.0) -> void:
	facing = 1 if x > position.x else -1
	spr.scale.x = float(facing)
	mode = "walk"
	var tw := create_tween()
	tw.tween_property(self, "position:x", x, absf(x - position.x) / speed)
	await tw.finished
	mode = "idle"


func face(dirx: int) -> void:
	facing = dirx
	spr.scale.x = float(facing)
