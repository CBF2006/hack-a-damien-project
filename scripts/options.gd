extends Control

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1080, 920),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var _selected_res: int = 0

@onready var _res_buttons: Array = [
	$VBoxContainer/Res1080x920,
	$VBoxContainer/Res1280x720,
	$VBoxContainer/Res1600x900,
	$VBoxContainer/Res1920x1080,
]


func _ready() -> void:
	$TextureRect.size = get_viewport().get_visible_rect().size
	$TextureRect.position = Vector2.ZERO
	$VBoxContainer/BackButton.grab_focus()

	var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	$VBoxContainer/FullscreenButton.button_pressed = is_full

	var current := DisplayServer.window_get_size()
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == current:
			_selected_res = i
			break
	_highlight_selected()


func _highlight_selected() -> void:
	for i in range(_res_buttons.size()):
		_res_buttons[i].modulate = Color(0.6, 1.0, 0.6) if i == _selected_res else Color.WHITE


func _apply_resolution(index: int) -> void:
	_selected_res = index
	_highlight_selected()
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_size(RESOLUTIONS[index])
		var screen := DisplayServer.screen_get_size()
		var win := DisplayServer.window_get_size()
		DisplayServer.window_set_position((screen - win) / 2)


func _on_res_1080x920_pressed() -> void:
	_apply_resolution(0)

func _on_res_1280x720_pressed() -> void:
	_apply_resolution(1)

func _on_res_1600x900_pressed() -> void:
	_apply_resolution(2)

func _on_res_1920x1080_pressed() -> void:
	_apply_resolution(3)


func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_resolution(_selected_res)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/mainMenu.tscn")
