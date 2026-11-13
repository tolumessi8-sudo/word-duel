class_name Keyboard
extends VBoxContainer
## On-screen letter keyboard. Emits key("a") .. key("z").

signal key(letter: String)

const ROWS := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
var _buttons: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 10)
	for row in ROWS:
		var h := UI.hbox(8)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		for ch in row:
			var b := UI.btn(ch.to_upper(), UI.PANEL2, 84, 34)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 84)
			b.pressed.connect(func() -> void: key.emit(ch))
			h.add_child(b)
			_buttons[ch] = b
		add_child(h)


func highlight(letter: String) -> void:
	for ch in _buttons.keys():
		var b: Button = _buttons[ch]
		var on: bool = ch == letter.to_lower()
		var color: Color = UI.GOOD if on else UI.PANEL2
		b.add_theme_stylebox_override("normal", UI.box(color, 22))
		var fc := UI.DARK_TEXT if on else UI.TEXT
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, fc)
