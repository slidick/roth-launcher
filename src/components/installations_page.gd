extends MarginContainer

signal done

var selected_item: TreeItem


@warning_ignore("native_method_override")
func show() -> void:
	super.show()
	%BackButton.grab_focus()


func _ready() -> void:
	if OS.get_name() == "Linux":
		%FileDialog.root_subfolder = "/"
	if RothLauncher.installations.is_empty():
		scan_for_common()
	else:
		reset()


func scan_for_common() -> void:
	var scan_directories: Array = []
	
	if OS.get_name() == "Windows":
		scan_directories = [
			"C:/Program Files/Steam/steamapps/common/Realms of the Haunting",
			"C:/Program Files (x86)/Steam/steamapps/common/Realms of the Haunting",
			"C:/GOG Games/Realms of the Haunting",
			"C:/GOG/Realms of the Haunting",
			"C:/Games/Realms of the Haunting",
			"D:/Program Files/Steam/steamapps/common/Realms of the Haunting",
			"D:/Program Files (x86)/Steam/steamapps/common/Realms of the Haunting",
			"D:/GOG Games/Realms of the Haunting",
			"D:/GOG/Realms of the Haunting",
			"D:/Games/Realms of the Haunting",
		]
	elif OS.get_name() == "Linux":
		scan_directories = [
			"/opt/Realms of the Haunting",
			"/usr/local/games/Realms of the Haunting",
			OS.get_user_data_dir().path_join("../Steam/steamapps/common/Realms of the Haunting"),
		]
	
	for directory: String in scan_directories:
		if RothLauncher.is_valid_installation_directory(directory):
			%FoundInstallsItemList.add_item(directory)
	%FoundInstallsPanel.show()


func reset() -> void:
	for install_dir: String in RothLauncher.installations:
		add_installation(install_dir)


func add_installation(directory: String) -> void:	
	var install_info: Dictionary = RothLauncher.get_installation_information(directory)
	
	var tree_root: TreeItem = %Tree.get_root()
	if not tree_root:
		tree_root = %Tree.create_item()
	var tree_item: TreeItem = tree_root.create_child()
	tree_item.set_text(0, directory)
	tree_item.set_expand_right(0, true)
	
	var tree_child: TreeItem = tree_item.create_child()
	tree_child.set_selectable(0, false)
	tree_child.set_selectable(1, false)
	tree_child.set_text(0, "Language")
	tree_child.set_text(1, install_info.get("language", ""))
	
	tree_child = tree_item.create_child()
	tree_child.set_selectable(0, false)
	tree_child.set_selectable(1, false)
	tree_child.set_text(0, "RES Version")
	tree_child.set_text(1, install_info.get("res_version", ""))
	
	tree_child = tree_item.create_child()
	tree_child.set_selectable(0, false)
	tree_child.set_selectable(1, false)
	tree_child.set_text(0, "EXE Version")
	tree_child.set_text(1, install_info.get("exe_version", ""))
	
	tree_child = tree_item.create_child()
	tree_child.set_selectable(0, false)
	tree_child.set_selectable(1, false)
	tree_child.set_text(0, "Store")
	tree_child.set_text(1, install_info.get("store", ""))
	
	%BackButton.disabled = false
	%NoInstallsLabel.hide()


func _on_add_button_pressed() -> void:
	%FileDialog.popup()


func _on_file_dialog_dir_selected(dir: String) -> void:
	if dir in RothLauncher.installations:
		return
	if RothLauncher.is_valid_installation_directory(dir):
		RothLauncher.add_installation(dir)
		add_installation(dir)
	else:
		await Dialog.information("Invalid installation directory:\n%s" % dir, "Error", true, Vector2(400,150), "Okay", HORIZONTAL_ALIGNMENT_CENTER)
		%FileDialog.popup()


func _on_tree_item_mouse_selected(mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		selected_item = %Tree.get_selected()
		%PopupMenu.popup(Rect2i(int(%Tree.global_position.x + mouse_position.x), int(%Tree.global_position.y + mouse_position.y), 0, 0))


func _on_popup_menu_index_pressed(index: int) -> void:
	match index:
		0:
			RothLauncher.remove_installation(selected_item.get_text(0))
			if len(RothLauncher.installations) == 0:
				%BackButton.disabled = true
				%NoInstallsLabel.show()
			selected_item.free()


func _on_back_button_pressed() -> void:
	%BackButton.disabled = true
	done.emit("Installations")
	await get_tree().create_timer(0.2).timeout
	%BackButton.disabled = false


func _on_found_installs_item_list_multi_selected(_index: int, _selected: bool) -> void:
	if len(%FoundInstallsItemList.get_selected_items()) > 0:
		%FoundInstallsConfirmButton.disabled = false
	else: 
		%FoundInstallsConfirmButton.disabled = true


func _on_found_installs_cancel_button_pressed() -> void:
	%FoundInstallsPanel.hide()


func _on_found_installs_confirm_button_pressed() -> void:
	for index: int in %FoundInstallsItemList.get_selected_items():
		var directory: String = %FoundInstallsItemList.get_item_text(index)
		RothLauncher.add_installation(directory)
		add_installation(directory)
	%FoundInstallsPanel.hide()
