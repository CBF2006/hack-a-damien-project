extends Node

# Add new tower scenes to this array as they are created.
var tower1_scene: PackedScene = preload("res://scenes/tower1.tscn")
var tower_scenes: Array = []

var spots = []
var current_index = 0
var cursor

var state = "world"

# W key opens the tower buy menu (Tower 1, Tower 2, ...).
# S key opens the upgrade/sell menu.
var menu_w_options = ["Tower 1", "Tower 2", "Tower 3"]
var menu_s_options = ["Upgrade", "Sell"]
var menu_index = 0

var shop_menu
var item_label
var messageLabel
var message_timer


func _ready():
	tower_scenes = [tower1_scene]
	cursor = get_node("../Cursor")
	cursor.play("choose")
	spots = [
		get_node("../Node2D"),
		get_node("../Node2D2"),
		get_node("../Node2D3"),
		get_node("../Node2D4"),
		get_node("../Node2D5"),
	]
	shop_menu = get_node("../ShopMenu")
	item_label = get_node("../ShopMenu/Panel/ItemLabel")
	messageLabel = get_node("../ShopMenu/Panel/messageLabel")
	messageLabel.text = ""
	message_timer = get_node("../ShopMenu/Panel/message_timer")
	message_timer.timeout.connect(_on_message_timeout)


func open_shop(options):
	menu_index = 0
	shop_menu.visible = true
	item_label.text = options[menu_index]


func close_shop():
	shop_menu.visible = false
	state = "world"


func scroll_shop(direction, options):
	menu_index = (menu_index + direction + options.size()) % options.size()
	item_label.text = options[menu_index]


func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if state == "world":
			if event.keycode == KEY_A:
				current_index = (current_index - 1 + spots.size()) % spots.size()
				update_cursor()
			if event.keycode == KEY_D:
				current_index = (current_index + 1) % spots.size()
				update_cursor()
			if event.keycode == KEY_W:
				state = "towerMenu"
				open_shop(menu_w_options)
			if event.keycode == KEY_S:
				state = "upgradeMenu"
				open_shop(menu_s_options)

		elif state == "towerMenu":
			if event.keycode == KEY_A:
				scroll_shop(-1, menu_w_options)
			if event.keycode == KEY_D:
				scroll_shop(1, menu_w_options)
			if event.keycode == KEY_S:
				close_shop()
			if event.keycode == KEY_W:
				_place_tower(menu_index)

		elif state == "upgradeMenu":
			if event.keycode == KEY_A:
				scroll_shop(-1, menu_s_options)
			if event.keycode == KEY_D:
				scroll_shop(1, menu_s_options)
			if event.keycode == KEY_W:
				close_shop()
			if event.keycode == KEY_S:
				_handle_upgrade_action(menu_index)


# Instantiates the tower type at menu_index on the current spot.
func _place_tower(index: int) -> void:
	if index < tower_scenes.size():
		spots[current_index].place_tower_type(tower_scenes[index])
	close_shop()


# Delegates upgrade/sell actions to the current spot's build_spot script.
func _handle_upgrade_action(index: int) -> void:
	match index:
		0: spots[current_index].on_cursor_action("tower_upgrade")
		1: spots[current_index].on_cursor_action("sell_tower")
	close_shop()


func update_cursor():
	cursor.position = spots[current_index].position


func _on_message_timeout():
	messageLabel.text = ""


func enemy_killed():
	GameManager.add_money(10)
	updateMoney()

func try_buy(cost, _item_name = ""):
	if GameManager.can_spend_money(cost):
		GameManager.spend_money(cost)
		updateMoney()
		close_shop()
	else:
		messageLabel.text = "Not enough cash!"
		message_timer.start()


func updateMoney():
	print("Money: $", GameManager.player_money)
