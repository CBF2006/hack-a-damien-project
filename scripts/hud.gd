extends CanvasLayer

@onready var health_label: Label = $HealthLabel

func _ready() -> void:
	health_label.text = "Health: %d" % GameManager.player_health
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.game_over.connect(_on_game_over)

func _on_health_changed(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health

func _on_game_over() -> void:
	get_tree().change_scene_to_file("res://scenes/mainMenu.tscn")
