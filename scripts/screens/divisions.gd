extends Screen
## The 7 divisions, from Rookie to Legend.


func start(_args: Dictionary) -> void:
	tab = "divisions"
	var root := make_root(24)
	root.add_child(make_title("Divisions", "crown"))
	var cur := Game.division()
	var tro := Game.pint("trophies")
	var hint := UI.label("Earn trophies to climb. Higher divisions mean harder puzzles and bigger rewards.", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	var list := UI.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in range(Config.DIVISIONS.size() - 1, -1, -1):
		var d := i + 1
		var info: Dictionary = Config.DIVISIONS[i]
		var here := d == cur
		var reached := tro >= int(info["from"])
		var col: Color = info["color"]
		var p := UI.panel(Color("16263f").lerp(col, 0.14 if reached else 0.0), 26)
		if here:
			var sb := UI.card_box(Color("16263f").lerp(col, 0.2), 26)
			sb.set_border_width_all(4)
			sb.border_color = UI.ACCENT
			p.add_theme_stylebox_override("panel", sb)
		var h := UI.hbox(18)
		p.add_child(h)
		var bw := Control.new()
		bw.custom_minimum_size = Vector2(130, 130)
		var b := Badge.new(d, 150)
		b.set_anchors_preset(Control.PRESET_CENTER)
		b.offset_left = -75
		b.offset_right = 75
		b.offset_top = -75
		b.offset_bottom = 75
		b.dimmed = not reached
		bw.add_child(b)
		if not reached:
			var lk := UI.icon("lock", 44)
			lk.set_anchors_preset(Control.PRESET_CENTER)
			lk.offset_left = -22
			lk.offset_right = 22
			lk.offset_top = -10
			lk.offset_bottom = 34
			bw.add_child(lk)
		h.add_child(bw)
		var v := UI.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v)
		var nm := UI.label(str(info["name"]).to_upper(), 40, col.lightened(0.2) if reached else UI.MUTED)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(nm)
		v.add_child(UI.label("YOU ARE HERE" if here else "%d trophies" % int(info["from"]), 24, UI.ACCENT if here else UI.TEXT))
		var rw := UI.hbox(8)
		rw.add_child(UI.chip("coin", "+%d" % (20 + 5 * d), UI.ACCENT))
		rw.add_child(UI.chip("crown", "+%d" % (100 * d), Color("ff9ad0")))
		v.add_child(rw)
		list.add_child(p)
	root.add_child(banner_strip())
