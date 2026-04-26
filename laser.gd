extends Area2D

var target = null
var speed = 300.0
var damage = 10

func _process(delta):
	if target == null:
		queue_free()
		return
	var dir = (target.global_position - global_position).normalized()
	global_position += dir * speed * delta

func _on_body_entered(body):
	if body == target:
		body.take_damage(damage)
		queue_free()
