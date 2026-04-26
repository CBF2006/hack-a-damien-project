extends Node

var spots = []
var current_index = 0
var cursor

var state = "world"

var menu_w_options = ["Tower 1", "Tower 2", "Tower 3"]
var menu_s_options = ["Upgrade 1", "Upgrade 2", "Upgrade 3"]
var menu_index = 0

var tower_costs = [50, 100, 150]
var upgrade_costs = [30, 60, 90]

var shop_menu
var item_label

var money = 1000
var messageLabel

var message_timer

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
			if event.keycode == KEY_S:
				state = "upgradeMenu"
				open_shop(menu_w_options)
			if event.keycode == KEY_W:
				state = "towerMenu"
				open_shop(menu_s_options)

		elif state == "upgradeMenu":
			if event.keycode == KEY_A:
				scroll_shop(-1, menu_w_options)
			if event.keycode == KEY_D:
				scroll_shop(1, menu_w_options)
			if event.keycode == KEY_W:
				close_shop()
			if event.keycode == KEY_S:
				try_buy(tower_costs[menu_index], menu_w_options[menu_index])

		elif state == "towerMenu":
			if event.keycode == KEY_A:
				scroll_shop(-1, menu_s_options)
			if event.keycode == KEY_D:
				scroll_shop(1, menu_s_options)
			if event.keycode == KEY_S:
				close_shop()
			if event.keycode == KEY_W:
				try_buy(upgrade_costs[menu_index], menu_s_options[menu_index])

func update_cursor():
	cursor.position = spots[current_index].position

func _on_message_timeout():
	messageLabel.text = ""

func enemy_killed():
	money += 10 
	updateMoney()

func try_buy(cost, item_name):
	if money >= cost:
		money -= cost
		updateMoney()
		close_shop()
	else:
		messageLabel.text = "Not enough cash!"
		message_timer.start()

func updateMoney():
	print("Money: $", money)
