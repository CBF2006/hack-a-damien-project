extends Node2D
class_name TowerSpot

@export var radius := 30.0

var tower: Node2D = null
var detector: Area2D

func _ready() -> void:
	add_to_group("tower_spot")
	_ensure_detector()

func _ensure_detector() -> void:
	detector = get_node_or_null("SpotDetector")
	if detector == null:
		detector = Area2D.new()
		detector.name = "SpotDetector"
		detector.collision_layer = 2
		detector.collision_mask = 0
		add_child(detector)

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		detector.add_child(shape)

	if not detector.is_in_group("cursor_tower_spot"):
		detector.add_to_group("cursor_tower_spot")

func is_empty() -> bool:
	return tower == null or not is_instance_valid(tower)

func set_tower(value: Node2D) -> void:
	tower = value

func clear_tower() -> void:
	tower = null
