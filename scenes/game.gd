extends Node2D

@export var enemy_scene : PackedScene
var wave = 1
var enemies_to_spawn = 5
var spawn_delay = 2

func _ready():
	start_wave()

func start_wave():
	for i in range(enemies_to_spawn):
		spawn_enemy()
		await get_tree().create_timer(spawn_delay).timeout

func spawn_enemy():
	var follow = PathFollow2D.new()
	follow.loop = false        # ← stops repeating
	$Path2D.add_child(follow)
	
	var enemy = enemy_scene.instantiate()
	follow.add_child(enemy)
