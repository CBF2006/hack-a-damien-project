extends Node

var spots = []
var current_index = 0
var cursor

func _ready():
	cursor = get_node("../Cursor")
	cursor.play("choose")
	spots = [
		get_node("../Node2D"),
		get_node("../Node2D2"),
		get_node("../Node2D3"),
		get_node("../Node2D4"),
		get_node("../Node2D5"),
	]

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_A:
			current_index = (current_index - 1 + spots.size()) % spots.size()
			update_cursor()
		if event.keycode == KEY_D:
			current_index = (current_index + 1) % spots.size()
			update_cursor()
		if event.keycode == KEY_W:
			print("Up selected")
		if event.keycode == KEY_S:
			print("Down selected")

func update_cursor():
	cursor.position = spots[current_index].position
	print("Selected: ", spots[current_index].name)
