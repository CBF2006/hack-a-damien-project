extends Node2D

@export var enemy_scene: PackedScene

var hud_scene: PackedScene = preload("res://scenes/hud.tscn")
var hud_instance: Node

var wave: int = 1
var enemies_to_spawn: int = 5
var spawn_delay: float = 2.0
var enemies_alive: int = 0
var time_between_waves: float = 5.0
var first_wave_delay: float = 10.0
var game_active: bool = true

var shop_open: bool = false
var shop_index: int = 0
var shop_actions: Array[String] = ["place_tower", "tower_upgrade", "sell_tower"]
var shop_labels: Array[String] = ["Build Tower", "Upgrade Tower", "Sell Tower"]

@onready var joystick_controller: Node = $JoystickController
@onready var shop_menu: CanvasLayer = $ShopMenu
@onready var shop_item_label: Label = $ShopMenu/Panel/ItemLabel
@onready var shop_message_label: Label = $ShopMenu/Panel/messageLabel

func _ready() -> void:
	hud_instance = hud_scene.instantiate()
	add_child(hud_instance)
	_setup_shop_menu()
	_bind_joystick_events()

	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.victory_triggered.connect(_on_victory)
	show_tutorial_hint("Hover a spot. Up-Up builds, Up-Down upgrades, Down-Down-Down sells. R-L-R-L opens shop.")
	
	GameManager.play_song(GameManager.SONG_MAIN)
	start_wave(first_wave_delay)

func start_wave(initial_delay: float = 0.0) -> void:
	if not game_active:
		return
	hud_instance.set_wave(wave)
	show_tutorial_hint("Move to a tower and then press down on the joystick to interact with it")
	enemies_alive = enemies_to_spawn

	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay).timeout

	GameManager.play_song(GameManager.SONG_WAVE_START)

	for i in range(enemies_to_spawn):
		if not game_active:
			return
		await get_tree().create_timer(spawn_delay).timeout
		var enemy = spawn_enemy()
		enemy.activate()

func spawn_enemy() -> Node:
	var follow := PathFollow2D.new()
	follow.loop = false
	$Path2D.add_child(follow)

	var enemy := enemy_scene.instantiate()
	follow.add_child(enemy)
	return enemy

func enemies_died() -> void:
	if not game_active:
		return
	enemies_alive -= 1
	if enemies_alive == 0:
		wave += 1
		enemies_to_spawn += 1
		GameManager.check_victory(wave)
		if game_active:
			await get_tree().create_timer(time_between_waves).timeout
		if game_active:
			start_wave()

func _on_game_over() -> void:
	GameManager.play_song(GameManager.SONG_GAMEOVER)
	game_active = false
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _on_victory() -> void:
	GameManager.stop_song()
	game_active = false
	get_tree().change_scene_to_file("res://scenes/victory.tscn")


func show_command_feedback(message: String) -> void:
	if hud_instance != null and hud_instance.has_method("show_command_feedback"):
		hud_instance.show_command_feedback(message)


func show_tutorial_hint(message: String) -> void:
	if hud_instance != null and hud_instance.has_method("show_tutorial_hint"):
		hud_instance.show_tutorial_hint(message)


func _setup_shop_menu() -> void:
	shop_open = false
	shop_menu.visible = false
	shop_message_label.text = ""
	shop_index = 0
	_update_shop_label()


func _bind_joystick_events() -> void:
	if joystick_controller == null:
		return

	if joystick_controller.has_signal("combo_triggered"):
		joystick_controller.combo_triggered.connect(_on_combo_triggered)
	if joystick_controller.has_signal("action_pressed"):
		joystick_controller.action_pressed.connect(_on_joystick_action)


func _on_combo_triggered(combo_name: String) -> void:
	if combo_name == "open_menu" or combo_name == "open_radial_menu":
		_toggle_shop_menu()
		return

	if not shop_open:
		return

	if combo_name == "place_tower" or combo_name == "tower_upgrade" or combo_name == "sell_tower":
		_perform_spot_action(combo_name)


func _on_joystick_action(action_name: String) -> void:
	if not shop_open:
		return

	match action_name:
		"left":
			_cycle_shop(-1)
		"right":
			_cycle_shop(1)
		"up", "confirm":
			_perform_spot_action(shop_actions[shop_index])
		"down":
			_toggle_shop_menu(false)


func _toggle_shop_menu(force_state: bool = not shop_open) -> void:
	shop_open = force_state
	shop_menu.visible = shop_open
	shop_message_label.text = ""

	if shop_open:
		_update_shop_label()
		show_command_feedback("Shop open: LEFT/RIGHT choose, UP/CONFIRM apply, DOWN close")
	else:
		show_command_feedback("Shop closed")


func _cycle_shop(direction: int) -> void:
	shop_index = wrapi(shop_index + direction, 0, shop_actions.size())
	_update_shop_label()


func _update_shop_label() -> void:
	if shop_item_label == null:
		return

	var selected_action := shop_actions[shop_index]
	var selected_label := shop_labels[shop_index]
	var details := ""
	match selected_action:
		"place_tower":
			details = "(Cost: 25)"
		"tower_upgrade":
			details = "(Cost: next upgrade)"
		"sell_tower":
			details = "(Refund: 65%)"

	shop_item_label.text = "%s %s" % [selected_label, details]


func _perform_spot_action(action_name: String) -> void:
	var spot := _get_hovered_build_spot()
	if spot == null:
		shop_message_label.text = "Move cursor over build spot"
		show_command_feedback("Hover a build spot before using the shop")
		return

	spot.on_cursor_action(action_name)


func _get_hovered_build_spot() -> Node:
	if joystick_controller == null:
		return null
	if joystick_controller.has_method("get_hovered_build_spot"):
		return joystick_controller.get_hovered_build_spot()
	return null
