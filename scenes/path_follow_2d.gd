extends PathFollow2D

@export var speed = 50.0

func _process(delta):
	progress += speed * delta
