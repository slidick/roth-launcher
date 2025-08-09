extends Control

signal done


@onready var _things_to_save : Dictionary = {
	"dosbox_settings": {
		"fullscreen": {"node": %FullscreenCheckButton, "value": %FullscreenCheckButton.button_pressed},
		"fulldouble": {"node": %FulldoubleCheckButton, "value": %FulldoubleCheckButton.button_pressed},
		"fullresolution": {"node": %FullResolutionOption, "value": %FullResolutionOption.text},
		"windowresolution": {"node": %WindowResolutionOption, "value": %WindowResolutionOption.text},
		"output": {"node": %OutputOption, "value": %OutputOption.text},
		"autolock": {"node": %AutolockCheckButton, "value": %AutolockCheckButton.button_pressed},
		"scaler": {"node": %ScalerOption, "value": %ScalerOption.text},
		"cycles": {"node": %CyclesOption, "value": %CyclesOption.text}
	},
}

@warning_ignore("native_method_override")
func show() -> void:
	super.show()
	%BackButton.grab_focus()


func _ready() -> void:
	_reset()


func _reset() -> void:
	for outer_key: String in _things_to_save:
		var settings: Variant = Settings.settings.get(outer_key)
		if settings:
			for key: String in settings as Dictionary:
				if key in _things_to_save[outer_key]:
					_handle_node_reset(_things_to_save[outer_key][key].node, settings[key])
					_things_to_save[outer_key][key].value = settings[key]
		else:
			var save_data: Dictionary = {}
			for key: String in _things_to_save[outer_key]:
				_handle_node_reset(_things_to_save[outer_key][key].node, _things_to_save[outer_key][key].value)
				save_data[key] = _things_to_save[outer_key][key].value
			Settings.update_settings(outer_key, save_data)


func _save(_unused: Variant = null) -> void:
	for outer_key: String in _things_to_save:
		var save_data  : Dictionary = {}
		for key: String in _things_to_save[outer_key]:
			_handle_node_save(_things_to_save[outer_key][key])
			save_data[key] = _things_to_save[outer_key][key].value
		Settings.update_settings(outer_key, save_data)


func _handle_node_reset(node: Control, value: Variant) -> void:
	if node is LineEdit:
		node.text = value
	if (node is CheckBox or
			node is CheckButton):
		node.button_pressed = value
	if node is OptionButton:
		for i in range(node.item_count):
			if node.get_item_text(i).to_lower() == value.to_lower():
				node.selected = i


func _handle_node_save(node_data: Dictionary) -> void:
	if node_data.node is LineEdit:
		node_data.value = node_data.node.text
	if (node_data.node is CheckBox or
			node_data.node is CheckButton):
		node_data.value = node_data.node.button_pressed
	if node_data.node is OptionButton:
		node_data.value = node_data.node.text.to_lower()


func _on_back_button_pressed() -> void:
	%BackButton.disabled = true
	done.emit("Settings")
	await get_tree().create_timer(0.2).timeout
	%BackButton.disabled = false
