extends Screen
## Private matches with a 4-letter room code. No trophies are at stake.

var _edit: LineEdit
var _err: Label
var _code_box: VBoxContainer
var _menu_box: VBoxContainer
var _code_l: Label
var _match_id := ""
var _timer: Timer
var _busy := false


func start(_args: Dictionary) -> void:
	var root := make_root(24)
	root.add_theme_constant_override("separation", 18)
	root.add_child(make_header("Play a Friend"))

	_menu_box = UI.vbox(18)
	root.add_child(_menu_box)
	_menu_box.add_child(UI.label("Create a room and send the code to your friend (WhatsApp, SMS...). The match starts when they join.", 26, UI.MUTED))
	var create := UI.btn("CREATE ROOM", UI.ACCENT, 100, 36)
	create.pressed.connect(_create)
	_menu_box.add_child(create)
	_menu_box.add_child(UI.spacer(10))
	_menu_box.add_child(UI.label("Got a code from a friend?", 30, UI.TEXT))
	_edit = LineEdit.new()
	_edit.placeholder_text = "ROOM CODE"
	_edit.max_length = 4
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.custom_minimum_size = Vector2(0, 100)
	_edit.add_theme_font_size_override("font_size", 52)
	_edit.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			_edit.text = up
			_edit.caret_column = up.length())
	_edit.text_submitted.connect(func(_t: String) -> void: _join())
	_menu_box.add_child(_edit)
	var join := UI.btn("JOIN ROOM", UI.BLUE, 92, 34)
	join.pressed.connect(_join)
	_menu_box.add_child(join)
	_err = UI.label("", 26, UI.BAD, HORIZONTAL_ALIGNMENT_CENTER)
	_menu_box.add_child(_err)

	_code_box = UI.vbox(20)
	_code_box.hide()
	root.add_child(_code_box)
	_code_box.add_child(UI.label("Your room code", 32, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_code_l = UI.label("", 110, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_code_box.add_child(_code_l)
	_code_box.add_child(UI.label("Waiting for your friend to join...", 28, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var copy := UI.btn("Copy code", UI.PANEL2, 80, 28)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_code_l.text)
		UI.toast(self, "Code copied"))
	_code_box.add_child(copy)
	var cancel := UI.btn("Cancel room", UI.PANEL2, 80, 28)
	cancel.pressed.connect(on_back)
	_code_box.add_child(cancel)

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_poll)
	add_child(_timer)


func on_back() -> void:
	_timer.stop()
	if _match_id != "":
		await Game.call_api("cancel_match", {"mid": _match_id})
	if is_inside_tree():
		go("home")


func _create() -> void:
	var r: Dictionary = await Game.call_api("create_room")
	if not is_inside_tree():
		return
	if not r.get("ok", false):
		_err.text = "Could not create a room. Check your internet."
		return
	_match_id = str(r["match_id"])
	_code_l.text = str(r["code"])
	_menu_box.hide()
	_code_box.show()
	_timer.start()


func _join() -> void:
	var code := _edit.text.strip_edges().to_upper()
	if code.length() != 4:
		_err.text = "Enter the 4-letter code"
		return
	_err.text = ""
	var r: Dictionary = await Game.call_api("join_room", {"p_code": code})
	if not is_inside_tree():
		return
	if r.get("ok", false):
		go("match", {"mode": "friendly", "match_id": str(r["match_id"])})
	else:
		_err.text = str(r.get("error", "Could not join that room"))


func _poll() -> void:
	if _busy or _match_id == "":
		return
	_busy = true
	var r: Dictionary = await Game.call_api("poll_match", {"mid": _match_id})
	_busy = false
	if not is_inside_tree():
		return
	if r.get("ok", false) and str(r["state"].get("status", "")) != "waiting":
		_timer.stop()
		go("match", {"mode": "friendly", "match_id": _match_id})
