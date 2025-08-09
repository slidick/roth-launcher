extends Control

signal done

var current_screenshot: int = 0

@warning_ignore("native_method_override")
func show() -> void:
	super.show()
	%LaunchButton.grab_focus()


func _ready() -> void:
	RothLauncher.installations_updated.connect(_on_installations_updated)
	update_installations()
	update_maps()
	
	%StoryLabel.focus_mode = FOCUS_NONE
	
	RothLauncher.game_launched.connect(func () -> void:
		%AnimationPlayer.play("playing_game")
		await get_tree().create_timer(0.2).timeout
		%MainPanelContainer.hide()
	)
	RothLauncher.game_closed.connect(func () -> void:
		%MainPanelContainer.show()
		%AnimationPlayer.play_backwards("playing_game")
	)


func _on_back_button_pressed() -> void:
	%BackButton.disabled = true
	done.emit("Play")
	await get_tree().create_timer(0.2).timeout
	%BackButton.disabled = false


func _on_installations_updated() -> void:
	update_installations()


func update_installations() -> void:
	%InstallationOption.clear()
	var index: int = 0
	var selected_index: int = -1
	for install_dir: String in RothLauncher.installations:
		%InstallationOption.add_item(install_dir)
		%InstallationOption.set_item_tooltip(index, install_dir)
		if install_dir == RothLauncher.current_installation:
			selected_index = index
		index += 1
	%InstallationOption.select(selected_index)
	if selected_index == -1:
		%LaunchButton.disabled = true
		
		if %InstallationOption.item_count == 1:
			%InstallationOption.select(0)
			_on_installation_option_item_selected(0)
	else:
		%LaunchButton.disabled = false


func _on_installation_option_item_selected(index: int) -> void:
	var directory: String = %InstallationOption.get_item_text(index)
	RothLauncher.set_current_installation(directory)
	%LaunchButton.disabled = false


func _on_add_map_button_pressed() -> void:
	%AddPopupMenu.popup(Rect2i(%AddMapButton.global_position.x, %AddMapButton.global_position.y + %AddMapButton.size.y, 0, 0))


func _on_add_popup_menu_index_pressed(index: int) -> void:
	match index:
		0:
			#print("Browse Local")
			pass
		1:
			#print("Browse Online")
			pass
	Dialog.information("Not yet implemented", "Info", true, Vector2(300,140), "Close", HORIZONTAL_ALIGNMENT_CENTER)

func update_maps() -> void:
	%MapList.clear()
	
	var index: int = 0
	var selected_index: int = 0
	
	for custom_map: Dictionary in RothLauncher.custom_maps:
		var idx: int = %MapList.add_item(custom_map.map_name)
		%MapList.set_item_metadata(idx, custom_map)
		
		if custom_map.uuid == RothLauncher.current_map:
			selected_index = index
		index += 1
	
	%MapList.select(selected_index)
	_on_map_list_item_selected(selected_index)


func _on_launch_button_pressed() -> void:
	%LaunchButton.disabled = true
	
	var index: int = %MapList.get_selected_items()[0]
	var custom_map: Dictionary = %MapList.get_item_metadata(index)
	var installation_directory: String = %InstallationOption.text
	
	var launch_options: Dictionary = {
		"skip_intro": %SkipIntroCheckButton.button_pressed,
		"disable_cutscenes": %DisableCutscenesCheckButton.button_pressed,
	}
	
	if launch_options.disable_cutscenes:
		launch_options.skip_intro = false
	
	await RothLauncher.launch(custom_map, installation_directory, launch_options)
	update_maps()
	
	%LaunchButton.disabled = false


func _on_map_list_item_selected(index: int) -> void:
	var custom_map: Dictionary = %MapList.get_item_metadata(index)
	%TitleLabel.text = "%s (%s)" % [custom_map.map_title, custom_map.release_date]
	%InstalledLabel.text = "%s" % custom_map.install_date
	%LastPlayedLabel.text = "%s" % custom_map.last_played if custom_map.last_played != "1970-01-01" else "Unplayed"
	%DescriptionLabel.text = "%s" % custom_map.description
	%StoryLabel.text = "%s" % custom_map.story
	
	current_screenshot = 0
	
	if custom_map.uuid == "0":
		%TextureRect.texture = load(custom_map.screenshots[current_screenshot])
	
	
	
	%PrevImageButton.disabled = true
	if len(custom_map.screenshots) > 1:
		%NextImageButton.disabled = false
		%ImageButtonsContainer.show()
	else:
		%NextImageButton.disabled = true
		%ImageButtonsContainer.hide()
	
	%ScreenshotCountLabel.text = "(%s/%s)" % [current_screenshot+1, len(custom_map.screenshots)]


func _on_prev_image_button_pressed() -> void:
	var index: int = %MapList.get_selected_items()[0]
	var custom_map: Dictionary = %MapList.get_item_metadata(index)
	current_screenshot -= 1
	if custom_map.uuid == "0":
		%TextureRect.texture = load(custom_map.screenshots[current_screenshot])
	%NextImageButton.disabled = false
	if current_screenshot == 0:
		%PrevImageButton.disabled = true
	%ScreenshotCountLabel.text = "(%s/%s)" % [current_screenshot+1, len(custom_map.screenshots)]


func _on_next_image_button_pressed() -> void:
	var index: int = %MapList.get_selected_items()[0]
	var custom_map: Dictionary = %MapList.get_item_metadata(index)
	current_screenshot += 1
	if custom_map.uuid == "0":
		%TextureRect.texture = load(custom_map.screenshots[current_screenshot])
	%PrevImageButton.disabled = false
	if current_screenshot == len(custom_map.screenshots) - 1:
		%NextImageButton.disabled = true
	%ScreenshotCountLabel.text = "(%s/%s)" % [current_screenshot+1, len(custom_map.screenshots)]


func _on_launch_options_button_pressed() -> void:
	%LaunchOptionsPanel.show()


func _on_confirm_launch_options_button_pressed() -> void:
	%LaunchOptionsPanel.hide()


func _on_disable_cutscenes_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%SkipIntroCheckButton.disabled = true
	else:
		%SkipIntroCheckButton.disabled = false
