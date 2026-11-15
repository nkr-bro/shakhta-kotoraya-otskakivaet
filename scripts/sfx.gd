extends Node
## Sound effects and the ambient mine loop. Audio starts after the first
## user interaction, as browsers require.

const NAMES := ["select", "rotate", "swing", "strike", "ricochet", "miss", "hit", "crumble",
	"machine", "roar", "worm_hurt", "charge", "blast", "damage", "knocks", "victory", "ambient", "boss_music"]

var streams := {}
var pool: Array[AudioStreamPlayer] = []
var ambient: AudioStreamPlayer
var unlocked := false
var _last_play := {}
var voice_player: AudioStreamPlayer
var music_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	ambient = AudioStreamPlayer.new()
	ambient.stream = streams["ambient"]
	ambient.volume_db = -6.0
	ambient.finished.connect(func(): ambient.play())
	add_child(ambient)
	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -5.0
	music_player.finished.connect(func(): if music_player.stream: music_player.play())
	add_child(music_player)
	apply_settings()


func _input(event: InputEvent) -> void:
	if unlocked:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		unlocked = true
		ambient.play()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Save.volume, 0.0001)))
	AudioServer.set_bus_mute(0, Save.muted)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not unlocked or not streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if sound == "rotate" and now - int(_last_play.get(sound, 0)) < 60:
		return
	_last_play[sound] = now
	for p in pool:
		if not p.playing:
			p.stream = streams[sound]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## Plays the recorded Russian line for a dialogue text, if one exists.
func voice(text: String) -> void:
	voice_player.stop()
	if not unlocked:
		return
	var path := "res://assets/voice/%s.wav" % text.md5_text().substr(0, 12)
	if ResourceLoader.exists(path):
		voice_player.stream = load(path)
		voice_player.play()


func stop_voice() -> void:
	voice_player.stop()


func music(sound: String) -> void:
	music_player.stream = streams.get(sound)
	if unlocked and music_player.stream:
		music_player.play()
	ambient.volume_db = -14.0


func stop_music() -> void:
	music_player.stop()
	music_player.stream = null
	ambient.volume_db = -6.0
