extends Node2D

@export var tower_scene: PackedScene = preload("res://scenes/tower.tscn")
@export var place_cost: int = 25
@export var upgrade_cost: int = 20
@export var sell_refund_ratio: float = 0.65

var tower_instance: Node = null


func on_cursor_action(combo_name: String) -> Dictionary:
	match combo_name:
		"place_tower":
			return _place_tower()
		"tower_upgrade":
			return _upgrade_tower_path("path_a", "Path A")
		"tower_upgrade_path_a":
			return _upgrade_tower_path("path_a", "Path A")
		"tower_upgrade_path_b":
			return _upgrade_tower_path("path_b", "Path B")
		"sell_tower":
			return _sell_tower()

	return _action_result(false, "Unknown action", "invalid_action")


func has_tower() -> bool:
	return is_instance_valid(tower_instance)


func get_tower_status() -> Dictionary:
	if not has_tower():
		return {
			"has_tower": false,
			"build_cost": place_cost,
		}

	if tower_instance.has_method("get_tower_status_summary"):
		var status: Dictionary = tower_instance.get_tower_status_summary()
		status["has_tower"] = true
		status["build_cost"] = place_cost
		return status

	return {
		"has_tower": true,
		"level": 0,
		"path_a_level": 0,
		"path_b_level": 0,
		"locked_path": "",
		"sell_refund": int(place_cost * sell_refund_ratio),
		"build_cost": place_cost,
	}


func get_action_context(action_name: String) -> Dictionary:
	var status := get_tower_status()
	if action_name == "place_tower":
		if status.get("has_tower", false):
			return {"enabled": false, "reason": "spot_occupied", "detail": "Spot already occupied"}
		return {"enabled": true, "reason": "ok", "detail": "Cost: %d" % place_cost}

	if action_name == "sell_tower":
		if not status.get("has_tower", false):
			return {"enabled": false, "reason": "no_tower", "detail": "No tower to sell"}
		return {"enabled": true, "reason": "ok", "detail": "Refund: %d" % int(status.get("sell_refund", 0))}

	if action_name == "tower_upgrade_path_a" or action_name == "tower_upgrade":
		return _get_path_upgrade_context("path_a", "Path A")

	if action_name == "tower_upgrade_path_b":
		return _get_path_upgrade_context("path_b", "Path B")

	return {"enabled": false, "reason": "invalid_action", "detail": "Unknown action"}


func _place_tower() -> Dictionary:
	if has_tower():
		return _action_result(false, "Spot already occupied", "spot_occupied")

	if not _try_spend(place_cost):
		return _action_result(false, "Not enough gold", "not_enough_gold")

	tower_instance = tower_scene.instantiate()
	add_child(tower_instance)
	tower_instance.position = Vector2.ZERO

	if tower_instance.has_method("configure_tower"):
		tower_instance.configure_tower(place_cost)
	if tower_instance.has_method("set_spawned_from_spot"):
		tower_instance.set_spawned_from_spot(self)

	var tower_root := tower_instance as Node2D
	if tower_root != null:
		tower_root.scale = Vector2.ONE * 0.85
		var spawn_tween := create_tween()
		spawn_tween.tween_property(tower_root, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	GameManager.play_song(GameManager.SONG_PLACE)
	return _action_result(true, "Tower placed", "ok", {"spent": place_cost})


func _upgrade_tower_path(path_name: String, path_label: String) -> Dictionary:
	if not has_tower():
		return _action_result(false, "No tower here", "no_tower")

	if not tower_instance.has_method("get_upgrade_preview") or not tower_instance.has_method("upgrade_tower_path"):
		return _action_result(false, "Tower does not support path upgrades", "unsupported")

	var preview: Dictionary = tower_instance.get_upgrade_preview(path_name)
	if not preview.get("can_upgrade", false):
		var reason: String = str(preview.get("reason", "blocked"))
		match reason:
			"path_locked":
				return _action_result(false, "%s locked" % path_label, "path_locked")
			"path_maxed":
				return _action_result(false, "%s already maxed" % path_label, "path_maxed")
			_:
				return _action_result(false, "%s upgrade unavailable" % path_label, reason)

	var cost := int(preview.get("next_cost", upgrade_cost))

	if not _try_spend(cost):
		return _action_result(false, "Not enough gold", "not_enough_gold")

	if tower_instance.upgrade_tower_path(path_name):
		var updated_summary: Dictionary = {}
		if tower_instance.has_method("get_tower_status_summary"):
			updated_summary = tower_instance.get_tower_status_summary()
		var new_level: int = int(updated_summary.get("path_a_level", 0))
		if path_name == "path_b":
			new_level = int(updated_summary.get("path_b_level", 0))
		GameManager.play_song(GameManager.SONG_UPGRADE)
		return _action_result(true, "%s upgraded to Lv.%d" % [path_label, new_level], "ok", {"spent": cost, "path": path_name, "path_level": new_level})
	else:
		_refund(cost)
		return _action_result(false, "%s already maxed" % path_label, "path_maxed")


func _sell_tower() -> Dictionary:
	if not has_tower():
		return _action_result(false, "No tower to sell", "no_tower")

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
	return _action_result(true, "Tower sold (+%d gold)" % refund_amount, "ok", {"refunded": refund_amount})


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


func _action_result(success: bool, message: String, reason: String, extras: Dictionary = {}) -> Dictionary:
	_show_feedback(message)
	var result := {
		"success": success,
		"message": message,
		"reason": reason,
	}
	for key in extras.keys():
		result[key] = extras[key]
	return result


func _get_path_upgrade_context(path_name: String, path_label: String) -> Dictionary:
	if not has_tower():
		return {"enabled": false, "reason": "no_tower", "detail": "No tower here"}

	if not tower_instance.has_method("get_upgrade_preview"):
		return {"enabled": false, "reason": "unsupported", "detail": "Tower has no path upgrades"}

	var preview: Dictionary = tower_instance.get_upgrade_preview(path_name)
	if preview.get("can_upgrade", false):
		return {
			"enabled": true,
			"reason": "ok",
			"detail": "%s cost: %d" % [path_label, int(preview.get("next_cost", upgrade_cost))],
		}

	var reason: String = str(preview.get("reason", "blocked"))
	match reason:
		"path_locked":
			return {"enabled": false, "reason": "path_locked", "detail": "%s locked" % path_label}
		"path_maxed":
			return {"enabled": false, "reason": "path_maxed", "detail": "%s maxed" % path_label}
		_:
			return {"enabled": false, "reason": reason, "detail": "%s unavailable" % path_label}
