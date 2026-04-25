extends Node2D

@export var fire_rate = 1.5
var target = null
var timer = 0.0

func _process(delta):
	timer += delta
	if target and timer >= fire_rate:
		shoot()
		timer = 0.0

func shoot():
	print("Shooting enemy!")

func _on_area_2d_body_entered(body):
	target = body

func _on_area_2d_body_exited(body):
	if body == target:
		target = null
