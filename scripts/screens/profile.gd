extends Screen
## Player profile: stats, avatar picker and the coin shop (avatars + frames).

var _body: VBoxContainer
var _coins: PanelContainer
var _busy := false


func start(_args: Dictionary) -> void:
	var root := make_root(24)
	root.add_theme_constant_override("separation", 14)
	root.add_child(make_header("Profile"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	_body = UI.vbox(16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_build()


func _owned(id: String, price: int) -> bool:
	return price == 0 or (Game.profile.get("owned", []) as Array).has(id)


func _build() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var nm := str(Game.profile.get("name", ""))
	var d := Game.division()
	var cur_av := UI.my_avatar_index()
	var cur_fr := Game.pint("frame")

	# ---- hero
	var hero := UI.panel(Color("16263f").lerp(Game.division_color(d), 0.16), 32)
	var hv := UI.vbox(8)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(hv)
	var avrow := HBoxContainer.new()
	avrow.alignment = BoxContainer.ALIGNMENT_CENTER
	avrow.add_child(UI.my_avatar(170))
	hv.add_child(avrow)
	hv.add_child(UI.label(nm, 46, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var chips := UI.hbox(12)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_child(UI.chip("trophy", str(Game.pint("trophies"))))
	_coins = UI.chip("coin", str(Game.coins()), UI.ACCENT)
	chips.add_child(_coins)
	hv.add_child(chips)
	var dl := UI.label("%s division  -  rank #%d" % [Game.division_name(d), Game.pint("rank", 1)], 26, Game.division_color(d).lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, true)
	hv.add_child(dl)
	_body.add_child(hero)

	# ---- stats
	var w := Game.pint("wins")
	var l := Game.pint("losses")
	var dr := Game.pint("draws")
	var total := w + l + dr
	var rate := "%d%%" % int(round(100.0 * w / total)) if total > 0 else "-"
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for s in [["WINS", str(w), UI.GOOD], ["LOSSES", str(l), UI.BAD], ["DRAWS", str(dr), UI.ACCENT],
			["WIN RATE", rate, UI.TEXT], ["BEST STREAK", str(Game.pint("best_streak")), Color("ff9a3c")], ["DAILY STREAK", str(Game.pint("daily_streak")), UI.BLUE]]:
		var p := UI.panel(UI.PANEL, 20)
		(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 8
		(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 8
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(0)
		p.add_child(v)
		v.add_child(UI.label(str(s[1]), 44, s[2], HORIZONTAL_ALIGNMENT_CENTER))
		var cap := UI.label(str(s[0]), 19, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
		cap.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(cap)
		grid.add_child(p)
	_body.add_child(grid)

	# ---- avatars
	_body.add_child(UI.label("AVATARS", 38, UI.ACCENT))
	var ag := _grid(4)
	for i in 12:
		var id := "av_%d" % i
		var price: int = UI.AVATAR_PRICES[i]
		var owned := _owned(id, price)
		ag.add_child(_cell(UI.avatar(nm, 104, i, cur_fr), UI.AVATAR_NAMES[i], i == cur_av, owned, price,
			_tap.bind("avatar", i, id, price, UI.AVATAR_NAMES[i])))
	_body.add_child(ag)

	# ---- frames
	_body.add_child(UI.label("FRAMES", 38, UI.ACCENT))
	var fg := _grid(3)
	for i in UI.FRAMES.size():
		var id := "fr_%d" % i
		var price: int = UI.FRAME_PRICES[i]
		var owned := _owned(id, price)
		fg.add_child(_cell(UI.avatar(nm, 110, cur_av, i), UI.FRAME_NAMES[i], i == cur_fr, owned, price,
			_tap.bind("frame", i, id, price, UI.FRAME_NAMES[i] + " frame")))
	_body.add_child(fg)
	_body.add_child(UI.label("Earn coins by winning matches, daily puzzles and watching ads.", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_body.add_child(UI.spacer(12))


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	return g


func _cell(pic: Control, title: String, equipped: bool, owned: bool, price: int, on_tap: Callable) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 200)
	var col := UI.ACCENT if equipped else (Color("2c4466") if owned else Color("1b2c44"))
	var sb := UI.box(Color("1d3454") if owned else Color("131f33"), 22, 4 if equipped else 2, col)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var v := UI.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pr.add_child(pic)
	v.add_child(pr)
	if not owned:
		pic.modulate = Color(0.5, 0.5, 0.58)
	var tl := UI.label(title, 22, UI.TEXT if owned else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tl)
	if equipped:
		var u := UI.label("IN USE", 20, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, true)
		u.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(u)
	elif not owned:
		var pc := UI.chip("coin", str(price), UI.ACCENT)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pcr := HBoxContainer.new()
		pcr.alignment = BoxContainer.ALIGNMENT_CENTER
		pcr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pcr.add_child(pc)
		v.add_child(pcr)
	b.pressed.connect(on_tap)
	return b


func _tap(slot: String, idx: int, id: String, price: int, title: String) -> void:
	if _busy:
		return
	_busy = true
	var owned := _owned(id, price)
	if not owned:
		var yes: bool = await UI.confirm(self, "Buy %s?" % title, "Costs %d coins. You have %d." % [price, Game.coins()], "Buy", "Cancel")
		if not is_inside_tree():
			return
		if not yes:
			_busy = false
			return
		var r: Dictionary = await Game.call_api("buy_item", {"p_item": id})
		if not is_inside_tree():
			return
		if not r.get("ok", false):
			_busy = false
			UI.toast(self, "Not enough coins - win matches or watch ads!" if str(r.get("error", "")) == "not_enough_coins" else "Could not buy that")
			return
		Game.set_profile(r["profile"])
		Sfx.play("coin")
	var r2: Dictionary = await Game.call_api("equip_item", {"p_slot": slot, "p_idx": idx})
	if not is_inside_tree():
		return
	if r2.get("ok", false):
		Game.set_profile(r2["profile"])
		if not owned:
			UI.confetti(self, 40)
	_busy = false
	_build()
