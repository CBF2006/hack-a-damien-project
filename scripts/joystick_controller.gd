extends Control

# ─── Signals ───────────────────────────────────────────────────────────────────
# Emitted for continuous movement (joysticks or dragging)
signal direction_changed(vector: Vector2)
# Emitted for discrete inputs like quick flicks or key presses
signal action_pressed(action_name: String)
# Emitted whenever the player enters or exits Action Mode
signal action_mode_toggled(enabled: bool)

# ─── Config ────────────────────────────────────────────────────────────────────
@export var debug_mode             := true   # Enables rich text console logging
@export var dead_zone              := 20.0   # Minimum pixel distance for mouse/touch movement
@export var gesture_threshold      := 60.0   # Distance required to consider a move a full gesture
@export var joy_con_dead_zone      := 0.2    # Dead zone for analog stick input (0.0–1.0)
@export var joy_con_device_index   := 0      # The specific controller index to listen to
@export var combo_max_length       := 10     # Max number of inputs stored in the history buffer
@export var simulate_combo_delay   := 1.0   # Seconds to wait before running the startup debug test
@export var gesture_joycon_scale   := 2.0   # Sensitivity multiplier for joystick gestures
@export var input_gap              := 0.15  # Time between inputs during simulation
@export var flick_threshold        := 0.2   # Time window (s): release under this counts as a flick
@export var flick_cooldown         := 0.25  # Prevents rapid accidental double-flicks
@export var held_move_interval     := 0.15  # Frequency of direction_changed while holding
@export var cursor_speed           := 400.0 # How fast the cursor moves across the screen
@export var combo_confirm_delay    := 0.35  # Wait after a partial match before confirming it
@export var combo_reset_timeout    := 1.2   # Idle time before the input sequence resets
@export var snap_dir_threshold     := 0.1   # Snapping precision for direction-change debug logs

# ─── Serial Bridge Config ──────────────────────────────────────────────────────
@export var bridge_host                := "127.0.0.1"
@export var bridge_port                := 5555
@export var serial_reconnect_interval  := 2.0

# ─── Action Mode Config ────────────────────────────────────────────────────────
## When false the controller is always in free-move; flicks and combos are
## disabled and _action_mode cannot be entered.
@export var action_mode_available := true

## Color printed in the console when Action Mode turns ON / OFF.
@export var action_mode_on_color  := "lime"
@export var action_mode_off_color := "orange"

# ─── Nodes ─────────────────────────────────────────────────────────────────────
@onready var knob: TextureRect = $VisualKnob

# ─── State ─────────────────────────────────────────────────────────────────────
var is_held          := false         # Mouse/touch currently pressed
var origin           := Vector2.ZERO  # Screen coord where the press started
var current_dir      := Vector2.ZERO  # Normalised movement direction
var input_sequence: Array[String] = []

var _last_logged_dir   := Vector2.ZERO
var _press_time        := 0.0
var _flick_on_cooldown := false
var _held_timer        := 0.0
var _is_free_moving    := false

## Whether the player is currently in Action Mode.
## Read this from other nodes to gate game verbs.
var _action_mode := false

# ─── Combo Pending State ────────────────────────────────────────────────────────
var _pending_combo       : String          = ""
var _combo_confirm_timer : SceneTreeTimer  = null
var _combo_reset_timer   : SceneTreeTimer  = null

# ─── Serial Bridge State ──────────────────────────────────────────────────────
var _serial_peer             : StreamPeerTCP = null
var _serial_connected        := false
var _serial_buffer           := ""
var _serial_reconnect_timer  := 0.0
var _serial_prev_btn         := false
var _serial_prev_dir         := Vector2.ZERO

# ─── Combos ────────────────────────────────────────────────────────────────────
var combos := {
	["right", "left",  "right", "left"]: "open_menu",
	["left",  "left",  "right", "right"]: "example_llrr",
	["left",  "left",  "right"]:          "example_llr",
	["up",    "up"]:                      "place_tower",
	["up",    "down"]:                    "tower_upgrade",
	["down",  "down",  "down"]:           "sell_tower",
	["right", "right"]:                   "open_radial_menu",
}

var _sorted_combos: Array = []

# ─── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_sorted_combos = combos.keys()
	_sorted_combos.sort_custom(func(a, b): return a.size() > b.size())

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
	# ── Action Mode toggle: Space / Enter / ui_accept (rebindable in Project > Input Map) ──
	if event.is_action_pressed("ui_accept"):
		toggle_action_mode()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			toggle_action_mode()
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
func _process(delta: float) -> void:
	_serial_process(delta)

	var stick := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if stick.length() > joy_con_dead_zone:
		current_dir      = stick.normalized()
		_last_logged_dir = current_dir
		_press_time     += delta

		if _action_mode:
			# ── Action Mode: honour flick threshold ──
			if _press_time > flick_threshold:
				if not _is_free_moving:
					_is_free_moving = true
					if debug_mode:
						print_rich("[color=yellow]MODE: free move (action mode)[/color]")
				_held_timer += delta
				if _held_timer >= held_move_interval:
					_held_timer = 0.0
					emit_signal("direction_changed", current_dir)
		else:
			# ── Free-Move Mode: always emit direction ──
			_is_free_moving = true
			_held_timer    += delta
			if _held_timer >= held_move_interval:
				_held_timer = 0.0
				emit_signal("direction_changed", current_dir)
	else:
		# Stick returned to neutral.
		if _press_time > 0.0:
			if _action_mode and _press_time < flick_threshold:
				# Quick flick — only fires in Action Mode.
				if not _flick_on_cooldown and _last_logged_dir != Vector2.ZERO:
					var action = _dir_to_action(_last_logged_dir)
					if debug_mode:
						print_rich("[color=magenta]FLICK (joy-con): %s[/color]" % action)
					emit_signal("action_pressed", action)
					_start_flick_cooldown()

		_press_time     = 0.0
		_is_free_moving = not _action_mode  # stay in free-move when not in action mode
		_held_timer     = 0.0
		current_dir     = Vector2.ZERO

	# Mouse/Touch held logic
	if is_held:
		_press_time += delta
		if not _action_mode:
			# Always free-move outside Action Mode.
			_is_free_moving = true
		elif _press_time > flick_threshold and not _is_free_moving:
			_is_free_moving = true
		if _is_free_moving:
			_held_timer += delta
			if _held_timer >= held_move_interval:
				_held_timer = 0.0
				if current_dir != Vector2.ZERO:
					emit_signal("direction_changed", current_dir)

	# Cursor movement — locked while in Action Mode so flicks register cleanly.
	if not _action_mode and current_dir != Vector2.ZERO:
		knob.global_position += current_dir * cursor_speed * delta
		var vp := get_viewport_rect().size
		knob.global_position.x = clamp(knob.global_position.x, 0.0, vp.x)
		knob.global_position.y = clamp(knob.global_position.y, 0.0, vp.y)

# ─── Arrow Keys (debug / simulation) ──────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	if not debug_mode:             return
	if not event.pressed:          return

	match (event as InputEventKey).keycode:
		KEY_RIGHT:
			print_rich("[color=gray]Key: RIGHT[/color]")
			emit_signal("action_pressed", "right")
		KEY_LEFT:
			print_rich("[color=gray]Key: LEFT[/color]")
			emit_signal("action_pressed", "left")
		KEY_UP:
			print_rich("[color=gray]Key: UP[/color]")
			emit_signal("action_pressed", "up")
		KEY_DOWN:
			print_rich("[color=gray]Key: DOWN[/color]")
			emit_signal("action_pressed", "down")

# ─── MSP430 Serial Bridge ─────────────────────────────────────────────────────
func _serial_connect() -> void:
	_serial_peer = StreamPeerTCP.new()
	var err = _serial_peer.connect_to_host(bridge_host, bridge_port)
	if err != OK and debug_mode:
		print_rich("[color=red]Serial: Can't connect to bridge on port %d[/color]" % bridge_port)

func _serial_process(delta: float) -> void:
	if _serial_peer == null:
		return

	_serial_peer.poll()
	var status = _serial_peer.get_status()

	match status:
		StreamPeerTCP.STATUS_CONNECTED:
			if not _serial_connected:
				_serial_connected = true
				_serial_peer.set_no_delay(true)
				_serial_reconnect_timer = 0.0
				if debug_mode:
					print_rich("[color=green]Serial: MSP430 connected via bridge[/color]")
			_serial_read()

		StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR:
			if _serial_connected:
				_serial_connected = false
				if debug_mode:
					print_rich("[color=red]Serial: Disconnected[/color]")
			_serial_reconnect_timer += delta
			if _serial_reconnect_timer >= serial_reconnect_interval:
				_serial_reconnect_timer = 0.0
				_serial_connect()

		StreamPeerTCP.STATUS_CONNECTING:
			pass

func _serial_read() -> void:
	var available = _serial_peer.get_available_bytes()
	if available <= 0:
		return

	var data = _serial_peer.get_data(available)
	if data[0] != OK:
		return

	_serial_buffer += data[1].get_string_from_utf8()

	while true:
		var nl = _serial_buffer.find("\n")
		if nl == -1:
			break
		var line = _serial_buffer.substr(0, nl).strip_edges()
		_serial_buffer = _serial_buffer.substr(nl + 1)
		if line.length() > 0:
			_serial_parse(line)

func _serial_parse(line: String) -> void:
	if not line.begins_with("J:"):
		return

	var parts = line.substr(2).split(",")
	if parts.size() != 3:
		return

	var sx  : int  = int(parts[0])
	var sy  : int  = int(parts[1])
	var btn : bool = (parts[2] == "1")

	var dir := Vector2.ZERO
	if   sx == 1: dir.x = -1.0
	elif sx == 2: dir.x =  1.0
	if   sy == 1: dir.y = -1.0
	elif sy == 2: dir.y =  1.0

	if dir != current_dir:
		current_dir      = dir
		_last_logged_dir = dir
		emit_signal("direction_changed", dir)

	# Only emit action_pressed in Action Mode (edge detection for combos).
	if _action_mode and dir != Vector2.ZERO and dir != _serial_prev_dir:
		emit_signal("action_pressed", _dir_to_action(dir))
	_serial_prev_dir = dir

	if btn and not _serial_prev_btn:
		if _action_mode:
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
	var overlapping_areas = $VisualKnob/CursorDetector.get_overlapping_areas()
	for area in overlapping_areas:
		if area.get_parent().has_method("on_cursor_action"):
			area.get_parent().on_cursor_action(combo_name)

	print_rich("[color=green]★ COMBO: %s[/color]" % combo_name)
	match combo_name:
		"open_menu":        print_rich("[color=green]→ would open menu[/color]")
		"open_radial_menu": print_rich("[color=green]→ would open radial menu[/color]")
		"tower_upgrade":    print_rich("[color=green]→ upgrade verb[/color]")
		"sell_tower":       print_rich("[color=green]→ sell verb[/color]")
		"place_tower":      print_rich("[color=green]→ place verb[/color]")
		"example_llrr":     print_rich("[color=green]→ LLRR combo fired[/color]")
		"example_llr":      print_rich("[color=green]→ LLR combo fired[/color]")

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
