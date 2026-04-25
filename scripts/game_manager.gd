extends Node

signal health_changed(new_health: int)
signal game_over

var player_health: int = 100

func new_game() -> void:
	player_health = 100

func take_damage(amount: int) -> void:
	player_health -= amount
	health_changed.emit(player_health)
	if player_health <= 0:
		game_over.emit()
