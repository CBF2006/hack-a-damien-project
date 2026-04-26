extends Node

signal health_changed(current: int, maximum: int)
signal game_over_triggered
signal victory_triggered

const HP_LOSS_PER_ENEMY: int = 2
const VICTORY_WAVE: int = 10

var player_health: int = 20
var max_health: int = 20
var difficulty: int = 1
var _ended: bool = false

func setup(diff: int) -> void:
	difficulty = diff
	_ended = false
	match difficulty:
		0: max_health = 30
		1: max_health = 20
		2: max_health = 10
	player_health = max_health
	health_changed.emit(player_health, max_health)

func enemy_reached_end() -> void:
	if _ended:
		return
	player_health = max(0, player_health - HP_LOSS_PER_ENEMY)
	health_changed.emit(player_health, max_health)
	if player_health <= 0:
		_ended = true
		game_over_triggered.emit()

func check_victory(wave: int) -> void:
	if _ended:
		return
	if wave > VICTORY_WAVE:
		_ended = true
		victory_triggered.emit()

func reset() -> void:
	_ended = false
	player_health = max_health
	health_changed.emit(player_health, max_health)
