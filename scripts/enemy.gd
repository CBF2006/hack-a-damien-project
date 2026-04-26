extends Node2D

<<<<<<< Updated upstream
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
=======
@export var speed = 50.0
@export var max_hp: int = 10
@export var kill_reward: int = 12
var current_hp: int
var _is_elite: bool = false
var _elite_reward_bonus: int = 8

func _ready() -> void:
	current_hp = max_hp
	if _is_elite:
		scale = Vector2.ONE * 1.08
>>>>>>> Stashed changes

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
<<<<<<< Updated upstream
	var game_root = get_tree().get_first_node_in_group("game_root")
	if game_root != null and game_root.has_method("on_enemy_killed"):
		game_root.on_enemy_killed(reward)
	get_parent().queue_free()
=======
	GameManager.play_song(GameManager.SONG_KILL)
	var reward := kill_reward
	if _is_elite:
		reward += _elite_reward_bonus
	GameManager.add_money(reward)
	var game = get_tree().get_root().get_node_or_null("game")
	if game:
		game.enemies_died()
	var follow = get_parent()
	if is_instance_valid(follow):
		follow.queue_free()


func configure_enemy(config: Dictionary) -> void:
	var hp_mult := float(config.get("hp_multiplier", 1.0))
	var speed_mult := float(config.get("speed_multiplier", 1.0))
	var reward_mult := float(config.get("reward_multiplier", 1.0))
	var elite := bool(config.get("is_elite", false))

	max_hp = max(1, int(round(float(max_hp) * hp_mult)))
	current_hp = max_hp
	speed = max(1.0, speed * speed_mult)
	kill_reward = max(1, int(round(float(kill_reward) * reward_mult)))

	_is_elite = elite
	if _is_elite:
		max_hp = int(round(max_hp * 1.45))
		current_hp = max_hp
		speed *= 1.08
		kill_reward = int(round(kill_reward * 1.35))
>>>>>>> Stashed changes
