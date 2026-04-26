extends Node2D

@export var speed := 50.0
@export var max_health := 60.0
@export var reward := 12

var health := 0.0
var _slow_multiplier := 1.0
var _slow_seconds_left := 0.0

func _ready() -> void:
	add_to_group("enemy")
	health = max_health

func _process(delta: float) -> void:
	if _slow_seconds_left > 0.0:
		_slow_seconds_left -= delta
		if _slow_seconds_left <= 0.0:
			_slow_multiplier = 1.0

	var follow = get_parent()
	follow.progress += speed * _slow_multiplier * delta

	if follow.progress_ratio >= 1.0:
		var game_root = get_tree().get_first_node_in_group("game_root")
		if game_root != null and game_root.has_method("on_enemy_reached_end"):
			game_root.on_enemy_reached_end()
		follow.queue_free()

func apply_damage(value: float) -> void:
	health -= value
	if health <= 0.0:
		_die()

func apply_slow(multiplier: float, duration_seconds: float) -> void:
	_slow_multiplier = min(_slow_multiplier, multiplier)
	_slow_seconds_left = max(_slow_seconds_left, duration_seconds)

func _die() -> void:
	var game_root = get_tree().get_first_node_in_group("game_root")
	if game_root != null and game_root.has_method("on_enemy_killed"):
		game_root.on_enemy_killed(reward)
	get_parent().queue_free()
