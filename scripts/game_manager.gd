extends Node

signal health_changed(current: int, maximum: int)
signal money_changed(current: int)
signal game_over_triggered
signal victory_triggered

const HP_LOSS_PER_ENEMY: int = 2
const VICTORY_WAVE: int = 10
const STARTING_MONEY_EASY: int = 220
const STARTING_MONEY_NORMAL: int = 160
const STARTING_MONEY_HARD: int = 120

var player_health: int = 20
var max_health: int = 20
var player_money: int = STARTING_MONEY_NORMAL
var difficulty: int = 1
var _ended: bool = false

func setup(diff: int) -> void:
	difficulty = diff
	_ended = false
	match difficulty:
		0:
			max_health = 30
			player_money = STARTING_MONEY_EASY
		1:
			max_health = 20
			player_money = STARTING_MONEY_NORMAL
		2:
			max_health = 10
			player_money = STARTING_MONEY_HARD
	player_health = max_health
	health_changed.emit(player_health, max_health)
	money_changed.emit(player_money)

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
	money_changed.emit(player_money)


func can_spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	return player_money >= amount


func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_spend_money(amount):
		return false
	player_money -= amount
	money_changed.emit(player_money)
	return true


func try_spend_money(amount: int) -> bool:
	return spend_money(amount)


func refund_money(amount: int) -> void:
	if amount <= 0:
		return
	player_money += amount
	money_changed.emit(player_money)


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	player_money += amount
	money_changed.emit(player_money)


#new joystick stuff
# ─── Song IDs (must match buzzer.h on the MSP430) ─────────────────────────────
const SONG_NONE       := 0
const SONG_MAIN       := 1
const SONG_PLACE      := 2
const SONG_UPGRADE    := 3
const SONG_SELL       := 4
const SONG_WAVE_START := 5
const SONG_GAMEOVER   := 6
const SONG_KILL       := 7

# ─── MSP430 buzzer / LCD passthrough ──────────────────────────────────────────
# These look up the JoystickController (which holds the open TCP connection
# to the Python serial bridge) and forward the call. If the controller isn't
# in the scene yet (e.g. on the main menu), the call is a silent no-op.

func play_song(id: int) -> void:
	var jc := get_tree().get_first_node_in_group("joystick_controller")
	if jc != null:
		jc.serial_play_song(id)

func stop_song() -> void:
	play_song(SONG_NONE)

func set_lcd(id: int) -> void:
	var jc := get_tree().get_first_node_in_group("joystick_controller")
	if jc != null:
		jc.serial_set_lcd(id)
