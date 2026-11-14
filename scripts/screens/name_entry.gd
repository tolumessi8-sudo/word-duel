extends Screen
## First launch: pick a username. The account is created on the server and saved on the device.

var _edit: LineEdit
var _err: Label
var _btn: Button


func start(args: Dictionary) -> void:
	var v := make_root()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	var logo := TextureRect.new()
	logo.texture = UI.tex("res://art/logo.png")
	logo.custom_minimum_size = Vector2(0, 330)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(logo)
	v.add_child(UI.label("Race your opponent from one word to another, one letter at a time.", 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(20))
	var notice := str(args.get("notice", ""))
	if notice != "":
		v.add_child(UI.label(notice, 26, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Choose your username", 34, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_edit = LineEdit.new()
	_edit.placeholder_text = "3-16 letters, numbers or _"
	_edit.max_length = 16
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.custom_minimum_size = Vector2(0, 90)
	_edit.text_submitted.connect(func(_t: String) -> void: _submit())
	v.add_child(_edit)
	_err = UI.label("", 26, UI.BAD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_err)
	_btn = UI.btn("START PLAYING", UI.GOOD, 108, 40)
	_btn.pressed.connect(_submit)
	v.add_child(_btn)


func on_back() -> void:
	pass


func valid_name(n: String) -> bool:
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9_]{3,16}$")
	return re.search(n) != null


func _submit() -> void:
	var n := _edit.text.strip_edges()
	if not valid_name(n):
		_err.text = "Use 3-16 letters, numbers or _ (no spaces)"
		return
	_err.text = ""
	_btn.disabled = true
	_btn.text = "Creating account..."
	var r: Dictionary = await Api.call_rpc("register_player", {"p_name": n})
	if not is_inside_tree():
		return
	if r.get("ok", false):
		Game.set_account(str(r["id"]), str(r["secret"]))
		await Game.refresh_profile()
		if is_inside_tree():
			go("home", {"welcome": true})
		return
	_btn.disabled = false
	_btn.text = "START PLAYING"
	if r.get("net", false):
		_err.text = "Can't reach the server. Check your internet."
	else:
		_err.text = str(r.get("error", "Could not create the account"))
