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

@export var wave := 1
@export var enemies_to_spawn := 5
@export var spawn_delay := 2.0
@export var time_between_waves := 5.0

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
	if enemy_scene == null:
		enemy_scene = preload("res://scenes/enemy.tscn")
	if tower_scene == null:
		tower_scene = preload("res://scenes/tower.tscn")
	add_to_group("game_root")
	currency = start_currency
	_setup_joystick()
	_setup_tower_spots()
	_register_existing_towers()
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

func start_wave() -> void:
	if _wave_running:
		return
	_wave_running = true
	enemies_alive = enemies_to_spawn
	print("Wave: ", wave)

	for _i in range(enemies_to_spawn):
		spawn_enemy()
		await get_tree().create_timer(spawn_delay).timeout

func spawn_enemy() -> void:
	var follow := PathFollow2D.new()
	follow.loop = false
	$Path2D.add_child(follow)

	var enemy = enemy_scene.instantiate()
	follow.add_child(enemy)

func on_enemy_killed(reward: int) -> void:
	enemies_alive -= 1
	currency += reward
	_print_currency()
	_try_finish_wave()

func on_enemy_reached_end() -> void:
	enemies_alive -= 1
	_try_finish_wave()

func _try_finish_wave() -> void:
	if enemies_alive > 0:
		return
	_wave_running = false
	wave += 1
	enemies_to_spawn += 1
	await get_tree().create_timer(time_between_waves).timeout
	start_wave()

func handle_combo_request(combo_key: String, context_kind: String, spot: Node, tower: Node) -> bool:
	match context_kind:
		"build":
			return _handle_build_combo(combo_key, spot)
		"tower":
			return _handle_tower_combo(combo_key, tower)
		_:
			return _handle_global_combo(combo_key)

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

func _on_command_mode_changed(active: bool, seconds_left: float) -> void:
	if active:
		print("Command mode: ", snapped(seconds_left, 0.01))

func _on_combo_buffer_changed(trail_text: String) -> void:
	if trail_text.is_empty():
		return
	print("Trail: ", trail_text)

func _on_combo_result(success: bool, context_kind: String, combo_key: String) -> void:
	if success:
		print("Combo success [", context_kind, "]: ", combo_key)
	else:
		print("Combo failed [", context_kind, "]: ", combo_key)
