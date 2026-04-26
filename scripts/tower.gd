extends Node2D

@export var fire_rate = 1.5
@export var damage = 10

var projectile_scene = preload("res://scenes/laser.tscn")  # adjust path if needed
var target = null
var timer = 0.0

func _process(delta):
	timer += delta
	if target and timer >= fire_rate:
		shoot()
		timer = 0.0

func shoot():
	var p = projectile_scene.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position
	p.target = target

func _on_area_2d_body_entered(body):
	target = body

func _on_area_2d_body_exited(body):
	if body == target:
		target = null
