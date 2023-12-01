extends Button

signal on_toggled(pressed: bool, index: int)

func _ready() -> void:
	text = "%s" % (get_index() % 9)

func _on_toggled(_button_pressed) -> void:
	on_toggled.emit(_button_pressed,get_index())
