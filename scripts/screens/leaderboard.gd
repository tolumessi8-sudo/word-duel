extends Screen
## Global trophy ranking and today's daily-puzzle ranking.

var _tab := "trophies"
var _list: VBoxContainer
var _tab_btns: Dictionary = {}


func start(args: Dictionary) -> void:
	_tab = str(args.get("tab", "trophies"))
	var root := make_root(24)
	root.add_child(make_header("Leaderboard"))
	var tabs := UI.hbox(12)
	for t in [["trophies", "Trophies"], ["daily", "Today's Puzzle"]]:
		var b := UI.btn(str(t[1]), UI.PANEL2, 72, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = t[0]
		b.pressed.connect(func() -> void: _set_tab(key))
		tabs.add_child(b)
		_tab_btns[key] = b
	root.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = UI.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_set_tab(_tab)


func _set_tab(t: String) -> void:
	_tab = t
	for k in _tab_btns.keys():
		var b: Button = _tab_btns[k]
		b.add_theme_stylebox_override("normal", UI.box(UI.ACCENT if k == t else UI.PANEL2, 22))
		var fc := UI.DARK_TEXT if k == t else UI.TEXT
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, fc)
	_load()


func _clear() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()


func _load() -> void:
	_clear()
	_list.add_child(UI.label("Loading...", 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var mine := _tab
	var r: Dictionary = await Game.call_api("leaderboard" if mine == "trophies" else "daily_leaderboard")
	if not is_inside_tree() or mine != _tab:
		return
	_clear()
	if not r.get("ok", false):
		_list.add_child(UI.label("Could not load the leaderboard.", 28, UI.BAD, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var rows: Array = r.get("rows", [])
	if rows.is_empty():
		_list.add_child(UI.label("Nobody here yet. Be the first!", 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var rank := 1
	for row in rows:
		var me: bool = bool(row.get("me", false))
		var p := UI.panel(Color("3b2a05") if me else UI.PANEL, 18)
		var h := UI.hbox(14)
		p.add_child(h)
		var rl := UI.label("#%d" % rank, 28, UI.ACCENT if rank <= 3 else UI.MUTED)
		rl.custom_minimum_size = Vector2(80, 0)
		rl.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(rl)
		var nl := UI.label(str(row.get("name", "")), 30, UI.TEXT)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(nl)
		var value := ""
		if mine == "trophies":
			value = "%d  %s" % [int(row.get("trophies", 0)), Game.division_name(int(row.get("division", 1)))]
		else:
			value = "%d moves  %s" % [int(row.get("moves", 0)), UI.fmt_time(float(row.get("seconds", 0)))]
		var vl := UI.label(value, 26, UI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		vl.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(vl)
		_list.add_child(p)
		rank += 1
	if mine == "trophies" and r.has("my_rank"):
		_list.add_child(UI.label("Your rank: #%d" % int(r["my_rank"]), 28, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
