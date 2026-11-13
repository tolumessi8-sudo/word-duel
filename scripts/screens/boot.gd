extends Screen
## Splash: checks the saved account and loads the profile.

var _status: Label
var _retry: Button


func start(_args: Dictionary) -> void:
	var v := make_root()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	v.add_child(UI.label("WORD DUEL", 80, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Change one letter at a time", 30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_status = UI.label("Connecting...", 28, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_status)
	_retry = UI.btn("Retry", UI.ACCENT, 84, 32)
	_retry.pressed.connect(_connect)
	_retry.hide()
	v.add_child(_retry)
	_connect()


func on_back() -> void:
	pass


func _connect() -> void:
	_retry.hide()
	_status.text = "Connecting..."
	if not Game.has_account():
		go("name")
		return
	var r: Dictionary = await Game.refresh_profile()
	if not is_inside_tree():
		return
	if r.get("ok", false):
		go("home", {"season": r.get("season_reward")})
		return
	if r.get("net", false):
		_status.text = "Can't reach the server.\nCheck your internet connection."
	else:
		_status.text = "Something went wrong (%s)." % str(r.get("error", "unknown"))
	_retry.show()
