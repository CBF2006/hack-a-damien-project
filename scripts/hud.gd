extends CanvasLayer

@onready var health_bar: ProgressBar = $HUDPanel/VBoxContainer/HealthBar
@onready var health_label: Label = $HUDPanel/VBoxContainer/HealthLabel
@onready var wave_label: Label = $HUDPanel/VBoxContainer/WaveLabel
@onready var command_label: Label = $CommandPanel/CommandLabel
@onready var vbox: VBoxContainer = $HUDPanel/VBoxContainer

var gold_label: Label

func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.money_changed.connect(_on_money_changed)
	_ensure_gold_label()
	_on_health_changed(GameManager.player_health, GameManager.max_health)
	_on_money_changed(GameManager.player_money)

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


func show_command_feedback(message: String) -> void:
	if command_label != null:
		command_label.text = message
		command_label.modulate = Color(0.95, 0.95, 0.95)


func show_tutorial_hint(message: String) -> void:
	if command_label != null:
		command_label.text = message
		command_label.modulate = Color(0.75, 1.0, 0.9)
