extends Control

var selected_difficulty: int = 1

func _ready() -> void:
	_update_highlight()
	$VBoxContainer/NormalButton.grab_focus()

func _on_easy_pressed() -> void:
	selected_difficulty = 0
	_update_highlight()

func _on_normal_pressed() -> void:
	selected_difficulty = 1
	_update_highlight()

func _on_hard_pressed() -> void:
	selected_difficulty = 2
	_update_highlight()

func _on_start_pressed() -> void:
	GameManager.setup(selected_difficulty)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/mainMenu.tscn")

func _update_highlight() -> void:
	$VBoxContainer/EasyButton.modulate = Color.WHITE
	$VBoxContainer/NormalButton.modulate = Color.WHITE
	$VBoxContainer/HardButton.modulate = Color.WHITE
	match selected_difficulty:
		0: $VBoxContainer/EasyButton.modulate = Color(0.4, 1.0, 0.4)
		1: $VBoxContainer/NormalButton.modulate = Color(1.0, 1.0, 0.4)
		2: $VBoxContainer/HardButton.modulate = Color(1.0, 0.4, 0.4)
