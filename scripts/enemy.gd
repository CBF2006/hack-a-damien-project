extends Node2D

@export var speed = 50.0
@export var max_hp: int = 10
@export var kill_reward: int = 12
var current_hp: int

func _ready() -> void:
	current_hp = max_hp

func _process(delta):
	var follow = get_parent()
	follow.progress += speed * delta

	if follow.progress_ratio >= 1.0:
		var game = get_tree().get_root().get_node_or_null("game")
		GameManager.enemy_reached_end()
		if is_instance_valid(game):
			game.enemies_died()
		follow.queue_free()

func take_damage(amount: int) -> void:
	if current_hp <= 0:
		return
	current_hp -= amount
	if current_hp <= 0:
		_die()

func _die() -> void:
	GameManager.play_song(GameManager.SONG_KILL)
	GameManager.add_money(kill_reward)
	var game = get_tree().get_root().get_node_or_null("game")
	if game:
		game.enemies_died()
	var follow = get_parent()
	if is_instance_valid(follow):
		follow.queue_free()
