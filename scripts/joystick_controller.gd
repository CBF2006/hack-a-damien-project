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

<<<<<<< Updated upstream
=======
# ─── Combos ────────────────────────────────────────────────────────────────────
# Combo table:
# - right,left,right,left => open_menu
# - right,right => open_radial_menu
# - up,up => place_tower
# - up,down => tower_upgrade_path_a
# - down,up => tower_upgrade_path_b
# - down,down,down => sell_tower
var combos := {
	["right", "left",  "right", "left"]: "open_menu",
	["left",  "left",  "right", "right"]: "example_llrr",
	["left",  "left",  "right"]:          "example_llr",
	["up",    "up"]:                      "place_tower",
	["up",    "down"]:                    "tower_upgrade_path_a",
	["down",  "up"]:                      "tower_upgrade_path_b",
	["down",  "down",  "down"]:           "sell_tower",
	["right", "right"]:                   "open_radial_menu",
}

var _sorted_combos: Array = []

# ─── Ready ─────────────────────────────────────────────────────────────────────
>>>>>>> Stashed changes
func _ready() -> void:
	_matcher = ComboMatcher.new(_all_combo_keys)
	_setup_trail_label()
	_set_state(InputState.FREE)
	_update_hover_context(true)

<<<<<<< Updated upstream
=======
	if debug_mode:
		print_rich("[color=white]──────────────────────────────[/color]")
		print_rich("[color=white]JoystickController: debug ON[/color]")
		print_rich("[color=white]dead_zone: %s | gesture_threshold: %s[/color]" % [dead_zone, gesture_threshold])
		print_rich("[color=white]joy_con_dead_zone: %s | device_index: %s[/color]" % [joy_con_dead_zone, joy_con_device_index])
		print_rich("[color=white]flick_threshold: %s | flick_cooldown: %s[/color]" % [flick_threshold, flick_cooldown])
		print_rich("[color=white]combo_max_length: %s | input_gap: %s[/color]" % [combo_max_length, input_gap])
		print_rich("[color=white]combo_confirm_delay: %s | combo_reset_timeout: %s[/color]" % [combo_confirm_delay, combo_reset_timeout])
		print_rich("[color=white]cursor_speed: %s | action_mode_available: %s[/color]" % [cursor_speed, action_mode_available])
		print_rich("[color=white]Mouse, touch, arrow keys, Joy-Con, MSP430 serial all active[/color]")
		print_rich("[color=white]──────────────────────────────[/color]")

		direction_changed.connect(_debug_direction)
		action_pressed.connect(_on_action_pressed)
		action_mode_toggled.connect(_debug_action_mode)

		if run_startup_combo_test:
			await get_tree().create_timer(simulate_combo_delay).timeout
			_simulate_combo(["up", "up"])

	_serial_connect()

# ─── Action Mode Toggle ────────────────────────────────────────────────────────
## Call this (or let _unhandled_key_input do it) to enter/exit Action Mode.
func toggle_action_mode() -> void:
	if not action_mode_available:
		return
	_action_mode = not _action_mode
	emit_signal("action_mode_toggled", _action_mode)

	if not _action_mode:
		# Leaving Action Mode: flush any pending combo and reset sequence.
		_cancel_pending_combo()
		_reset_sequence("exited action mode")
		# Treat everything as free-move again.
		_is_free_moving = true

# ─── Mouse + Touch ─────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# ui_accept is treated as confirm so game.gd can apply consistent button semantics.
	if event.is_action_pressed("ui_accept"):
		toggle_action_mode()          # ← only trigger for action mode
		emit_signal("action_pressed", "confirm")
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and debug_mode:
			toggle_action_mode()      # ← only trigger for action mode
			emit_signal("action_pressed", "confirm")
			return

	# Handle Mouse Button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_held      = true
			_press_time  = 0.0
			_held_timer  = 0.0
			origin       = event.position
			# In free-move mode enter movement immediately; no flick detection.
			_is_free_moving = not _action_mode
			if debug_mode:
				print_rich("[color=gray]Mouse pressed at: %s[/color]" % origin)
		else:
			_handle_release_flick("mouse")

	if event is InputEventMouseMotion and is_held:
		_track_press_time_mouse(event.position - origin)

	# Touchscreen
	if event is InputEventScreenTouch:
		if event.pressed:
			is_held      = true
			_press_time  = 0.0
			_held_timer  = 0.0
			origin       = event.position
			_is_free_moving = not _action_mode
			if debug_mode:
				print_rich("[color=gray]Touch pressed at: %s[/color]" % origin)
		else:
			_handle_release_flick("touch")

	if event is InputEventScreenDrag and is_held:
		_track_press_time_mouse(event.position - origin)

# ─── Mouse/Touch Helpers ───────────────────────────────────────────────────────
func _track_press_time_mouse(delta: Vector2) -> void:
	if delta.length() < dead_zone:
		if current_dir != Vector2.ZERO:
			current_dir = Vector2.ZERO
			emit_signal("direction_changed", Vector2.ZERO)
		return

	current_dir      = delta.normalized()
	_last_logged_dir = current_dir

	if _is_free_moving:
		emit_signal("direction_changed", current_dir)

func _handle_release_flick(source: String) -> void:
	# Flicks only fire when the player is in Action Mode.
	if _action_mode and _press_time < flick_threshold \
			and not _flick_on_cooldown and current_dir != Vector2.ZERO:
		if debug_mode:
			print_rich("[color=magenta]FLICK (%s): %s[/color]" % [source, _dir_to_action(current_dir)])
		emit_signal("action_pressed", _dir_to_action(current_dir))
		_start_flick_cooldown()

	_release(source)

# ─── Process (Joy-Con + Cursor Movement) ────────────────────────────────────────
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
func _cardinal_from_vector(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "R" if v.x > 0.0 else "L"
	return "D" if v.y > 0.0 else "U"
=======
	var sx  : int  = int(parts[0])
	var sy  : int  = int(parts[1])
	var btn : bool = (parts[2] == "1")

	var dir := Vector2.ZERO
	if   sx == 1: dir.x = -1.0
	elif sx == 2: dir.x =  1.0
	if   sy == 1: dir.y = -1.0
	elif sy == 2: dir.y =  1.0

	_serial_dir = dir
	if dir != _serial_prev_dir:
		_last_logged_dir = dir
		emit_signal("direction_changed", dir)

	# Only emit action_pressed in Action Mode (edge detection for combos).
	if _action_mode and dir != Vector2.ZERO and dir != _serial_prev_dir:
		emit_signal("action_pressed", _dir_to_action(dir))
	_serial_prev_dir = dir

	if btn and not _serial_prev_btn:
		toggle_action_mode()
		emit_signal("action_pressed", "confirm")
		if debug_mode:
			print_rich("[color=magenta]Serial: button pressed[/color]")
	_serial_prev_btn = btn

## Send a raw command to the MSP430.
func serial_send(cmd: String) -> void:
	if _serial_connected and _serial_peer != null:
		_serial_peer.put_data((cmd + "\n").to_utf8_buffer())

func serial_play_song(id: int)                      -> void: serial_send("SONG:%d" % id)
func serial_set_lcd(id: int)                        -> void: serial_send("LCD:%d" % id)
func serial_song_and_lcd(song_id: int, lcd_id: int) -> void: serial_send("SONG:%d LCD:%d" % [song_id, lcd_id])

# ─── Helpers ───────────────────────────────────────────────────────────────────
func _dir_to_action(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

func _release(source: String) -> void:
	if debug_mode:
		print_rich("[color=gray]Released (%s)[/color]" % source)
	is_held         = false
	_press_time     = 0.0
	_is_free_moving = not _action_mode
	_held_timer     = 0.0
	current_dir     = Vector2.ZERO
	emit_signal("direction_changed", Vector2.ZERO)

func _start_flick_cooldown() -> void:
	_flick_on_cooldown = true
	await get_tree().create_timer(flick_cooldown).timeout
	_flick_on_cooldown = false

# ─── Sequence / Combo Reset ────────────────────────────────────────────────────
func _reset_sequence(reason: String) -> void:
	if input_sequence.is_empty():
		return
	if debug_mode:
		print_rich("[color=orange]Sequence reset (%s)[/color]" % reason)
	input_sequence.clear()
	_cancel_pending_combo()

func _restart_reset_timer() -> void:
	_combo_reset_timer = null
	_combo_reset_timer = get_tree().create_timer(combo_reset_timeout)
	_combo_reset_timer.timeout.connect(
		func():
			if _combo_reset_timer != null:
				_reset_sequence("idle timeout")
				_combo_reset_timer = null
	)

# ─── Combo Detection ────────────────────────────────────────────────────────────
func _on_action_pressed(action_name: String) -> void:
	if _should_skip_repeated_input(action_name):
		return

	# Combo tracking only runs in Action Mode.
	if not _action_mode:
		return

	input_sequence.append(action_name)
	_restart_reset_timer()
	_cancel_pending_combo()

	if debug_mode:
		print_rich("[color=cyan]Sequence so far: %s[/color]" % str(input_sequence))

	var match_name := _find_best_match()
	if match_name != "":
		_pending_combo = match_name

	if _pending_combo != "":
		if debug_mode:
			print_rich("[color=cyan]Pending: %s (Timer reset by input)[/color]" % _pending_combo)
		_combo_confirm_timer = get_tree().create_timer(combo_confirm_delay)
		_combo_confirm_timer.timeout.connect(_confirm_pending_combo)

	if input_sequence.size() > combo_max_length:
		input_sequence.pop_front()


func _should_skip_repeated_input(action_name: String) -> bool:
	if action_name != _last_action_name:
		_last_action_name = action_name
		_last_action_time = _elapsed
		return false

	if _last_action_time < 0.0:
		_last_action_time = _elapsed
		return false

	var delta_time := _elapsed - _last_action_time
	_last_action_time = _elapsed
	return delta_time < repeated_input_cooldown

func _find_best_match() -> String:
	for combo in _sorted_combos:
		var combo_len: int = combo.size()
		if input_sequence.size() >= combo_len:
			var tail: Array = input_sequence.slice(input_sequence.size() - combo_len)
			if tail == combo:
				return combos[combo]
	return ""

func _cancel_pending_combo() -> void:
	if _combo_confirm_timer != null:
		_combo_confirm_timer = null
	if _pending_combo != "" and debug_mode:
		print_rich("[color=orange]Input detected: Delaying combo '%s'[/color]" % _pending_combo)

func _confirm_pending_combo() -> void:
	if _combo_confirm_timer == null:
		return
	_combo_confirm_timer = null
	if _pending_combo == "":
		return
	_trigger_combo(_pending_combo)
	_pending_combo = ""
	_reset_sequence("combo fired")

func _trigger_combo(combo_name: String) -> void:
	emit_signal("combo_triggered", combo_name)

	print_rich("[color=green]★ COMBO: %s[/color]" % combo_name)
	match combo_name:
		"open_menu":        print_rich("[color=green]→ would open menu[/color]")
		"open_radial_menu": print_rich("[color=green]→ would open radial menu[/color]")
		"tower_upgrade_path_a": print_rich("[color=green]→ upgrade path A[/color]")
		"tower_upgrade_path_b": print_rich("[color=green]→ upgrade path B[/color]")
		"sell_tower":       print_rich("[color=green]→ sell verb[/color]")
		"place_tower":      print_rich("[color=green]→ place verb[/color]")
		"example_llrr":     print_rich("[color=green]→ LLRR combo fired[/color]")
		"example_llr":      print_rich("[color=green]→ LLR combo fired[/color]")


func get_hovered_build_spot() -> Node:
	for area in $VisualKnob/CursorDetector.get_overlapping_areas():
		var parent_node: Node = area.get_parent()
		if parent_node != null and parent_node.has_method("on_cursor_action"):
			return parent_node
	return null


func is_action_mode_enabled() -> bool:
	return _action_mode


func set_action_mode_enabled(enabled: bool) -> void:
	if _action_mode == enabled:
		return
	toggle_action_mode()

# ─── Debug ─────────────────────────────────────────────────────────────────────
func _debug_direction(vec: Vector2) -> void:
	var rounded = vec.snapped(Vector2(snap_dir_threshold, snap_dir_threshold))
	if rounded != _last_logged_dir.snapped(Vector2(snap_dir_threshold, snap_dir_threshold)):
		print_rich("[color=yellow]DIR: %s[/color]" % rounded)

func _debug_action_mode(enabled: bool) -> void:
	if enabled:
		print_rich("[color=%s]── ACTION MODE ON ──[/color]" % action_mode_on_color)
	else:
		print_rich("[color=%s]── ACTION MODE OFF (free move) ──[/color]" % action_mode_off_color)

func _simulate_combo(actions: Array) -> void:
	print_rich("[color=white]── Simulating combo: %s ──[/color]" % str(actions))
	for action in actions:
		emit_signal("action_pressed", action)
		await get_tree().create_timer(input_gap).timeout
	print_rich("[color=white]── Simulation done ──[/color]")
>>>>>>> Stashed changes
