extends Node2D

@export var base_damage := 14.0
@export var base_range := 140.0
@export var base_fire_rate := 1.2
@export var base_max_health := 120.0
@export var base_sell_value := 30

var damage := 0.0
var range := 0.0
var fire_rate := 0.0
var max_health := 0.0
var health := 0.0
var sell_value := 0

var _variant := "base"
var _level := 1
var _timer := 0.0
var _boost_multiplier := 1.0
var _boost_seconds_left := 0.0

var _spot: Node = null
var _targets: Array = []

@onready var _range_area: Area2D = $Area2D
@onready var _range_shape: CollisionShape2D = $Area2D/DetectionRange

func _ready() -> void:
	add_to_group("tower")
	damage = base_damage
	range = base_range
	fire_rate = base_fire_rate
	max_health = base_max_health
	health = max_health
	sell_value = base_sell_value
	_apply_range_shape()
	_ensure_cursor_target_area()

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

func upgrade_tower() -> void:
	_level += 1
	damage *= 1.22
	range *= 1.06
	fire_rate *= 0.92
	max_health *= 1.15
	health = min(max_health, health + max_health * 0.15)
	sell_value = int(round(float(sell_value) * 1.35))
	_apply_range_shape()

func add_shield() -> void:
	max_health += 25.0
	health = min(max_health, health + 35.0)

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
