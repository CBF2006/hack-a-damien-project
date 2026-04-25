extends Node2D

@export var speed = 50.0

func _process(delta):
	var follow = get_parent()
	follow.progress += speed * delta
	
	if follow.progress_ratio >= 1.0:
		get_tree().get_root().get_node("game").enemies_died()
		follow.queue_free()
