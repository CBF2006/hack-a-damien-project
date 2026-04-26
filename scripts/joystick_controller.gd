extends Control

signal hover_context_changed(context_kind: String)
signal command_mode_changed(active: bool, seconds_left: float)
signal combo_buffer_changed(trail_text: String)
signal combo_result(success: bool, context_kind: String, combo_key: String)

const ComboMatcher = preload("res://scripts/combo_matcher.gd")

@export var cursor_speed := 600.0
@export var move_dead_zone := 0.2
@export var command_input_dead_zone := 0.55
@export var command_window_seconds := 1.4
@export var combo_max_length := 3
@export var combo_confirm_delay := 0.2
@export var debug_mode := false

@onready var knob: TextureRect = $VisualKnob
@onready var cursor_detector: Area2D = $VisualKnob/CursorDetector

enum InputState { FREE, COMMAND }

var _state: InputState = InputState.FREE
var _command_seconds_left := 0.0
var _command_buffer: Array[String] = []
var _command_confirm_timer := 0.0
var _trail_label: Label

var _hover_context_kind := "global"
var _hover_spot: Node = null
var _hover_tower: Node = null

var _dir_latched := false
var _matcher: ComboMatcher

var _all_combo_keys: Array[String] = [
	"U", "D", "L", "R",
	"U>U", "U>R", "U>L", "D>D", "L>R", "D>U", "R>R"
]

func _ready() -> void:
	_matcher = ComboMatcher.new(_all_combo_keys)
	_setup_trail_label()
	_set_state(InputState.FREE)
	_update_hover_context(true)

func _process(delta: float) -> void:
	var stick := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	_apply_cursor_movement(stick, delta)
	_update_hover_context(false)

	if Input.is_action_just_pressed("ui_accept"):
		_enter_command_mode()

	if _state == InputState.COMMAND:
		_process_command_mode(stick, delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not debug_mode:
		return
	if not event is InputEventKey:
		return
	if not event.pressed:
		return

	match (event as InputEventKey).keycode:
		KEY_UP:
			if _state == InputState.COMMAND:
				_register_direction("U")
		KEY_DOWN:
			if _state == InputState.COMMAND:
				_register_direction("D")
		KEY_LEFT:
			if _state == InputState.COMMAND:
				_register_direction("L")
		KEY_RIGHT:
			if _state == InputState.COMMAND:
				_register_direction("R")

func _apply_cursor_movement(stick: Vector2, delta: float) -> void:
	if stick.length() < move_dead_zone:
		return

	var direction := stick.normalized()
	knob.global_position += direction * cursor_speed * delta

	var viewport_size = get_viewport_rect().size
	knob.global_position.x = clamp(knob.global_position.x, 0.0, viewport_size.x)
	knob.global_position.y = clamp(knob.global_position.y, 0.0, viewport_size.y)

func _process_command_mode(stick: Vector2, delta: float) -> void:
	_command_seconds_left -= delta
	command_mode_changed.emit(true, _command_seconds_left)

	if _command_seconds_left <= 0.0:
		_finalize_command_sequence(false)
		return

	var is_above_threshold := stick.length() >= command_input_dead_zone
	if is_above_threshold and not _dir_latched:
		_dir_latched = true
		_register_direction(_cardinal_from_vector(stick))
	elif not is_above_threshold:
		_dir_latched = false

	if _command_confirm_timer > 0.0:
		_command_confirm_timer -= delta
		if _command_confirm_timer <= 0.0:
			_finalize_command_sequence(false)

func _register_direction(dir: String) -> void:
	if dir.is_empty():
		return

	_command_buffer.append(dir)
	if _command_buffer.size() > combo_max_length:
		_command_buffer = _command_buffer.slice(_command_buffer.size() - combo_max_length, _command_buffer.size())

	var combo_key := ComboMatcher.sequence_to_key(_command_buffer)
	combo_buffer_changed.emit(_format_trail(_command_buffer))
	_update_trail_label()

	if debug_mode:
		print("Combo buffer: ", combo_key)

	if not _matcher.has_prefix(combo_key):
		_fail_command("invalid_combo")
		return

	if _matcher.is_exact(combo_key) and not _matcher.has_longer_prefix(combo_key):
		_finalize_command_sequence(true)
		return

	_command_confirm_timer = combo_confirm_delay

func _finalize_command_sequence(force_try_execute: bool) -> void:
	var combo_key := ""
	if force_try_execute:
		combo_key = ComboMatcher.sequence_to_key(_command_buffer)
	else:
		combo_key = _matcher.find_longest_exact_from_suffix(_command_buffer)

	if combo_key.is_empty():
		_fail_command("no_match")
		return

	var handled := _execute_combo(combo_key)
	combo_result.emit(handled, _hover_context_kind, combo_key)
	if handled:
		_success_feedback()
	else:
		_fail_feedback()

	_exit_command_mode()

func _enter_command_mode() -> void:
	_set_state(InputState.COMMAND)
	_command_seconds_left = command_window_seconds
	_command_buffer.clear()
	_command_confirm_timer = 0.0
	_dir_latched = false
	combo_buffer_changed.emit("")
	_update_trail_label()

func _exit_command_mode() -> void:
	_set_state(InputState.FREE)
	_command_seconds_left = 0.0
	_command_buffer.clear()
	_command_confirm_timer = 0.0
	_dir_latched = false
	combo_buffer_changed.emit("")
	_update_trail_label()

func _set_state(next_state: InputState) -> void:
	_state = next_state
	var active := _state == InputState.COMMAND
	command_mode_changed.emit(active, _command_seconds_left)
	_update_knob_visual()

func _execute_combo(combo_key: String) -> bool:
	var game_root = get_tree().get_first_node_in_group("game_root")
	if game_root == null:
		return false
	if not game_root.has_method("handle_combo_request"):
		return false

	return game_root.handle_combo_request(combo_key, _hover_context_kind, _hover_spot, _hover_tower)

func _fail_command(_reason: String) -> void:
	combo_result.emit(false, _hover_context_kind, ComboMatcher.sequence_to_key(_command_buffer))
	_fail_feedback()
	_exit_command_mode()

func _update_hover_context(force_emit: bool) -> void:
	var previous := _hover_context_kind
	_hover_context_kind = "global"
	_hover_spot = null
	_hover_tower = null

	for area in cursor_detector.get_overlapping_areas():
		if area.is_in_group("cursor_tower_target"):
			_hover_context_kind = "tower"
			_hover_tower = area.get_meta("tower_ref") if area.has_meta("tower_ref") else area.get_parent()
			break

	if _hover_context_kind != "tower":
		for area in cursor_detector.get_overlapping_areas():
			if area.is_in_group("cursor_tower_spot"):
				_hover_context_kind = "build"
				_hover_spot = area.get_parent()
				break

	if force_emit or previous != _hover_context_kind:
		hover_context_changed.emit(_hover_context_kind)
		_update_knob_visual()

func _update_knob_visual() -> void:
	var context_color := Color(1.0, 1.0, 1.0)
	match _hover_context_kind:
		"build":
			context_color = Color(0.6, 1.0, 0.7)
		"tower":
			context_color = Color(0.6, 0.85, 1.0)
		_:
			context_color = Color(1.0, 1.0, 1.0)

	if _state == InputState.COMMAND:
		context_color = context_color.lerp(Color(1.0, 0.9, 0.4), 0.4)

	knob.modulate = context_color

func _success_feedback() -> void:
	knob.scale = Vector2.ONE * 1.2
	await get_tree().create_timer(0.08).timeout
	knob.scale = Vector2.ONE

func _fail_feedback() -> void:
	knob.modulate = Color(1.0, 0.4, 0.4)
	await get_tree().create_timer(0.08).timeout
	_update_knob_visual()

func _setup_trail_label() -> void:
	_trail_label = Label.new()
	_trail_label.name = "ComboTrail"
	_trail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trail_label.position = Vector2(-64.0, -44.0)
	_trail_label.size = Vector2(220.0, 24.0)
	_trail_label.text = ""
	knob.add_child(_trail_label)

func _update_trail_label() -> void:
	if _trail_label == null:
		return
	_trail_label.text = _format_trail(_command_buffer)
	_trail_label.visible = _state == InputState.COMMAND and not _trail_label.text.is_empty()

func _format_trail(buffer: Array[String]) -> String:
	if buffer.is_empty():
		return ""
	return " -> ".join(buffer)

func _cardinal_from_vector(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "R" if v.x > 0.0 else "L"
	return "D" if v.y > 0.0 else "U"
