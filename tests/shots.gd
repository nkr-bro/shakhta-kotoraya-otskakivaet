extends "res://tests/autotest.gd"
## Captures one gameplay screenshot per chapter (wave in flight).
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	for ch in 3:
		Save.next_chapter = ch
		game = load("res://scenes/Game.tscn").instantiate()
		game.pause_on_focus_loss = false
		add_child(game)
		await wait_playable()
		var lv = game.level
		await secs(2.5 if ch == 2 else 1.0)
		if ch == 2:
			while not lv.telegraphing:
				await secs(0.2)
			await secs(2.0)
		lv.fire()
		await secs(0.62)
		await screenshot("chapter%d" % (ch + 1))
		game.queue_free()
		await secs(0.3)
	get_tree().quit()
