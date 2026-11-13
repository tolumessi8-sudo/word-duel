extends Screen
## Sound, username, help.

var _edit: LineEdit
var _msg: Label


func start(_args: Dictionary) -> void:
	var root := make_root(24)
	root.add_theme_constant_override("separation", 18)
	root.add_child(make_header("Settings"))

	var sound := CheckButton.new()
	sound.text = "Sound effects"
	sound.button_pressed = Game.sound_on
	sound.add_theme_font_size_override("font_size", 32)
	sound.focus_mode = Control.FOCUS_NONE
	sound.toggled.connect(func(on: bool) -> void:
		Game.sound_on = on
		Game.save_settings())
	root.add_child(sound)

	root.add_child(UI.label("Username", 30, UI.MUTED))
	_edit = LineEdit.new()
	_edit.text = str(Game.profile.get("name", ""))
	_edit.max_length = 16
	_edit.custom_minimum_size = Vector2(0, 88)
	root.add_child(_edit)
	var save := UI.btn("Save username", UI.ACCENT, 84, 30)
	save.pressed.connect(_save_name)
	root.add_child(save)
	_msg = UI.label("", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_msg)

	var how := UI.btn("How to play", UI.PANEL2, 80, 28)
	how.pressed.connect(show_howto)
	root.add_child(how)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)
	root.add_child(UI.label("Word Duel %s  -  by MSGames\nYour account is saved on this device. Ads shown are test ads." % Config.VERSION, 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func _save_name() -> void:
	var n := _edit.text.strip_edges()
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9_]{3,16}$")
	if re.search(n) == null:
		_msg.text = "Use 3-16 letters, numbers or _"
		_msg.add_theme_color_override("font_color", UI.BAD)
		return
	var r: Dictionary = await Game.call_api("set_name", {"p_name": n})
	if not is_inside_tree():
		return
	if r.get("ok", false):
		Game.set_profile(r["profile"])
		_msg.text = "Saved!"
		_msg.add_theme_color_override("font_color", UI.GOOD)
	else:
		_msg.text = str(r.get("error", "Could not save"))
		_msg.add_theme_color_override("font_color", UI.BAD)
