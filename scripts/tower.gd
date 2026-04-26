extends Node2D

<<<<<<< Updated upstream
@export var base_damage := 14.0
@export var base_range := 140.0
@export var base_fire_rate := 1.2
@export var base_max_health := 120.0
@export var base_sell_value := 30
=======
@export var base_damage: int = 2
@export var base_range: float = 98.0
@export var base_fire_rate: float = 1.5
@export var base_health: int = 20

# Branch upgrade settings.
@export var path_max_level: int = 3
@export var path_a_upgrade_costs: Array[int] = [45, 80, 130]
@export var path_b_upgrade_costs: Array[int] = [40, 75, 120]

@export var path_a_damage_per_level: float = 2.2
@export var path_a_fire_rate_reduction_per_level: float = 0.14
@export var path_a_range_per_level: float = 6.0

@export var path_b_range_per_level: float = 20.0
@export var path_b_health_per_level: int = 14
@export var path_b_fire_rate_reduction_per_level: float = 0.05
>>>>>>> Stashed changes

var damage := 0.0
var range := 0.0
var fire_rate := 0.0
var max_health := 0.0
var health := 0.0
var sell_value := 0

<<<<<<< Updated upstream
var _variant := "base"
var _level := 1
var _timer := 0.0
var _boost_multiplier := 1.0
var _boost_seconds_left := 0.0
=======
const PATH_A := "path_a"
const PATH_B := "path_b"

var damage: int = 2
var fire_rate: float = 1.5
var tower_range: float = 98.0
var max_health: int = 20
var current_health: int = 20
var level: int = 0
var path_a_level: int = 0
var path_b_level: int = 0
var locked_path: String = ""
var total_invested: int = 25
>>>>>>> Stashed changes

var _spot: Node = null
var _targets: Array = []

@onready var _range_area: Area2D = $Area2D
@onready var _range_shape: CollisionShape2D = $Area2D/DetectionRange

func _ready() -> void:
<<<<<<< Updated upstream
	add_to_group("tower")
	damage = base_damage
	range = base_range
	fire_rate = base_fire_rate
	max_health = base_max_health
	health = max_health
	sell_value = base_sell_value
	_apply_range_shape()
	_ensure_cursor_target_area()
=======
	_apply_stats()


func configure_tower(initial_investment: int = 25) -> void:
	level = 0
	path_a_level = 0
	path_b_level = 0
	locked_path = ""
	total_invested = max(0, initial_investment)
	current_health = base_health
	_apply_stats(true)


func set_spawned_from_spot(_spot: Node) -> void:
	pass


func upgrade_tower() -> bool:
	if locked_path == PATH_A:
		return upgrade_tower_path(PATH_A)
	if locked_path == PATH_B:
		return upgrade_tower_path(PATH_B)
	return upgrade_tower_path(PATH_A)


func can_upgrade_path(path_name: String) -> bool:
	if not _is_valid_path(path_name):
		return false
	if _is_path_locked_for(path_name):
		return false
	return _get_path_level(path_name) < path_max_level


func get_upgrade_cost_for_path(path_name: String) -> int:
	if not can_upgrade_path(path_name):
		return -1

	var lvl := _get_path_level(path_name)
	if path_name == PATH_A:
		if lvl < path_a_upgrade_costs.size():
			return int(path_a_upgrade_costs[lvl])
		return -1

	if lvl < path_b_upgrade_costs.size():
		return int(path_b_upgrade_costs[lvl])
	return -1


func upgrade_tower_path(path_name: String) -> bool:
	if not can_upgrade_path(path_name):
		return false

	var next_cost := get_upgrade_cost_for_path(path_name)
	if next_cost <= 0:
		return false

	total_invested += next_cost
	if path_name == PATH_A:
		path_a_level += 1
	else:
		path_b_level += 1

	if locked_path == "":
		locked_path = path_name

	level = path_a_level + path_b_level
	_apply_stats(true)
	return true


func get_upgrade_preview(path_name: String) -> Dictionary:
	var result := {
		"path": path_name,
		"can_upgrade": false,
		"reason": "invalid_path",
		"next_cost": -1,
		"next_level": _get_path_level(path_name),
		"locked_path": locked_path,
	}

	if not _is_valid_path(path_name):
		return result

	if _is_path_locked_for(path_name):
		result.reason = "path_locked"
		return result

	var curr_level := _get_path_level(path_name)
	if curr_level >= path_max_level:
		result.reason = "path_maxed"
		return result

	var next_cost := get_upgrade_cost_for_path(path_name)
	if next_cost <= 0:
		result.reason = "missing_cost"
		return result

	result.can_upgrade = true
	result.reason = "ok"
	result.next_cost = next_cost
	result.next_level = curr_level + 1
	return result


func get_tower_status_summary() -> Dictionary:
	return {
		"level": level,
		"path_a_level": path_a_level,
		"path_b_level": path_b_level,
		"path_max_level": path_max_level,
		"locked_path": locked_path,
		"damage": damage,
		"fire_rate": fire_rate,
		"range": tower_range,
		"health": current_health,
		"max_health": max_health,
		"sell_refund": get_sell_refund(),
	}


# Returns cost of next upgrade, or -1 if already maxed.
func get_upgrade_cost() -> int:
	if locked_path == PATH_B:
		return get_upgrade_cost_for_path(PATH_B)
	return get_upgrade_cost_for_path(PATH_A)


func get_path_level(path_name: String) -> int:
	return _get_path_level(path_name)


func get_locked_path() -> String:
	return locked_path


func get_sell_refund() -> int:
	return int(total_invested * 0.65)


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	if current_health == 0:
		queue_free()

>>>>>>> Stashed changes

func _process(delta: float) -> void:
	_timer += delta
	if _boost_seconds_left > 0.0:
		_boost_seconds_left -= delta
		if _boost_seconds_left <= 0.0:
			_boost_multiplier = 1.0

	if _timer < _effective_fire_rate():
		return

	var target = _get_valid_target()
	if target == null:
		return

	shoot(target)
	_timer = 0.0

func shoot(enemy: Node) -> void:
	if enemy != null and enemy.has_method("apply_damage"):
		enemy.apply_damage(_effective_damage())

<<<<<<< Updated upstream
func set_variant(variant_name: String) -> void:
	_variant = variant_name
	match variant_name:
		"fast":
			damage *= 0.75
			fire_rate *= 0.6
			range *= 0.85
			health *= 0.9
		"sniper":
			damage *= 1.7
			fire_rate *= 1.8
			range *= 1.5
			health *= 0.85
		"defensive":
			damage *= 0.9
			fire_rate *= 1.0
			range *= 0.9
			max_health *= 1.7
			health = max_health
		_:
			pass
	_apply_range_shape()
=======
func _apply_stats(reset_health: bool = false) -> void:
	# Path A specializes in damage/DPS, Path B in range/survivability.
	var damage_bonus := int(round(path_a_level * path_a_damage_per_level))
	var range_bonus := (path_a_level * path_a_range_per_level) + (path_b_level * path_b_range_per_level)
	var fire_rate_bonus := (path_a_level * path_a_fire_rate_reduction_per_level) + (path_b_level * path_b_fire_rate_reduction_per_level)
	var health_bonus := path_b_level * path_b_health_per_level

	damage = max(1, base_damage + damage_bonus)
	tower_range = base_range + range_bonus
	fire_rate = max(0.25, base_fire_rate - fire_rate_bonus)
	max_health = base_health + health_bonus
	if reset_health:
		current_health = max_health
	if sprite != null:
		sprite.frame = min(level, 2)
		sprite.scale = Vector2.ONE * (1.0 + (0.06 * level))
	if detection_area != null:
		var shape := detection_area.get_node_or_null("DetectionRange")
		if shape is CollisionShape2D and shape.shape is CircleShape2D:
			(shape.shape as CircleShape2D).radius = tower_range
>>>>>>> Stashed changes

func upgrade_tower() -> void:
	_level += 1
	damage *= 1.22
	range *= 1.06
	fire_rate *= 0.92
	max_health *= 1.15
	health = min(max_health, health + max_health * 0.15)
	sell_value = int(round(float(sell_value) * 1.35))
	_apply_range_shape()

<<<<<<< Updated upstream
func add_shield() -> void:
	max_health += 25.0
	health = min(max_health, health + 35.0)
=======
func _is_valid_path(path_name: String) -> bool:
	return path_name == PATH_A or path_name == PATH_B


func _is_path_locked_for(path_name: String) -> bool:
	return locked_path != "" and locked_path != path_name


func _get_path_level(path_name: String) -> int:
	if path_name == PATH_A:
		return path_a_level
	if path_name == PATH_B:
		return path_b_level
	return 0


func _refresh_target() -> void:
	_targets = _targets.filter(func(candidate: Node2D) -> bool:
		return is_instance_valid(candidate)
	)
>>>>>>> Stashed changes

func repair_tower() -> void:
	health = max_health

func apply_temp_boost(duration_seconds: float, multiplier: float) -> void:
	_boost_seconds_left = max(_boost_seconds_left, duration_seconds)
	_boost_multiplier = max(_boost_multiplier, multiplier)

func get_sell_value() -> int:
	return sell_value

func set_spot(new_spot: Node) -> void:
	if _spot != null and _spot.has_method("clear_tower"):
		_spot.clear_tower()
	_spot = new_spot
	if _spot != null and _spot.has_method("set_tower"):
		_spot.set_tower(self)

func remove_from_spot() -> void:
	if _spot != null and _spot.has_method("clear_tower"):
		_spot.clear_tower()
	_spot = null

func _effective_damage() -> float:
	return damage * _boost_multiplier

func _effective_fire_rate() -> float:
	return max(0.08, fire_rate / _boost_multiplier)

func _apply_range_shape() -> void:
	if _range_shape == null:
		return
	if _range_shape.shape is CircleShape2D:
		(_range_shape.shape as CircleShape2D).radius = range

func _get_valid_target() -> Node:
	_targets = _targets.filter(func(t): return t != null and is_instance_valid(t))
	if _targets.is_empty():
		return null

	var closest: Node = null
	var best_distance := INF
	for target in _targets:
		var dist := global_position.distance_squared_to(target.global_position)
		if dist < best_distance:
			best_distance = dist
			closest = target

	return closest

func _on_area_2d_body_entered(body: Node) -> void:
	var enemy = _extract_enemy_from_body(body)
	if enemy != null and not _targets.has(enemy):
		_targets.append(enemy)

func _on_area_2d_body_exited(body: Node) -> void:
	var enemy = _extract_enemy_from_body(body)
	if enemy != null:
		_targets.erase(enemy)

func _extract_enemy_from_body(body: Node) -> Node:
	if body == null:
		return null
	if body.is_in_group("enemy"):
		return body
	var maybe_parent = body.get_parent()
	if maybe_parent != null and maybe_parent.is_in_group("enemy"):
		return maybe_parent
	return null

func _ensure_cursor_target_area() -> void:
	var cursor_area = get_node_or_null("CursorTarget")
	if cursor_area == null:
		cursor_area = Area2D.new()
		cursor_area.name = "CursorTarget"
		cursor_area.collision_layer = 2
		cursor_area.collision_mask = 0
		add_child(cursor_area)

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 22.0
		shape.shape = circle
		cursor_area.add_child(shape)

	if not cursor_area.is_in_group("cursor_tower_target"):
		cursor_area.add_to_group("cursor_tower_target")
	cursor_area.set_meta("tower_ref", self)
