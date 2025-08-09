extends MarginContainer

signal done(from_page: String)


@warning_ignore("native_method_override")
func show() -> void:
	super.show()
	%BackButton.show()
	%RunningLabel.hide()
	%BackButton.grab_focus()


func _on_back_button_pressed() -> void:
	%BackButton.disabled = true
	done.emit("Tips")
	await get_tree().create_timer(0.2).timeout
	%BackButton.disabled = false
