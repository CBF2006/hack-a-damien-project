extends Node2D

const TowerSpot = preload("res://scripts/tower_spot.gd")

@export var enemy_scene: PackedScene
@export var tower_scene: PackedScene
@export var joystick_scene: PackedScene

@export var start_currency := 150
@export var passive_currency_gain := 10

@export var base_tower_cost := 50
@export var fast_tower_cost := 70
@export var sniper_tower_cost := 80
@export var defensive_tower_cost := 65

<<<<<<< Updated upstream
@export var wave := 1
@export var enemies_to_spawn := 5
@export var spawn_delay := 2.0
@export var time_between_waves := 5.0
=======
var shop_open: bool = false
var shop_index: int = 0
var shop_actions: Array[String] = ["place_tower", "tower_upgrade_path_a", "tower_upgrade_path_b", "sell_tower"]
var shop_labels: Array[String] = ["Build Tower", "Upgrade Path A", "Upgrade Path B", "Sell Tower"]
var _last_shop_hovered_spot_id: int = -1
>>>>>>> Stashed changes

@export var tower_spot_positions := PackedVector2Array(
	Vector2(448, 320),
	Vector2(608, 295),
	Vector2(777, 365),
	Vector2(878, 255)
)

var currency := 0
var enemies_alive := 0
var _wave_running := false
var _last_hover_context := "global"

func _ready() -> void:
<<<<<<< Updated upstream
	if enemy_scene == null:
		enemy_scene = preload("res://scenes/enemy.tscn")
	if tower_scene == null:
		tower_scene = preload("res://scenes/tower.tscn")
	add_to_group("game_root")
	currency = start_currency
	_setup_joystick()
	_setup_tower_spots()
	_register_existing_towers()
=======
	hud_instance = hud_scene.instantiate()
	add_child(hud_instance)
	_setup_shop_menu()
	_bind_joystick_events()
	_set_action_mode_ui(false)

	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.victory_triggered.connect(_on_victory)
	show_tutorial_hint("Button: toggle Action Mode. Up-Up build, Up-Down Path A, Down-Up Path B, Down-Down-Down sell.")
	
>>>>>>> Stashed changes
	start_wave()
	_print_currency()

func _setup_joystick() -> void:
	if joystick_scene == null:
		joystick_scene = preload("res://scenes/ui/joystick_controller.tscn")
	var joystick = joystick_scene.instantiate()
	add_child(joystick)
	joystick.hover_context_changed.connect(_on_hover_context_changed)
	joystick.command_mode_changed.connect(_on_command_mode_changed)
	joystick.combo_buffer_changed.connect(_on_combo_buffer_changed)
	joystick.combo_result.connect(_on_combo_result)

func _setup_tower_spots() -> void:
	for existing in get_tree().get_nodes_in_group("tower_spot"):
		if existing.get_parent() == self:
			existing.queue_free()

	for position_2d in tower_spot_positions:
		var spot := TowerSpot.new()
		spot.position = position_2d
		add_child(spot)

func _register_existing_towers() -> void:
	for child in get_children():
		if child.has_method("set_spot"):
			var closest_spot = _find_closest_empty_spot(child.global_position, true)
			if closest_spot != null:
				closest_spot.set_tower(child)
				child.set_spot(closest_spot)


func _process(_delta: float) -> void:
	if not shop_open:
		return

	var spot := _get_hovered_build_spot()
	var spot_id := -1
	if spot != null:
		spot_id = int(spot.get_instance_id())

	if spot_id != _last_shop_hovered_spot_id:
		_last_shop_hovered_spot_id = spot_id
		_update_shop_label()

func start_wave() -> void:
	if _wave_running:
		return
<<<<<<< Updated upstream
	_wave_running = true
=======
	hud_instance.set_wave(wave)
	show_tutorial_hint("Action Mode combos or shop both work. Use button to enter/exit mode.")
>>>>>>> Stashed changes
	enemies_alive = enemies_to_spawn
	print("Wave: ", wave)

<<<<<<< Updated upstream
	for _i in range(enemies_to_spawn):
		spawn_enemy()
=======
	var elite_count := _get_wave_elite_count()
	for i in range(enemies_to_spawn):
		if not game_active:
			return
		var is_elite := i < elite_count
		spawn_enemy(is_elite)
>>>>>>> Stashed changes
		await get_tree().create_timer(spawn_delay).timeout

func spawn_enemy(is_elite: bool = false) -> void:
	var follow := PathFollow2D.new()
	follow.loop = false
	$Path2D.add_child(follow)

<<<<<<< Updated upstream
	var enemy = enemy_scene.instantiate()
=======
	var enemy := enemy_scene.instantiate()
	if enemy != null and enemy.has_method("configure_enemy"):
		enemy.configure_enemy(_build_enemy_config(is_elite))
>>>>>>> Stashed changes
	follow.add_child(enemy)

func on_enemy_killed(reward: int) -> void:
	enemies_alive -= 1
	currency += reward
	_print_currency()
	_try_finish_wave()

func on_enemy_reached_end() -> void:
	enemies_alive -= 1
	_try_finish_wave()

<<<<<<< Updated upstream
func _try_finish_wave() -> void:
	if enemies_alive > 0:
=======
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
	_last_shop_hovered_spot_id = -1
	_update_shop_label()


func _bind_joystick_events() -> void:
	if joystick_controller == null:
>>>>>>> Stashed changes
		return
	_wave_running = false
	wave += 1
	enemies_to_spawn += 1
	await get_tree().create_timer(time_between_waves).timeout
	start_wave()

<<<<<<< Updated upstream
func handle_combo_request(combo_key: String, context_kind: String, spot: Node, tower: Node) -> bool:
	match context_kind:
		"build":
			return _handle_build_combo(combo_key, spot)
		"tower":
			return _handle_tower_combo(combo_key, tower)
		_:
			return _handle_global_combo(combo_key)
=======
	if joystick_controller.has_signal("combo_triggered"):
		joystick_controller.combo_triggered.connect(_on_combo_triggered)
	if joystick_controller.has_signal("action_pressed"):
		joystick_controller.action_pressed.connect(_on_joystick_action)
	if joystick_controller.has_signal("action_mode_toggled"):
		joystick_controller.action_mode_toggled.connect(_on_action_mode_toggled)
>>>>>>> Stashed changes

func _handle_build_combo(combo_key: String, spot: Node) -> bool:
	if spot == null or not spot.has_method("is_empty") or not spot.is_empty():
		return false

	match combo_key:
		"U":
			return _build_tower(spot, "base", base_tower_cost)
		"U>R":
			return _build_tower(spot, "fast", fast_tower_cost)
		"U>L":
			return _build_tower(spot, "sniper", sniper_tower_cost)
		"D":
			return _build_tower(spot, "defensive", defensive_tower_cost)
		_:
			return false

func _handle_tower_combo(combo_key: String, tower: Node) -> bool:
	if tower == null:
		return false

	match combo_key:
		"U>U":
			if tower.has_method("upgrade_tower"):
				tower.upgrade_tower()
				return true
		"D":
			if tower.has_method("add_shield"):
				tower.add_shield()
				return true
		"L":
			return _sell_tower(tower)
		"L>R":
			return _relocate_tower(tower)
		"D>U":
			if tower.has_method("repair_tower"):
				tower.repair_tower()
				return true
		"R>R":
			if tower.has_method("apply_temp_boost"):
				tower.apply_temp_boost(4.0, 1.35)
				return true

	return false

func _handle_global_combo(combo_key: String) -> bool:
	match combo_key:
		"R":
			currency += passive_currency_gain
			_print_currency()
			return true
		"R>R":
			for tower in get_tree().get_nodes_in_group("tower"):
				if tower.has_method("apply_temp_boost"):
					tower.apply_temp_boost(3.0, 1.2)
			return true
		"D>D":
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.6, 2.0)
			return true
		_:
			return false

func _build_tower(spot: Node, variant: String, cost: int) -> bool:
	if currency < cost:
		return false

	currency -= cost
	var tower = tower_scene.instantiate()
	add_child(tower)
	tower.global_position = spot.global_position
	if tower.has_method("set_spot"):
		tower.set_spot(spot)
	if tower.has_method("set_variant"):
		tower.set_variant(variant)
	if spot.has_method("set_tower"):
		spot.set_tower(tower)
	_print_currency()
	return true

func _sell_tower(tower: Node) -> bool:
	if not tower.has_method("get_sell_value"):
		return false

	currency += tower.get_sell_value()
	if tower.has_method("remove_from_spot"):
		tower.remove_from_spot()
	tower.queue_free()
	_print_currency()
	return true

func _relocate_tower(tower: Node) -> bool:
	var target_spot = _find_closest_empty_spot(tower.global_position, false)
	if target_spot == null:
		return false

	if tower.has_method("set_spot"):
		tower.set_spot(target_spot)
	tower.global_position = target_spot.global_position
	return true

func _find_closest_empty_spot(from_position: Vector2, include_occupied: bool) -> Node:
	var closest: Node = null
	var best_distance := INF

	for spot in get_tree().get_nodes_in_group("tower_spot"):
		if not include_occupied and spot.has_method("is_empty") and not spot.is_empty():
			continue
		var distance := from_position.distance_squared_to(spot.global_position)
		if distance < best_distance:
			best_distance = distance
			closest = spot

	return closest

func _print_currency() -> void:
	print("Currency: ", currency)

func _on_hover_context_changed(context_kind: String) -> void:
	if _last_hover_context == context_kind:
		return
	_last_hover_context = context_kind
	print("Hover context: ", context_kind)

<<<<<<< Updated upstream
func _on_command_mode_changed(active: bool, seconds_left: float) -> void:
	if active:
		print("Command mode: ", snapped(seconds_left, 0.01))

func _on_combo_buffer_changed(trail_text: String) -> void:
	if trail_text.is_empty():
=======
	if combo_name != "place_tower" and combo_name != "tower_upgrade" and combo_name != "tower_upgrade_path_a" and combo_name != "tower_upgrade_path_b" and combo_name != "sell_tower":
>>>>>>> Stashed changes
		return
	print("Trail: ", trail_text)

<<<<<<< Updated upstream
func _on_combo_result(success: bool, context_kind: String, combo_key: String) -> void:
	if success:
		print("Combo success [", context_kind, "]: ", combo_key)
	else:
		print("Combo failed [", context_kind, "]: ", combo_key)
=======
	if not _is_action_mode_enabled():
		show_command_feedback("Enter Action Mode first")
		return

	var result := _perform_spot_action(combo_name)
	if bool(result.get("success", false)):
		_set_action_mode_enabled(false, "Action complete")


func _on_joystick_action(action_name: String) -> void:
	match action_name:
		"left":
			if shop_open:
				_cycle_shop(-1)
		"right":
			if shop_open:
				_cycle_shop(1)
		"confirm", "up":
			_handle_confirm()
		"down":
			if shop_open:
				_toggle_shop_menu(false)


func _on_action_mode_toggled(enabled: bool) -> void:
	_set_action_mode_ui(enabled)


func _handle_confirm() -> void:
	if shop_open:
		var result := _perform_spot_action(shop_actions[shop_index])
		if bool(result.get("success", false)):
			_toggle_shop_menu(false)
			_set_action_mode_enabled(false, "Action complete")
		return

	if _is_action_mode_enabled():
		_set_action_mode_enabled(false, "Action mode canceled")
	else:
		_set_action_mode_enabled(true, "Action mode active")


func _toggle_shop_menu(force_state: bool = not shop_open) -> void:
	shop_open = force_state
	shop_menu.visible = shop_open
	shop_message_label.text = ""
	_last_shop_hovered_spot_id = -1

	if shop_open:
		_update_shop_label()
		show_command_feedback("Shop: LEFT/RIGHT choose, CONFIRM apply, DOWN close")
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
	var spot := _get_hovered_build_spot()
	var context := _get_shop_action_context(spot, selected_action)
	var detail := str(context.get("detail", ""))
	var enabled := bool(context.get("enabled", false))

	if detail == "":
		shop_item_label.text = selected_label
	else:
		shop_item_label.text = "%s - %s" % [selected_label, detail]

	shop_item_label.modulate = Color(0.95, 0.95, 0.95) if enabled else Color(0.95, 0.65, 0.65)


func _perform_spot_action(action_name: String) -> Dictionary:
	var spot := _get_hovered_build_spot()
	if spot == null:
		shop_message_label.text = "Move cursor over build spot"
		show_command_feedback("Hover a build spot before using the shop")
		return {"success": false, "reason": "no_spot", "message": "Move cursor over build spot"}

	if not spot.has_method("on_cursor_action"):
		shop_message_label.text = "Invalid build spot"
		show_command_feedback("Build spot missing action handler")
		return {"success": false, "reason": "invalid_spot", "message": "Invalid build spot"}

	var result = spot.on_cursor_action(action_name)
	if typeof(result) != TYPE_DICTIONARY:
		result = {"success": true, "reason": "ok", "message": "Action completed"}

	if shop_message_label != null:
		shop_message_label.text = str(result.get("message", ""))

	return result


func _get_hovered_build_spot() -> Node:
	if joystick_controller == null:
		return null
	if joystick_controller.has_method("get_hovered_build_spot"):
		return joystick_controller.get_hovered_build_spot()
	return null


func _is_action_mode_enabled() -> bool:
	if joystick_controller != null and joystick_controller.has_method("is_action_mode_enabled"):
		return joystick_controller.is_action_mode_enabled()
	return false


func _set_action_mode_enabled(enabled: bool, feedback: String = "") -> void:
	if joystick_controller != null and joystick_controller.has_method("set_action_mode_enabled"):
		joystick_controller.set_action_mode_enabled(enabled)

	_set_action_mode_ui(enabled)
	if feedback != "":
		show_command_feedback(feedback)


func _set_action_mode_ui(enabled: bool) -> void:
	if hud_instance != null and hud_instance.has_method("set_action_mode_indicator"):
		hud_instance.set_action_mode_indicator(enabled)


func _get_shop_action_context(spot: Node, action_name: String) -> Dictionary:
	if spot == null:
		return {"enabled": false, "detail": "Hover a build spot"}

	if spot.has_method("get_action_context"):
		return spot.get_action_context(action_name)

	return {"enabled": false, "detail": "Action unavailable"}


func _build_enemy_config(is_elite: bool) -> Dictionary:
	var wave_index: int = max(0, wave - 1)
	var hp_multiplier: float = (1.0 + (0.18 * float(wave_index))) * float(GameManager.get_enemy_hp_multiplier())
	var speed_multiplier: float = min(1.85, (1.0 + (0.06 * float(wave_index))) * float(GameManager.get_enemy_speed_multiplier()))
	var reward_multiplier: float = (1.0 + (0.12 * float(wave_index))) * float(GameManager.get_reward_multiplier())

	return {
		"hp_multiplier": hp_multiplier,
		"speed_multiplier": speed_multiplier,
		"reward_multiplier": reward_multiplier,
		"is_elite": is_elite,
	}


func _get_wave_elite_count() -> int:
	if wave < 3 or wave % 3 != 0:
		return 0

	var extra_elites := 0
	if wave >= 6:
		extra_elites = int((wave - 6) / 3)

	return min(enemies_to_spawn, 1 + extra_elites)
>>>>>>> Stashed changes
