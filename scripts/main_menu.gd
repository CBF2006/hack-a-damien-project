extends Control

func _ready():
	var viewport_size = get_viewport().get_visible_rect().size
	$TextureRect.size = viewport_size
	$TextureRect.position = Vector2.ZERO
	$VBoxContainer/Button.grab_focus()

	var joy = get_tree().get_first_node_in_group("joystick_controller")
	if joy:
		joy.action_pressed.connect(_on_joy_action)

func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://scenes/game_settings.tscn")

func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/options.tscn")

func _on_quit_button_pressed():
	get_tree().quit()

func _on_joy_action(action: String) -> void:
	print("joy action: ", action)
	if action == "confirm":
		var focused := get_viewport().gui_get_focus_owner()
		print("focused: ", focused)
		if focused is Button:
			focused.emit_signal("pressed")
