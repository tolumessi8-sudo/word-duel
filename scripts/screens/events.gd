extends Screen
## Weekend matches + live events (events are rows in the database, see README).


func start(_args: Dictionary) -> void:
	var root := make_root(24)
	root.add_child(make_header("Events"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := UI.vbox(16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var weekend := bool(Game.profile.get("weekend", false))
	var wp := UI.panel(Color("2e1f5c") if weekend else UI.PANEL, 24)
	var wv := UI.vbox(8)
	wp.add_child(wv)
	wv.add_child(UI.label("Weekend Matches", 40, UI.PURPLE.lightened(0.3)))
	wv.add_child(UI.label("OPEN NOW - play for bigger rewards!" if weekend else "Opens Saturday - closes Sunday night", 28, UI.GOOD if weekend else UI.MUTED))
	wv.add_child(UI.label("- Puzzles are one division harder\n- Win: +40 trophies and 60 coins\n- If it is a draw, the player with the FEWEST MOVES wins", 26, UI.TEXT))
	if weekend:
		var play := UI.btn("PLAY WEEKEND MATCH", UI.PURPLE, 90, 32)
		play.pressed.connect(func() -> void: go("match", {"mode": "weekend"}))
		wv.add_child(play)
	list.add_child(wp)

	var events: Array = Game.profile.get("events", [])
	if events.is_empty():
		list.add_child(UI.label("No special events right now. Check back soon!", 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for e in events:
		var p := UI.panel(Color("3b2a05"), 24)
		var v := UI.vbox(6)
		p.add_child(v)
		v.add_child(UI.label(str(e.get("title", "")), 36, UI.ACCENT))
		v.add_child(UI.label(str(e.get("description", "")), 28, UI.TEXT))
		var secs := int(e.get("ends_in", 0))
		var days := secs / 86400
		var hours := (secs % 86400) / 3600
		v.add_child(UI.label("Ends in %dd %dh" % [days, hours], 24, UI.MUTED))
		list.add_child(p)
	root.add_child(banner_strip())
