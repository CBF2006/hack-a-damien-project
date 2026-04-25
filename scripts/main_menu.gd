extends Control

const GAME_SCENE = "res://scenes/game.tscn"

func _ready():
	var viewport_size = get_viewport().get_visible_rect().size
	$TextureRect.size = viewport_size
	$TextureRect.position = Vector2.ZERO
	pass

func _on_start_button_pressed():
	get_tree().change_scene_to_file(GAME_SCENE)
	
func  _on_quit_button_pressed():
	get_tree().quit()
