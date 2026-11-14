extends Screen
## Global trophy ranking and today's daily-puzzle ranking.

var _tab := "trophies"
var _list: VBoxContainer
var _tab_btns: Dictionary = {}


func start(args: Dictionary) -> void:
	_tab = str(args.get("tab", "trophies"))
	tab = "leaderboard"
	var root := make_root(24)
	root.add_child(make_title("Ranks", "ranks"))
	var tabs := UI.hbox(12)
	for t in [["trophies", "Trophies"], ["daily", "Today's Puzzle"]]:
		var b := UI.btn(str(t[1]).to_upper(), UI.PANEL2, 72, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = t[0]
		b.pressed.connect(func() -> void: _set_tab(key))
		tabs.add_child(b)
		_tab_btns[key] = b
	root.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	_list = UI.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_set_tab(_tab)


func _set_tab(t: String) -> void:
	_tab = t
	for k in _tab_btns.keys():
		var b: Button = _tab_btns[k]
		var on: bool = k == t
		b.add_theme_stylebox_override("normal", UI.chunk(UI.ACCENT if on else Color("22364f"), 24, 8))
		b.add_theme_stylebox_override("hover", UI.chunk(UI.ACCENT if on else Color("22364f"), 24, 8))
		var fc := UI.DARK_TEXT if on else UI.MUTED
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
		var medal := [Color("ffc933"), Color("c0c7d1"), Color("cd7f32")]
		var base := Color("4a3406") if me else (Color("16263f").lerp(medal[rank - 1], 0.18) if rank <= 3 else UI.PANEL)
		var p := UI.panel(base, 22)
		(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 10
		(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 10
		var h := UI.hbox(14)
		p.add_child(h)
		var rw := Control.new()
		rw.custom_minimum_size = Vector2(64, 64)
		if rank <= 3:
			var ic := UI.icon("crown" if rank == 1 else "star", 60)
			ic.modulate = Color.WHITE if rank == 1 else (Color("e4ecf7") if rank == 2 else Color("e8a76a"))
			ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			rw.add_child(ic)
		else:
			var rl := UI.label("%d" % rank, 32, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
			rl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			rw.add_child(rl)
		h.add_child(rw)
		h.add_child(UI.avatar(str(row.get("name", "")), 64))
		var nl := UI.label(str(row.get("name", "")), 30, UI.ACCENT if me else UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.clip_text = true
		h.add_child(nl)
		if mine == "trophies":
			h.add_child(Badge.new(int(row.get("division", 1)), 64))
			var tc := UI.chip("trophy", str(int(row.get("trophies", 0))))
			tc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(tc)
		else:
			var vl := UI.label("%d moves  %s" % [int(row.get("moves", 0)), UI.fmt_time(float(row.get("seconds", 0)))], 26, UI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
			vl.autowrap_mode = TextServer.AUTOWRAP_OFF
			vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(vl)
		_list.add_child(p)
		rank += 1
	if mine == "trophies" and r.has("my_rank"):
		_list.add_child(UI.label("Your rank: #%d" % int(r["my_rank"]), 28, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
