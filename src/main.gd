extends Control

var game_running: bool = false

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if not game_running:
				get_tree().quit()
			else:
				if await Dialog.confirm("Launcher should remain running while game is running.\n Are you sure you wish to quit?", "Confirm?", false, Vector2(400,200)):
					get_tree().quit()


func _ready() -> void:
	get_tree().auto_accept_quit = false
	%VersionLabel.text = "v%s" % ProjectSettings.get_setting("application/config/version")
	
	RothLauncher.game_launched.connect(func () -> void:
		game_running = true
	)
	RothLauncher.game_closed.connect(func () -> void:
		game_running = false
	)
	
	hide_components()
	%PlayButton.grab_focus()
	if RothLauncher.installations.is_empty():
		change_page("installations", false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("take_screenshot"):
		take_screenshot()


func change_page(page_title: String, animation: bool = true, from_page: String = "") -> void:
	match page_title:
		"main":
			%MainLayout.show()
			%AnimationPlayer.play_backwards("show_component")
			await get_tree().create_timer(0.2).timeout
			hide_components()
			if from_page.is_empty():
				%PlayButton.grab_focus()
			else:
				find_child(from_page+"Button").grab_focus()
		"play":
			%PlayPage.show()
			%AnimationPlayer.play("show_component")
			await get_tree().create_timer(0.2).timeout
			#%MainLayout.hide()
		"settings":
			%Settings.show()
			%AnimationPlayer.play("show_component")
			await get_tree().create_timer(0.2).timeout
			#%MainLayout.hide()
		"controls":
			%Controls.show()
			%AnimationPlayer.play("show_component")
			await get_tree().create_timer(0.2).timeout
			#%MainLayout.hide()
		"tips":
			%Tips.show()
			%AnimationPlayer.play("show_component")
			await get_tree().create_timer(0.2).timeout
			#%MainLayout.hide()
		"installations":
			%Installations.show()
			%AnimationPlayer.play("show_component")
			if not animation:
				%AnimationPlayer.seek(5)
			await get_tree().create_timer(0.2).timeout
			#%MainLayout.hide()


func hide_components() -> void:
	for child: Control in %ComponentLayouts.get_children():
		child.hide()


func take_screenshot() -> void:
	if not DirAccess.dir_exists_absolute("user://screenshots"):
		DirAccess.make_dir_absolute("user://screenshots")
	var list: PackedStringArray = DirAccess.get_files_at("user://screenshots")
	var number: int = 0
	for file: String in list:
		var i: int = int(file.split("screen-")[1].split(".png")[0])
		if i > number:
			number = i
	number += 1
	get_viewport().get_texture().get_image().save_png("user://screenshots/screen-%03d.png" % number)


func _on_quit_button_pressed() -> void:
	get_tree().get_root().propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


func _on_play_button_pressed() -> void:
	change_page("play")


func _on_installations_button_pressed() -> void:
	change_page("installations")


func _on_controls_button_pressed() -> void:
	change_page("controls")


func _on_settings_button_pressed() -> void:
	change_page("settings")


func _on_tips_button_pressed() -> void:
	change_page("tips")


func _on_page_done(from_page: String) -> void:
	change_page("main", true, from_page)
