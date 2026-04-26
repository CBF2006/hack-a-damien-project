extends Control

# ─── Signals ───────────────────────────────────────────────────────────────────
# Emitted for continuous movement (joysticks or dragging)
signal direction_changed(vector: Vector2)
# Emitted for discrete inputs like quick flicks or key presses
signal action_pressed(action_name: String)

# ─── Config ────────────────────────────────────────────────────────────────────
@export var debug_mode := true           # Enables rich text console logging
@export var dead_zone := 20.0            # Minimum pixel distance for mouse/touch movement
@export var gesture_threshold := 60.0    # Distance required to consider a move a full gesture
@export var joy_con_dead_zone := 0.2     # Dead zone for analog stick input (0.0 to 1.0)
@export var joy_con_device_index := 0    # The specific controller index to listen to
@export var combo_max_length := 10       # Max number of inputs stored in the history buffer
@export var simulate_combo_delay := 1.0  # Seconds to wait before running the startup debug test
@export var gesture_joycon_scale := 2.0  # Sensitivity multiplier for joystick gestures
@export var input_gap := 0.15            # Time between inputs during simulation
@export var flick_threshold := 0.2       # Time window (seconds): release under this to count as a flick
@export var flick_cooldown := 0.25        # Prevents rapid accidental double-flicks
@export var held_move_interval := 0.15   # Frequency of 'direction_changed' signals while holding

@export var cursor_speed := 600.0 # How fast the cursor moves across the screen
@onready var knob: TextureRect = $VisualKnob # To move our $VisualKnob object

## How long to wait after a partial match before confirming it.
## Must be long enough for a follow-up input to arrive, but short
## enough to feel responsive. 0.3–0.5 s is a good starting point.
@export var combo_confirm_delay := 0.35

## How long with NO input before the sequence resets on its own.
## Keeps stale inputs from poisoning future combos.
@export var combo_reset_timeout := 1.2

# ─── Serial Bridge Config ──────────────────────────────────────────────────────
@export var bridge_host := "127.0.0.1"
@export var bridge_port := 5555
@export var serial_reconnect_interval := 2.0

# ─── State ─────────────────────────────────────────────────────────────────────
var is_held := false                     # Tracking if mouse/touch is currently pressed
var origin := Vector2.ZERO               # Screen coordinate where the press started
var current_dir := Vector2.ZERO          # Current normalized direction of movement
var input_sequence: Array[String] = []   # Buffer of recent actions (e.g. ["up", "down", "up"])
var _last_logged_dir := Vector2.ZERO     # Cached direction to handle releases correctly
var _press_time := 0.0                   # How long the current press/stick-tilt has lasted
var _flick_on_cooldown := false          # Throttle flag for flicks
var _held_timer := 0.0                   # Accumulator for interval-based movement signals
var _is_free_moving := false             # True if user held long enough to exit 'flick' mode

# ─── Combo pending state ────────────────────────────────────────────────────────
# When a combo tail-matches we don't fire it immediately. Instead we park it
# here and start a confirmation timer. A longer combo arriving in time will
# cancel the pending match and claim priority.
var _pending_combo: String = ""
var _combo_confirm_timer: SceneTreeTimer = null
var _combo_reset_timer:   SceneTreeTimer = null

# ─── Serial Bridge State ──────────────────────────────────────────────────────
var _serial_peer: StreamPeerTCP = null
var _serial_connected := false
var _serial_buffer := ""
var _serial_reconnect_timer := 0.0
var _serial_prev_btn := false
var _serial_prev_dir := Vector2.ZERO

# ─── Combos ────────────────────────────────────────────────────────────────────
# Longer combos MUST be listed before shorter prefix-sharing ones so that
# _find_best_match() can do a single-pass length-sorted search.
var combos := {
	["right", "left", "right", "left"]: "open_menu",
	["left",  "left", "right", "right"]: "example_llrr",   # longer — listed first
	["left",  "left", "right"]:          "example_llr",    # shorter prefix share
	["up",    "up"]:                     "open_radial_menu",
	["down",  "down", "down"]:           "sell_tower",
	["up",    "right"]:                  "place_tower",
	["down",  "up"]:                     "tower_upgrade",
}

# Sorted combo keys, longest first — built once in _ready so we never re-sort.
var _sorted_combos: Array = []

# ─── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Pre-sort combo keys longest-first so _find_best_match is deterministic.
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
		print_rich("[color=white]Mouse, touch, arrow keys, Joy-Con, MSP430 serial all active[/color]")
		print_rich("[color=white]──────────────────────────────[/color]")
		
		# Connect local signals to debug printers
		direction_changed.connect(_debug_direction)
		action_pressed.connect(_on_action_pressed)

		# Run a test simulation after a brief delay
		await get_tree().create_timer(simulate_combo_delay).timeout
		_simulate_combo(["up", "up"])

	# Connect to the serial bridge (MSP430)
	_serial_connect()

# ─── Mouse + Touch ─────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# Handle Mouse Button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_held = true
			_press_time = 0.0
			_is_free_moving = false
			_held_timer = 0.0
			origin = event.position
			if debug_mode:
				print_rich("[color=gray]Mouse pressed at: %s[/color]" % origin)
		else:
			_handle_release_flick("mouse")

	# Handle Mouse Movement
	if event is InputEventMouseMotion and is_held:
		var delta = event.position - origin
		_track_press_time_mouse(delta)

	# Handle Touchscreen (Mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			is_held = true
			_press_time = 0.0
			_is_free_moving = false
			_held_timer = 0.0
			origin = event.position
			if debug_mode:
				print_rich("[color=gray]Touch pressed at: %s[/color]" % origin)
		else:
			_handle_release_flick("touch")

	# Handle Finger Dragging
	if event is InputEventScreenDrag and is_held:
		var delta = event.position - origin
		_track_press_time_mouse(delta)

# ─── Mouse/Touch time tracking ──────────────────────────────────────────────────
func _track_press_time_mouse(delta: Vector2) -> void:
	# Ignore small movements within the dead zone
	if delta.length() < dead_zone:
		if current_dir != Vector2.ZERO:
			current_dir = Vector2.ZERO
			emit_signal("direction_changed", Vector2.ZERO)
		return

	current_dir = delta.normalized()
	_last_logged_dir = current_dir

	# Only emit direction signals if the user has held long enough to enter free-move mode
	if _is_free_moving:
		emit_signal("direction_changed", current_dir)

# Decide if the release was a quick flick or a finished drag
func _handle_release_flick(source: String) -> void:
	if _press_time < flick_threshold and not _flick_on_cooldown and current_dir != Vector2.ZERO:
		if debug_mode:
			print_rich("[color=magenta]FLICK (%s): %s[/color]" % [source, _dir_to_action(current_dir)])
		emit_signal("action_pressed", _dir_to_action(current_dir))
		_start_flick_cooldown()

	_release(source)

# ─── Joy-Con / Analog Stick ─────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Process MSP430 serial input first
	_serial_process(delta)
	
	# 1. Fetch combined axis values from input map
	var stick := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	# 2. Update current_dir based on stick movement
	if stick.length() > joy_con_dead_zone:
		current_dir = stick.normalized()
		_last_logged_dir = current_dir
		_press_time += delta

		# If held longer than the flick threshold, it's continuous movement
		if _press_time > flick_threshold:
			if not _is_free_moving:
				_is_free_moving = true
				if debug_mode:
					print_rich("[color=yellow]MODE: free move[/color]")

			# Emit direction signals at fixed intervals
			_held_timer += delta
			if _held_timer >= held_move_interval:
				_held_timer = 0.0
				emit_signal("direction_changed", current_dir)
	else:
		# Stick returned to center: Check if it was a quick flick before resetting
		if _press_time > 0.0 and _press_time < flick_threshold:
			if not _flick_on_cooldown and _last_logged_dir != Vector2.ZERO:
				var action = _dir_to_action(_last_logged_dir)
				if debug_mode:
					print_rich("[color=magenta]FLICK (joy-con): %s[/color]" % action)
				emit_signal("action_pressed", action)
				_start_flick_cooldown()

		# Reset state when stick is neutral
		_press_time = 0.0
		_is_free_moving = false
		_held_timer = 0.0
		current_dir = Vector2.ZERO

	# 3. Handle Mouse/Touch logic (if currently holding)
	if is_held:
		_press_time += delta
		if _press_time > flick_threshold and not _is_free_moving:
			_is_free_moving = true
		if _is_free_moving:
			_held_timer += delta
			if _held_timer >= held_move_interval:
				_held_timer = 0.0
				if current_dir != Vector2.ZERO:
					emit_signal("direction_changed", current_dir)
	
	
	# 3.5 Apply serial direction if active
	if _serial_prev_dir != Vector2.ZERO:
		current_dir = _serial_prev_dir
	
	
	
	# 4. Movement Execution
	if current_dir != Vector2.ZERO:
		# Move the knob
		knob.global_position += current_dir * cursor_speed * delta

		# Keep the cursor inside the game window
		var viewport_size = get_viewport_rect().size
		knob.global_position.x = clamp(knob.global_position.x, 0, viewport_size.x)
		knob.global_position.y = clamp(knob.global_position.y, 0, viewport_size.y)

# ─── Arrow Keys ────────────────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	if not debug_mode: return
	if not event.pressed: return

	# Map keys directly to action strings for the combo system
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
			# Read ALL pending data, not just one chunk
			while _serial_peer.get_available_bytes() > 0:
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
	# format: J:x,y,b
	if not line.begins_with("J:"):
		return

	var parts = line.substr(2).split(",")
	if parts.size() != 3:
		return

	var sx: int = int(parts[0])   # 0=neutral, 1=left, 2=right
	var sy: int = int(parts[1])   # 0=neutral, 1=up, 2=down
	var btn: bool = (parts[2] == "1")

	# Build direction vector
	var dir := Vector2.ZERO
	if sx == 1: dir.x = -1.0    # LEFT
	elif sx == 2: dir.x = 1.0   # RIGHT
	if sy == 1: dir.y = -1.0    # UP (screen Y inverted)
	elif sy == 2: dir.y = 1.0   # DOWN

	# Always emit direction_changed for cursor movement
	# Emit direction_changed on change
	if dir != _serial_prev_dir:
		emit_signal("direction_changed", dir)

	# Only emit action_pressed on direction CHANGE (edge detection for combos)
	if dir != Vector2.ZERO and dir != _serial_prev_dir:
		var action = _dir_to_action(dir)
		emit_signal("action_pressed", action)
	_serial_prev_dir = dir

	# Button edge detection
	if btn and not _serial_prev_btn:
		emit_signal("action_pressed", "confirm")
		if debug_mode:
			print_rich("[color=magenta]Serial: button pressed[/color]")
	_serial_prev_btn = btn

## Send a command to the MSP430 (buzzer, LCD)
func serial_send(cmd: String) -> void:
	if _serial_connected and _serial_peer != null:
		_serial_peer.put_data((cmd + "\n").to_utf8_buffer())

## Play a song on the MSP430 buzzer
func serial_play_song(id: int) -> void:
	serial_send("SONG:%d" % id)

## Show an LCD preset on the MSP430 screen
func serial_set_lcd(id: int) -> void:
	serial_send("LCD:%d" % id)

## Play song and set LCD in one message
func serial_song_and_lcd(song_id: int, lcd_id: int) -> void:
	serial_send("SONG:%d LCD:%d" % [song_id, lcd_id])

# ─── Helpers ───────────────────────────────────────────────────────────────────
# Converts a 2D vector into one of 4 cardinal strings
func _dir_to_action(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

# Generic reset triggered when input stops
func _release(source: String) -> void:
	if debug_mode:
		print_rich("[color=gray]Released (%s)[/color]" % source)
	is_held = false
	_press_time = 0.0
	_is_free_moving = false
	_held_timer = 0.0
	current_dir = Vector2.ZERO
	emit_signal("direction_changed", Vector2.ZERO)

# Prevents multiple flick actions within a fraction of a second
func _start_flick_cooldown() -> void:
	_flick_on_cooldown = true
	await get_tree().create_timer(flick_cooldown).timeout
	_flick_on_cooldown = false

# ─── Sequence Reset ─────────────────────────────────────────────────────────────
# Clears the history of recent inputs
func _reset_sequence(reason: String) -> void:
	if input_sequence.is_empty():
		return
	if debug_mode:
		print_rich("[color=orange]Sequence reset (%s)[/color]" % reason)
	input_sequence.clear()
	_cancel_pending_combo()

# Starts/Restarts the timer that wipes the input sequence if the player goes idle
func _restart_reset_timer() -> void:
	if _combo_reset_timer != null:
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
	input_sequence.append(action_name)

	# 1. Reset the "Idle Timeout" (The 1.2s window to wipe memory)
	_restart_reset_timer()

	# 2. Cancel any confirmation timer currently running from a previous input
	_cancel_pending_combo()

	if debug_mode:
		print_rich("[color=cyan]Sequence so far: %s[/color]" % str(input_sequence))

	# 3. Check if our current chain contains a valid combo
	var match_name := _find_best_match()

	# Update the pending name ONLY if we found a NEW match.
	if match_name != "":
		_pending_combo = match_name

	# 4. If we have ANY saved match (new or old), restart the confirmation timer.
	if _pending_combo != "":
		if debug_mode:
			print_rich("[color=cyan]Pending: %s (Timer reset by input)[/color]" % _pending_combo)
		
		_combo_confirm_timer = get_tree().create_timer(combo_confirm_delay)
		_combo_confirm_timer.timeout.connect(_confirm_pending_combo)

	# Trim sequence
	if input_sequence.size() > combo_max_length:
		input_sequence.pop_front()

# Scans history buffer against the dictionary of valid combos
func _find_best_match() -> String:
	# Checks longer sequences first (greedily)
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

# Final step: Map the combo name to a game event
func _trigger_combo(combo_name: String) -> void:
	# Get all areas the cursor is currently touching
	var overlapping_areas = $VisualKnob/CursorDetector.get_overlapping_areas()
	
	for area in overlapping_areas:
		if area.get_parent().has_method("on_cursor_action"):
			area.get_parent().on_cursor_action(combo_name)
	
	print_rich("[color=green]★ COMBO: %s[/color]" % combo_name)
	match combo_name:
		"open_menu":          print_rich("[color=green]→ would open menu[/color]")
		"open_radial_menu":   print_rich("[color=green]→ would open radial menu[/color]")
		"tower_upgrade":      print_rich("[color=green]→ would upgrade tower[/color]")
		"sell_tower":         print_rich("[color=green]→ would sell tower[/color]")
		"place_tower":        print_rich("[color=green]→ would place tower[/color]")
		"example_llrr":       print_rich("[color=green]→ LLRR combo fired[/color]")
		"example_llr":        print_rich("[color=green]→ LLR combo fired[/color]")

# ─── Debug ─────────────────────────────────────────────────────────────────────
func _debug_direction(vec: Vector2) -> void:
	var rounded = vec.snapped(Vector2(0.1, 0.1))
	if rounded != _last_logged_dir.snapped(Vector2(0.1, 0.1)):
		print_rich("[color=yellow]DIR: %s[/color]" % rounded)

func _simulate_combo(actions: Array) -> void:
	print_rich("[color=white]── Simulating combo: %s ──[/color]" % str(actions))
	for action in actions:
		emit_signal("action_pressed", action)
		await get_tree().create_timer(input_gap).timeout
	print_rich("[color=white]── Simulation done ──[/color]")
