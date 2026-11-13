extends Screen
## The 7 divisions, from Rookie to Legend.


func start(_args: Dictionary) -> void:
	var root := make_root(24)
	root.add_child(make_header("Divisions"))
	var cur := Game.division()
	var tro := Game.pint("trophies")
	root.add_child(UI.label("Win matches to earn trophies. Reach the next trophy mark to move up. Higher divisions mean harder puzzles and bigger rewards.", 24, UI.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := UI.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in range(Config.DIVISIONS.size() - 1, -1, -1):
		var d := i + 1
		var info: Dictionary = Config.DIVISIONS[i]
		var here := d == cur
		var reached := tro >= int(info["from"])
		var p := UI.panel(Color("2b3f5c") if here else UI.PANEL, 22)
		if here:
			p.add_theme_stylebox_override("panel", UI.box(Color("2b3f5c"), 22, 4, UI.ACCENT))
		var h := UI.hbox(16)
		p.add_child(h)
		var b := Badge.new(d, 100)
		b.dimmed = not reached
		h.add_child(b)
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var name_text := "%s%s" % [str(info["name"]), "   <- YOU" if here else ""]
		v.add_child(UI.label(name_text, 34, info["color"] if reached else UI.MUTED))
		v.add_child(UI.label("From %d trophies" % int(info["from"]), 24, UI.TEXT))
		v.add_child(UI.label("Puzzles: " + str(info["puzzle"]), 22, UI.MUTED))
		v.add_child(UI.label("Win reward: %d coins   Season reward: %d coins" % [20 + 5 * d, 100 * d], 22, UI.ACCENT))
		list.add_child(p)
	root.add_child(banner_strip())
