extends Node2D

@export var base_damage: int = 2
@export var base_range: float = 98.0
@export var base_fire_rate: float = 1.5
@export var base_health: int = 20
@export var range_per_level: float = 14.0
@export var fire_rate_reduction_per_level: float = 0.15
@export var health_per_level: int = 8
@export var max_level: int = 3
@export var upgrade_costs: Array = [50, 100, 200]

var projectile_scene: PackedScene = preload("res://scenes/laser.tscn")

var damage: int = 2
var fire_rate: float = 1.5
var tower_range: float = 98.0
var max_health: int = 20
var current_health: int = 20
var level: int = 0
var total_invested: int = 25

var target: Node2D = null
var timer: float = 0.0
var _targets: Array[Node2D] = []

@onready var detection_area: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_stats()


func configure_tower() -> void:
	level = 0
	total_invested = 25
	current_health = base_health
	_apply_stats(true)


func set_spawned_from_spot(_spot: Node) -> void:
	pass


func upgrade_tower() -> bool:
	if level >= max_level:
		return false
	total_invested += upgrade_costs[level]
	level += 1
	_apply_stats(true)
	return true


# Returns cost of next upgrade, or -1 if already maxed.
func get_upgrade_cost() -> int:
	if level >= max_level:
		return -1
	return upgrade_costs[level]


func get_sell_refund() -> int:
	return int(total_invested * 0.65)


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	if current_health == 0:
		queue_free()


func _process(delta: float) -> void:
	timer += delta
	_refresh_target()

	if target == null:
		return

	if timer >= fire_rate:
		shoot()
		timer = 0.0


func _apply_stats(reset_health: bool = false) -> void:
	# Damage doubles each level: 2 -> 4 -> 8 -> 16
	damage = int(base_damage * pow(2.0, level))
	tower_range = base_range + (range_per_level * level)
	fire_rate = max(0.25, base_fire_rate - (fire_rate_reduction_per_level * level))
	max_health = base_health + (health_per_level * level)
	if reset_health:
		current_health = max_health
	if sprite != null:
		sprite.frame = min(level, 2)
		sprite.scale = Vector2.ONE * (1.0 + (0.05 * level))
	if detection_area != null:
		var shape := detection_area.get_node_or_null("DetectionRange")
		if shape is CollisionShape2D and shape.shape is CircleShape2D:
			(shape.shape as CircleShape2D).radius = tower_range


func _refresh_target() -> void:
	_targets = _targets.filter(func(candidate: Node2D) -> bool:
		return is_instance_valid(candidate)
	)

	if target != null and not is_instance_valid(target):
		target = null

	if target != null:
		return

	var best_target: Node2D = null
	var best_distance := INF
	for candidate in _targets:
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate

	target = best_target


func shoot() -> void:
	if target == null:
		return

	var projectile := projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.target = target
	projectile.set("damage", damage)


func _on_area_2d_body_entered(body: Node) -> void:
	if body is Node2D and not _targets.has(body):
		_targets.append(body)
	if target == null and body is Node2D:
		target = body


func _on_area_2d_body_exited(body: Node) -> void:
	if body is Node2D and _targets.has(body):
		_targets.erase(body)
	if body == target:
		target = null
