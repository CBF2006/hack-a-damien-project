extends PathFollow2D

@export var speed = 50.0

func _ready() -> void:
	loop = false

func _process(delta: float) -> void:
	progress += speed * delta
	if progress_ratio >= 1.0:
		GameManager.take_damage(2)
		queue_free()
