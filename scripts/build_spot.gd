extends Node2D

@export var tower_scene: PackedScene = preload("res://scenes/tower.tscn")
@export var place_cost: int = 25
@export var upgrade_cost: int = 20
@export var sell_refund_ratio: float = 0.65

var tower_instance: Node = null


func on_cursor_action(combo_name: String) -> void:
	match combo_name:
		"place_tower":
			_place_tower()
		"tower_upgrade":
			_upgrade_tower()
		"sell_tower":
			_sell_tower()


func has_tower() -> bool:
	return is_instance_valid(tower_instance)


func place_tower_type(scene: PackedScene) -> void:
	var prev := tower_scene
	tower_scene = scene
	_place_tower()
	tower_scene = prev


func _place_tower() -> void:
	if has_tower():
		_show_feedback("Spot already occupied")
		return

	if not _try_spend(place_cost):
		_show_feedback("Not enough money")
		return

	tower_instance = tower_scene.instantiate()
	add_child(tower_instance)
	tower_instance.position = Vector2.ZERO

	if tower_instance.has_method("configure_tower"):
		tower_instance.configure_tower()
	if tower_instance.has_method("set_spawned_from_spot"):
		tower_instance.set_spawned_from_spot(self)

	var tower_root := tower_instance as Node2D
	if tower_root != null:
		tower_root.scale = Vector2.ONE * 0.85
		var spawn_tween := create_tween()
		spawn_tween.tween_property(tower_root, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	GameManager.play_song(GameManager.SONG_PLACE)
	_show_feedback("Tower placed")


func _upgrade_tower() -> void:
	if not has_tower():
		_show_feedback("No tower here")
		return

	var cost := upgrade_cost
	if tower_instance.has_method("get_upgrade_cost"):
		var next_cost: int = int(tower_instance.get_upgrade_cost())
		if next_cost > 0:
			cost = next_cost

	if not _try_spend(cost):
		_show_feedback("Not enough money")
		return

	if tower_instance.has_method("upgrade_tower") and tower_instance.upgrade_tower():
		GameManager.play_song(GameManager.SONG_UPGRADE)
		_show_feedback("Tower upgraded")
	else:
		_show_feedback("Tower is already maxed")
		_refund(cost)


func _sell_tower() -> void:
	if not has_tower():
		_show_feedback("No tower to sell")
		return

	var refund_amount: int = int(place_cost * sell_refund_ratio)
	if tower_instance.has_method("get_sell_refund"):
		refund_amount = int(tower_instance.get_sell_refund())

	_refund(refund_amount)

	var tower_root := tower_instance as Node2D
	if tower_root != null:
		var sell_tween := create_tween()
		sell_tween.tween_property(tower_root, "scale", Vector2.ONE * 0.75, 0.12)
		sell_tween.tween_property(tower_root, "modulate:a", 0.0, 0.08)
		sell_tween.finished.connect(func():
			if is_instance_valid(tower_instance):
				tower_instance.queue_free()
			tower_instance = null
		)
	else:
		if is_instance_valid(tower_instance):
			tower_instance.queue_free()
		tower_instance = null

	GameManager.play_song(GameManager.SONG_SELL)
	_show_feedback("Tower sold")


func _try_spend(amount: int) -> bool:
	if amount <= 0:
		return true

	if GameManager != null and GameManager.has_method("can_spend_money"):
		if not GameManager.can_spend_money(amount):
			return false
		if GameManager.has_method("spend_money"):
			GameManager.spend_money(amount)
		return true

	if GameManager != null and GameManager.has_method("try_spend_money"):
		return GameManager.try_spend_money(amount)

	return true


func _refund(amount: int) -> void:
	if amount <= 0:
		return

	if GameManager != null and GameManager.has_method("refund_money"):
		GameManager.refund_money(amount)
	elif GameManager != null and GameManager.has_method("add_money"):
		GameManager.add_money(amount)


func _show_feedback(message: String) -> void:
	var game := get_tree().get_root().get_node_or_null("game")
	if game != null and game.has_method("show_command_feedback"):
		game.show_command_feedback(message)
