extends CanvasLayer

@onready var health_bar: ProgressBar = $HUDPanel/VBoxContainer/HealthBar
@onready var health_label: Label = $HUDPanel/VBoxContainer/HealthLabel
@onready var wave_label: Label = $HUDPanel/VBoxContainer/WaveLabel
@onready var command_label: Label = $CommandPanel/CommandLabel
@onready var vbox: VBoxContainer = $HUDPanel/VBoxContainer

var gold_label: Label
var action_panel: PanelContainer

func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.money_changed.connect(_on_money_changed)
	_ensure_gold_label()
	_ensure_action_panel()
	_on_health_changed(GameManager.player_health, GameManager.max_health)
	_on_money_changed(GameManager.player_money)

	var joystick = get_tree().get_first_node_in_group("joystick_controller")
	if joystick:
		joystick.action_mode_toggled.connect(_on_action_mode_toggled)

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

func _ensure_action_panel() -> void:
	action_panel = PanelContainer.new()
	action_panel.name = "ActionPanel"
	action_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	action_panel.offset_top = -160
	action_panel.offset_bottom = -20
	action_panel.offset_left = 80
	action_panel.offset_right = -80

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	action_panel.add_child(vb)

	var title := Label.new()
	title.text = "⚔ ACTION MODE"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	vb.add_child(HSeparator.new())

	var actions := [
		"⬆⬆  Place Tower  (25g)",
		"⬆⬇  Upgrade Tower",
		"⬇⬇⬇  Sell Tower  (65% refund)",
		"➡⬅➡⬅  Open Shop",
	]
	for line in actions:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lbl)

	action_panel.visible = false
	add_child(action_panel)

func _on_action_mode_toggled(enabled: bool) -> void:
	if action_panel:
		action_panel.visible = enabled

func show_command_feedback(message: String) -> void:
	if command_label != null:
		command_label.text = message
		command_label.modulate = Color(0.95, 0.95, 0.95)

func show_tutorial_hint(message: String) -> void:
	if command_label != null:
		command_label.text = message
		command_label.modulate = Color(0.75, 1.0, 0.9)
