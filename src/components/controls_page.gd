extends Control

signal done
signal key_registered

const basic_controls: Array = [
	"move_forward",
	"move_backward",
	"strafe_left",
	"strafe_right",
	"turn_left",
	"turn_right",
	"look_up",
	"look_down",
	"tilt_up",
	"tilt_down",
	"jump",
	"crouch",
	"attack",
	"inventory",
	"toggle_run",
	"unarmed",
	"quickslot_1",
	"quickslot_2",
	"quickslot_3",
	"quickslot_4",
	"quickslot_5",
]

const advanced_controls: Array = [
	"quicksave",
	"quickload",
	"escape",
	"enter",
	"hide_weapon",
	"toggle_subtitles",
	"toggle_adventure_mode",
	"main_menu",
	"reload_after_death",
	"hold_run",
	"increase_gamma",
	"decrease_gamma",
	"increase_viewport",
	"decrease_viewport",
	"redraw_screen",
	"toggle_textures",
	"toggle_mouse_buttons",
	"display_version",
]

const dosbox_controls: Array = [
	"toggle_fullscreen",
	"capture_mouse",
	"cycles_up",
	"cycles_down",
	#"debugger",
]


var _current_key: String = ""
var _adding: bool = false


@warning_ignore("native_method_override")
func show() -> void:
	super.show()
	%BackButton.grab_focus()

func _ready() -> void:
	var controls: Dictionary = Settings.settings.get("dosbox_keymap", {})
	if controls.is_empty():
		controls = reset_controls()
	
	load_controls(controls)


func get_mapping_text(mapping_array: Array) -> String:
	var godot_key_string: String = ""
	for keycode: String in mapping_array:
		godot_key_string += ", " + SDL.sdl_to_godot_string(int(keycode))
	return godot_key_string.lstrip(", ")


func _on_back_button_pressed() -> void:
	%BackButton.disabled = true
	done.emit("Controls")
	await get_tree().create_timer(0.2).timeout
	%BackButton.disabled = false


func _on_button_pressed(key: String, adding: bool = false) -> void:
	_current_key = key
	_adding = adding
	%KeyInputPanel.show()
	var node: Node = find_child(key)
	if node.get_child_count() > 0:
		node.get_child(0).show()
	%KeyEdit.grab_focus()
	%ChangingKeyLabel.text = key.to_pascal_case()


func _on_key_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		#print("Command: %s, Godot: %s, SDL: %s" % [_current_key, event.keycode, SDL.godot_to_sdl(event)])
		%KeyInputPanel.hide()
		
		var key_string := OS.get_keycode_string(event.keycode)
		if event.location == KEY_LOCATION_LEFT:
			key_string = "Left" + key_string
		if event.location == KEY_LOCATION_RIGHT:
			key_string = "Right" + key_string
		get_viewport().set_input_as_handled()
		
		var code: int = SDL.godot_to_sdl(event)
		if code == -1:
			Dialog.information("Key mapping to sdl not found for keycode: %d" % event.keycode, "Error", false, Vector2(450, 160), "Close", HORIZONTAL_ALIGNMENT_CENTER)
		else:
		
			if _adding:
				var current_mapping: Variant = Settings.settings.get("dosbox_keymap").get(_current_key)
				if current_mapping and current_mapping is Array:
					current_mapping.append("%d" % code)
				else:
					current_mapping = ["%d" % code]
				Settings.update_settings("dosbox_keymap", {_current_key: current_mapping})
				var mapping_text: String = get_mapping_text(current_mapping)
				find_child(_current_key).text = mapping_text
			else:
				Settings.update_settings("dosbox_keymap", {_current_key: ["%d" % code]})
				find_child(_current_key).text = key_string
		
		if find_child(_current_key).get_child_count() > 0:
			find_child(_current_key).get_child(0).hide()
		
		key_registered.emit()


func _on_change_all_button_pressed() -> void:
	for node_name: String in basic_controls:
		_current_key = node_name
		%KeyInputPanel.show()
		%KeyEdit.grab_focus()
		%ChangingKeyLabel.text = node_name.to_pascal_case()
		var node: Node = find_child(node_name)
		if node.get_child_count() > 0:
			node.get_child(0).show()
		
		await key_registered

func _on_change_all_advanced_button_pressed() -> void:
	for node_name: String in advanced_controls:
		_current_key = node_name
		%KeyInputPanel.show()
		%KeyEdit.grab_focus()
		%ChangingKeyLabel.text = node_name.to_pascal_case()
		var node: Node = find_child(node_name)
		if node.get_child_count() > 0:
			node.get_child(0).show()
		
		await key_registered


func _on_change_all_dos_box_button_pressed() -> void:
	for node_name: String in dosbox_controls:
		_current_key = node_name
		%KeyInputPanel.show()
		%KeyEdit.grab_focus()
		%ChangingKeyLabel.text = node_name.to_pascal_case()
		var node: Node = find_child(node_name)
		if node.get_child_count() > 0:
			node.get_child(0).show()
		
		await key_registered


func _on_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_current_key = get_viewport().gui_get_hovered_control().name
		%PopupMenu.popup(Rect2i(int(event.global_position.x), int(event.global_position.y), 0, 0))


func _on_popup_menu_index_pressed(_index: int) -> void:
	Settings.settings.dosbox_keymap.erase(_current_key)
	Settings._save_settings()
	find_child(_current_key).text = ""


func _on_reset_button_pressed() -> void:
	if await Dialog.confirm("This will reset controls to the default.", "Confirm?", false, Vector2(300, 200)):
		var controls: Dictionary = reset_controls()
		load_controls(controls)

func reset_controls() -> Dictionary:
	var controls: Dictionary = {
		"move_forward": ["%d" % SDL.SDLK_w],
		"move_backward": ["%d" % SDL.SDLK_s],
		"strafe_left": ["%d" % SDL.SDLK_a],
		"strafe_right": ["%d" % SDL.SDLK_d],
		"turn_left": ["%d" % SDL.SDLK_q],
		"turn_right": ["%d" % SDL.SDLK_e],
		"look_up": ["%d" % SDL.SDLK_r],
		"look_down": ["%d" % SDL.SDLK_f],
		"tilt_up": ["%d" % SDL.SDLK_t],
		"tilt_down": ["%d" % SDL.SDLK_g],
		"jump": ["%d" % SDL.SDLK_SPACE],
		"crouch": ["%d" % SDL.SDLK_c],
		"attack": ["%d" % SDL.SDLK_LCTRL],
		"inventory": ["%d" % SDL.SDLK_TAB, "%d" % SDL.SDLK_i],
		"toggle_run": ["%d" % SDL.SDLK_BACKQUOTE],
		
		"unarmed": ["%d" % SDL.SDLK_1],
		"quickslot_1": ["%d" % SDL.SDLK_2],
		"quickslot_2": ["%d" % SDL.SDLK_3],
		"quickslot_3": ["%d" % SDL.SDLK_4],
		"quickslot_4": ["%d" % SDL.SDLK_5],
		"quickslot_5": ["%d" % SDL.SDLK_6],
		"quicksave": ["%d" % SDL.SDLK_F9],
		"quickload": ["%d" % SDL.SDLK_F10],
		"hide_weapon": ["%d" % SDL.SDLK_F1],
		"toggle_subtitles": ["%d" % SDL.SDLK_F2],
		"toggle_adventure_mode": ["%d" % SDL.SDLK_F3],
		"toggle_mouse_buttons": ["%d" % SDL.SDLK_F5],
		"display_version": ["%d" % SDL.SDLK_F8],
		"increase_gamma": ["%d" % SDL.SDLK_PERIOD],
		"decrease_gamma": ["%d" % SDL.SDLK_COMMA],
		"increase_viewport": ["%d" % SDL.SDLK_EQUALS],
		"decrease_viewport": ["%d" % SDL.SDLK_MINUS],
		"enter": ["%d" % SDL.SDLK_RETURN, "%d" % SDL.SDLK_KP_ENTER],
		"escape": ["%d" % SDL.SDLK_ESCAPE],
		"main_menu": ["%d" % SDL.SDLK_m],
		"toggle_textures": ["%d" % SDL.SDLK_BACKSLASH],
		"redraw_screen": ["%d" % SDL.SDLK_SLASH],
		"reload_after_death": ["%d" % SDL.SDLK_SPACE],
		"hold_run": ["%d" % SDL.SDLK_LSHIFT],
		
		"toggle_fullscreen": ["%d" % SDL.SDLK_F11],
		"capture_mouse": ["%d" % SDL.SDLK_F12],
		"cycles_up": ["%d" % SDL.SDLK_RIGHTBRACKET],
		"cycles_down": ["%d" % SDL.SDLK_LEFTBRACKET],
		"debugger": ["%d" % SDL.SDLK_PAUSE],
	}
	Settings.update_settings("dosbox_keymap", controls)
	return controls


func load_controls(controls: Dictionary) -> void:
	for key:String in controls:
		var node: Label = find_child(key)
		if node:
			node.text = get_mapping_text(controls[key])


func _on_hold_run_info_mouse_entered() -> void:
	%hold_run_info_panel.show()


func _on_hold_run_info_mouse_exited() -> void:
	%hold_run_info_panel.hide()
