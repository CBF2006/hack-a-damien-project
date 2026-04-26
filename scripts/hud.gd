extends CanvasLayer

@onready var health_bar: ProgressBar = $HUDPanel/VBoxContainer/HealthBar
@onready var health_label: Label = $HUDPanel/VBoxContainer/HealthLabel
@onready var wave_label: Label = $HUDPanel/VBoxContainer/WaveLabel
@onready var command_label: Label = $CommandPanel/CommandLabel
@onready var vbox: VBoxContainer = $HUDPanel/VBoxContainer

var gold_label: Label
var action_mode_label: Label
var context_label: Label

func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.money_changed.connect(_on_money_changed)
	_ensure_gold_label()
	_ensure_action_mode_label()
	_ensure_context_label()
	_on_health_changed(GameManager.player_health, GameManager.max_health)
	_on_money_changed(GameManager.player_money)
	set_action_mode_indicator(false)

func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HP: %d / %d" % [current, maximum]

func set_wave(wave: int) -> void:
	wave_label.text = "Wave: %d / %d" % [wave, GameManager.VICTORY_WAVE]


func _on_money_changed(current: int) -> void:
	if gold_label != null:
		gold_label.text = "Gold: %d" % current


func _ensure_gold_label() -> void:
	gold_label = vbox.get_node_or_null("GoldLabel")
	if gold_label != null:
		return

	gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	vbox.add_child(gold_label)
	vbox.move_child(gold_label, 1)


func _ensure_action_mode_label() -> void:
	action_mode_label = vbox.get_node_or_null("ActionModeLabel")
	if action_mode_label != null:
		return

	action_mode_label = Label.new()
	action_mode_label.name = "ActionModeLabel"
	action_mode_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(action_mode_label)
	vbox.move_child(action_mode_label, 3)


func _ensure_context_label() -> void:
	context_label = vbox.get_node_or_null("ContextLabel")
	if context_label != null:
		return

	context_label = Label.new()
	context_label.name = "ContextLabel"
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_label.add_theme_font_size_override("font_size", 13)
	context_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	vbox.add_child(context_label)
	vbox.move_child(context_label, 4)


func set_action_mode_indicator(enabled: bool) -> void:
	if action_mode_label == null:
		return

	if enabled:
		action_mode_label.text = "Mode: ACTION"
		action_mode_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65, 1.0))
	else:
		action_mode_label.text = "Mode: MOVE"
		action_mode_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45, 1.0))


func set_context_hint(message: String) -> void:
	if context_label != null:
		context_label.text = message


func show_command_feedback(message: String) -> void:
	if command_label != null:
		command_label.text = message
		var lowered := message.to_lower()
		if lowered.contains("not enough") or lowered.contains("locked") or lowered.contains("max") or lowered.contains("no tower"):
			command_label.modulate = Color(1.0, 0.55, 0.55)
		elif lowered.contains("placed") or lowered.contains("upgraded") or lowered.contains("sold") or lowered.contains("complete"):
			command_label.modulate = Color(0.55, 1.0, 0.65)
		else:
			command_label.modulate = Color(0.95, 0.95, 0.95)
	set_context_hint(message)


func show_tutorial_hint(message: String) -> void:
	if command_label != null:
		command_label.text = message
		command_label.modulate = Color(0.75, 1.0, 0.9)
