extends CharacterBody2D

@export var speed: float = 50.0

func _process(delta: float) -> void:
	# Parent chain: CharacterBody2D → Enemy (Node2D) → PathFollow2D
	var follow: PathFollow2D = get_parent().get_parent()
	follow.progress += speed * delta

	if follow.progress_ratio >= 1.0:
		# Resolve game reference before enemy_reached_end() may trigger a scene change
		var game: Node = get_tree().get_root().get_node_or_null("game")
		GameManager.enemy_reached_end()
		if is_instance_valid(game):
			game.enemies_died()
		follow.queue_free()
