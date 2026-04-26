extends Control

func _ready() -> void:
	$VBoxContainer/PlayAgainButton.grab_focus()

func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_settings.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/mainMenu.tscn")
