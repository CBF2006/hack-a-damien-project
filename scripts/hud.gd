extends CanvasLayer

@onready var health_bar: ProgressBar = $HUDPanel/VBoxContainer/HealthBar
@onready var health_label: Label = $HUDPanel/VBoxContainer/HealthLabel
@onready var wave_label: Label = $HUDPanel/VBoxContainer/WaveLabel

func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	_on_health_changed(GameManager.player_health, GameManager.max_health)

func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HP: %d / %d" % [current, maximum]

func set_wave(wave: int) -> void:
	wave_label.text = "Wave: %d / %d" % [wave, GameManager.VICTORY_WAVE]
