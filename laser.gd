extends Area2D

var target = null
var speed = 300.0
var damage = 10

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta):
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	var dir = (target.global_position - global_position).normalized()
	global_position += dir * speed * delta

func _on_body_entered(body):
	if target == null:
		return

	if body == target:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		elif body.get_parent() != null and body.get_parent().has_method("take_damage"):
			body.get_parent().take_damage(damage)
		queue_free()
