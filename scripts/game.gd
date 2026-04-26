extends Node2D

@export var enemy_scene: PackedScene

var hud_scene: PackedScene = preload("res://scenes/hud.tscn")
var hud_instance: Node

var wave: int = 1
var enemies_to_spawn: int = 5
var spawn_delay: float = 2.0
var enemies_alive: int = 0
var time_between_waves: float = 5.0
var game_active: bool = true

func _ready() -> void:
	hud_instance = hud_scene.instantiate()
	add_child(hud_instance)

	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.victory_triggered.connect(_on_victory)
	show_tutorial_hint("Hover a spot. Up-Up builds. Up-Down upgrades. Down-Down-Down sells.")

	start_wave()

func start_wave() -> void:
	if not game_active:
		return
	hud_instance.set_wave(wave)
	show_tutorial_hint("Build, upgrade, and sell with short joystick combos.")
	enemies_alive = enemies_to_spawn

	for i in range(enemies_to_spawn):
		if not game_active:
			return
		spawn_enemy()
		await get_tree().create_timer(spawn_delay).timeout

func spawn_enemy() -> void:
	var follow := PathFollow2D.new()
	follow.loop = false
	$Path2D.add_child(follow)

	var enemy := enemy_scene.instantiate()
	follow.add_child(enemy)

func enemies_died() -> void:
	if not game_active:
		return
	enemies_alive -= 1
	if enemies_alive == 0:
		wave += 1
		enemies_to_spawn += 1
		GameManager.check_victory(wave)
		if game_active:
			await get_tree().create_timer(time_between_waves).timeout
		if game_active:
			start_wave()

func _on_game_over() -> void:
	game_active = false
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _on_victory() -> void:
	game_active = false
	get_tree().change_scene_to_file("res://scenes/victory.tscn")


func show_command_feedback(message: String) -> void:
	if hud_instance != null and hud_instance.has_method("show_command_feedback"):
		hud_instance.show_command_feedback(message)


func show_tutorial_hint(message: String) -> void:
	if hud_instance != null and hud_instance.has_method("show_tutorial_hint"):
		hud_instance.show_tutorial_hint(message)
