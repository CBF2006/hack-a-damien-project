extends Node2D

@export var enemy_scene : PackedScene
var wave = 1
var enemies_to_spawn = 5
var spawn_delay = 2
var enemies_alive = 0
var time_between_waves = 5

func _ready():
	start_wave()

func start_wave():
	print("Wave: ", wave) # TODO: REPLACE WITH GUI
	enemies_alive = enemies_to_spawn
	
	for i in range(enemies_to_spawn):
		spawn_enemy()
		await get_tree().create_timer(spawn_delay).timeout

func spawn_enemy():
	var follow = PathFollow2D.new()
	follow.loop = false # Stops it from spawning
	$Path2D.add_child(follow)
	
	var enemy = enemy_scene.instantiate()
	follow.add_child(enemy)

func enemies_died():
	enemies_alive -= 1
	if enemies_alive <= 0:
		wave += 1
		enemies_to_spawn += 1 # Add 5 enemies next wave
		await get_tree().create_timer(time_between_waves).timeout # Wait pre-determined time bwtween waves
		start_wave()
