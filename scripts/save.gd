extends Node
## Progress and audio settings. A missing or damaged file falls back to defaults.

const PATH := "user://save.cfg"

var progress := 0          # number of finished chapters (0..3)
var volume := 0.8
var muted := false
var next_chapter := 0       # chapter Game.tscn should open
var stars := [0, 0, 0]      # best rating per chapter
var best_score := [0, 0, 0]
var wallet := 0
var owned := ["standard"]
var equipped := "standard"
var best_gems := [0, 0, 0]


func _ready() -> void:
	load_data()
	# Desktop builds start fullscreen (web needs a click: button / F key).
	if not OS.has_feature("web") and not OS.has_feature("editor_hint"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var p = cfg.get_value("progress", "chapters", 0)
	var v = cfg.get_value("audio", "volume", 0.8)
	var m = cfg.get_value("audio", "muted", false)
	progress = clampi(int(p), 0, 3) if (p is int or p is float) else 0
	volume = clampf(float(v), 0.0, 1.0) if (v is int or v is float) else 0.8
	muted = m if m is bool else false
	for key in ["best_score", "best_gems"]:
		var arr = cfg.get_value("progress", key, [0, 0, 0])
		if arr is Array and arr.size() == 3:
			for i in 3:
				if arr[i] is int or arr[i] is float:
					get(key)[i] = maxi(0, int(arr[i]))
	var w = cfg.get_value("forge", "wallet", 0)
	wallet = maxi(0, int(w)) if (w is int or w is float) else 0
	var o = cfg.get_value("forge", "owned", ["standard"])
	if o is Array:
		owned = ["standard"]
		for x in o:
			if x is String and not owned.has(x):
				owned.append(x)
	var e = cfg.get_value("forge", "equipped", "standard")
	equipped = e if (e is String and owned.has(e)) else "standard"
	var st = cfg.get_value("progress", "stars", [0, 0, 0])
	if st is Array and st.size() == 3:
		for i in 3:
			stars[i] = clampi(int(st[i]), 0, 3) if (st[i] is int or st[i] is float) else 0


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "chapters", progress)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "best_gems", best_gems)
	cfg.set_value("forge", "wallet", wallet)
	cfg.set_value("forge", "owned", owned)
	cfg.set_value("forge", "equipped", equipped)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "muted", muted)
	cfg.save(PATH)


func complete_chapter(index: int, rating := 0) -> void:
	progress = maxi(progress, index + 1)
	stars[index] = maxi(stars[index], rating)
	save_data()


func record(index: int, score: int, gems: int) -> void:
	best_score[index] = maxi(best_score[index], score)
	best_gems[index] = maxi(best_gems[index], gems)
	save_data()
