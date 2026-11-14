extends Screen
## Live match: matchmaking -> countdown -> race -> result.

var mode := "ranked"
var match_id := ""
var st: Dictionary = {}
var phase := "search"        # search | countdown | play | done
var start_at_ms := 0
var deadline_ms := 0
var finished := false
var poll_busy := false
var submitting := false
var hint_busy := false
var poll_timer: Timer
var _last_count := -1
var _div_before := 1

var _title: Label
var _timer_l: Label
var _opp_name: Label
var _opp_info: Label
var _opp_av: TextureRect
var _opp_bar: ProgressBar
var _me_info: Label
var _me_bar: ProgressBar
var _status: Label
var _board: LadderBoard
var _kb: Keyboard
var _hint_btn: Button
var _overlay: Control
var _overlay_label: Label
var _overlay_sub: Label
var _cancel_btn: Button


func start(args: Dictionary) -> void:
	mode = str(args.get("mode", "ranked"))
	_div_before = Game.division()
	match_id = str(args.get("match_id", ""))
	_build()
	poll_timer = Timer.new()
	poll_timer.wait_time = 1.0
	poll_timer.timeout.connect(_poll)
	add_child(poll_timer)
	if match_id == "":
		_overlay_label.text = "Finding an opponent..."
		_overlay_sub.text = "You both get the same puzzle"
		var r: Dictionary = await Game.call_api("find_match", {"p_mode": mode})
		if not is_inside_tree():
			return
		if not r.get("ok", false):
			var msg := "Could not start a match."
			if str(r.get("error", "")) == "weekend_closed":
				msg = "Weekend matches are only open on Saturday and Sunday."
			elif r.get("net", false):
				msg = "No connection to the server."
			await UI.choose(self, "Can't start", msg, ["OK"], [UI.ACCENT])
			if is_inside_tree():
				go("home")
			return
		match_id = str(r["match_id"])
	else:
		_overlay_label.text = "Starting..."
		_overlay_sub.text = ""
	poll_timer.start()
	_poll()


func _moves_text(n: int) -> String:
	return "%d move%s" % [n, "" if n == 1 else "s"]


func _f(v, d := 0.0) -> float:
	return float(v) if v != null else d


# ------------------------------------------------------------------ UI

func _build() -> void:
	var root := make_root(20)
	root.add_theme_constant_override("separation", 12)

	var h := UI.hbox(12)
	var back := UI.btn("LEAVE", Color("b4443a"), 64, 24)
	back.custom_minimum_size = Vector2(130, 64)
	back.pressed.connect(on_back)
	h.add_child(back)
	_title = UI.label("", 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(_title)
	var tc := UI.chip("bolt", "--:--", UI.ACCENT)
	_timer_l = tc.get_meta("lbl")
	tc.custom_minimum_size = Vector2(170, 0)
	h.add_child(tc)
	root.add_child(h)

	var vs := UI.hbox(10)
	vs.add_child(_side(false))
	var vsl := UI.label("VS", 34, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	vsl.autowrap_mode = TextServer.AUTOWRAP_OFF
	vsl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vs.add_child(vsl)
	vs.add_child(_side(true))
	root.add_child(vs)

	_board = LadderBoard.new()
	_board.move_made.connect(_on_move)
	root.add_child(_board)

	_status = UI.label("", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_status.custom_minimum_size = Vector2(0, 30)
	root.add_child(_status)

	_hint_btn = UI.btn("HINT  (15 coins / ad)", Color("3b82f6"), 68, 24, "bulb")
	_hint_btn.pressed.connect(_on_hint)
	root.add_child(_hint_btn)

	_kb = Keyboard.new()
	_kb.key.connect(_board.input_letter)
	root.add_child(_kb)

	# search / countdown overlay
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UI.BG, 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(c)
	var ov := UI.vbox(24)
	ov.custom_minimum_size = Vector2(560, 0)
	c.add_child(ov)
	_overlay_label = UI.label("", 150, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	ov.add_child(_overlay_label)
	_overlay_sub = UI.label("", 30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	ov.add_child(_overlay_sub)
	_cancel_btn = UI.btn("CANCEL", UI.PANEL2, 80, 28)
	_cancel_btn.pressed.connect(on_back)
	ov.add_child(_cancel_btn)
	add_child(_overlay)


func _side(opp: bool) -> Control:
	var p := UI.panel(Color("2a1a22") if opp else Color("173326"), 22)
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(8)
	p.add_child(v)
	var row := UI.hbox(10)
	var av := UI.avatar("opponent" if opp else str(Game.profile.get("name", "")), 68)
	row.add_child(av)
	var col := UI.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := UI.label("Opponent" if opp else "You", 26, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	col.add_child(nm)
	var info := UI.label("" if opp else "0 moves", 22, UI.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(info)
	row.add_child(col)
	v.add_child(row)
	var bar := UI.bar(4, UI.BAD if opp else UI.GOOD, 16)
	v.add_child(bar)
	if opp:
		_opp_name = nm
		_opp_info = info
		_opp_bar = bar
		_opp_av = av
	else:
		_me_info = info
		_me_bar = bar
	return p


# ------------------------------------------------------------------ flow

func on_back() -> void:
	if finished:
		go("home")
		return
	if phase == "search":
		poll_timer.stop()
		if match_id != "":
			await Game.call_api("cancel_match", {"mid": match_id})
		if is_inside_tree():
			go("home")
		return
	var yes: bool = await UI.confirm(self, "Leave the match?", "You will lose this match.", "Leave", "Stay")
	if yes and not finished:
		poll_timer.stop()
		await Game.call_api("forfeit_match", {"mid": match_id})
		if is_inside_tree():
			go("home")


func _process(_delta: float) -> void:
	if phase == "countdown":
		var left_ms := start_at_ms - Time.get_ticks_msec()
		if left_ms <= 0:
			_begin_play()
		else:
			var n := int(ceil(left_ms / 1000.0))
			if n != _last_count:
				_last_count = n
				_overlay_label.text = str(n)
				_overlay_label.pivot_offset = _overlay_label.size / 2.0
				_overlay_label.scale = Vector2(1.7, 1.7)
				_overlay_label.modulate.a = 0.2
				var tw := _overlay_label.create_tween().set_parallel()
				tw.tween_property(_overlay_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(_overlay_label, "modulate:a", 1.0, 0.2)
				Sfx.play("tick")
	elif phase == "play":
		var left := (deadline_ms - Time.get_ticks_msec()) / 1000.0
		_timer_l.text = UI.fmt_time(left)
		_timer_l.add_theme_color_override("font_color", UI.BAD if left < 10.0 else UI.ACCENT)


func _begin_play() -> void:
	phase = "play"
	_overlay.hide()
	_board.enabled = not bool(st.get("my_done", false))
	_status.text = "Go! Tap a tile, then a letter."
	Sfx.play("go")


func _poll() -> void:
	if poll_busy or finished or match_id == "":
		return
	poll_busy = true
	var r: Dictionary = await Game.call_api("poll_match", {"mid": match_id})
	poll_busy = false
	if not is_inside_tree() or finished:
		return
	if r.get("net", false):
		_status.text = "Connection problem... retrying"
		return
	if not r.get("ok", false):
		if str(r.get("error", "")) == "no_match":
			go("home")
		return
	_apply_state(r["state"])


func _same_words(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i]) != str(b[i]):
			return false
	return true


func _apply_state(s: Dictionary) -> void:
	st = s
	if str(s.get("status", "")) == "waiting":
		return
	var now := Time.get_ticks_msec()
	start_at_ms = now + int(_f(s.get("starts_in")) * 1000.0)
	deadline_ms = now + int(_f(s.get("time_left")) * 1000.0)
	var shortest := int(s.get("shortest", 4))
	var m := str(s.get("mode", mode))
	_title.text = "FRIEND MATCH" if m == "friendly" else "%s  -  %s" % [m.to_upper(), Game.division_name(int(s.get("division", 1)))]
	_opp_name.text = str(s.get("opp_name", "Opponent"))
	_opp_av.texture = UI.tex("res://art/avatars/av_%d.png" % UI.avatar_index(_opp_name.text))
	_opp_bar.max_value = shortest
	_opp_bar.value = clampi(shortest - int(_f(s.get("opp_dist"), shortest)), 0, shortest)
	_opp_info.text = "FINISHED" if bool(s.get("opp_done", false)) else _moves_text(int(_f(s.get("opp_moves"))))
	if phase == "search":
		phase = "countdown"
		_board.setup(str(s["start"]), str(s["target"]), s.get("my_words", []))
		_overlay_sub.text = "vs %s" % str(s.get("opp_name", "Opponent"))
		_overlay_label.text = ""
		_cancel_btn.hide()
		Sfx.play("good")
	elif not submitting:
		var mw: Array = s.get("my_words", [])
		if not _same_words(mw, _board.words):
			_board.setup(str(s["start"]), str(s["target"]), mw)
	_update_me()
	if s.get("result") != null:
		if not finished:
			_finish(s)
		return
	if bool(s.get("my_done", false)):
		_board.enabled = false
		_status.text = "You made it! Waiting for the result..."
	_status.add_theme_color_override("font_color", UI.MUTED)


func _update_me() -> void:
	var shortest := int(st.get("shortest", 4))
	var cur := _board.current()
	_me_bar.max_value = shortest
	_me_bar.value = clampi(shortest - Game.local_dist(cur, _board.target_word), 0, shortest)
	_me_info.text = _moves_text(_board.words.size())


func _on_move(word: String) -> void:
	_kb.highlight("")
	_update_me()
	if _board.is_solved():
		_board.enabled = false
		_status.text = "You made it! Waiting for the result..."
	submitting = true
	var r: Dictionary = await Game.call_api("submit_move", {"mid": match_id, "p_word": word})
	submitting = false
	if not is_inside_tree():
		return
	if r.get("ok", false):
		_apply_state(r["state"])
	elif r.has("state"):
		_apply_state(r["state"])
	else:
		_status.text = "Move not accepted - resyncing"
		_poll()


func _on_hint() -> void:
	if phase != "play" or hint_busy or submitting or _board.is_solved():
		return
	if int(st.get("my_hints", 0)) >= 2:
		UI.toast(self, "No hints left in this match")
		return
	var choice: int = await UI.choose(self, "Need a hint?", "Shows which letter to change next.",
		["Use 15 coins", "Watch an ad (free)", "Cancel"], [UI.ACCENT, UI.BLUE, UI.PANEL2])
	if choice < 0 or choice == 2 or not is_inside_tree() or finished:
		return
	var via_ad := choice == 1
	hint_busy = true
	if via_ad:
		var watched: bool = await Ads.show_rewarded()
		if not watched:
			hint_busy = false
			UI.toast(self, "Watch the whole ad to get a hint")
			return
	var r: Dictionary = await Game.call_api("get_hint", {"mid": match_id, "via_ad": via_ad})
	hint_busy = false
	if not is_inside_tree() or finished:
		return
	if r.get("ok", false):
		_board.show_hint(int(r["pos"]), str(r["letter"]))
		_kb.highlight(str(r["letter"]))
		st["my_hints"] = int(st.get("my_hints", 0)) + 1
		if not via_ad:
			Game.profile["coins"] = int(r.get("coins", Game.coins()))
			Game.profile_changed.emit()
	else:
		UI.toast(self, str(r.get("error", "No hint available")))


# ------------------------------------------------------------------ result

func _finish(s: Dictionary) -> void:
	finished = true
	phase = "done"
	poll_timer.stop()
	_board.enabled = false
	_overlay.hide()
	var res := str(s.get("result"))
	Sfx.play("win" if res == "win" else ("lose" if res == "lose" else "draw"))
	UI.buzz(120 if res == "win" else 60)
	await Game.refresh_profile()
	if is_inside_tree():
		_show_result(s, res)


func _reason_text(res: String, reason: String) -> String:
	match reason:
		"photo_finish":
			return "Photo finish! You both finished within a second."
		"moves":
			return "Tie-break: you used fewer moves!" if res == "win" else "Tie-break: your opponent used fewer moves."
		"timeout":
			if res == "draw":
				return "Time's up and you were equally close."
			return "Time's up. You were closer to the target!" if res == "win" else "Time's up. Your opponent was closer."
		"forfeit":
			return "Your opponent left the match." if res == "win" else "You left the match."
	return "You reached the target first!" if res == "win" else "Your opponent got there first."


func _count_up(l: Label, to: int, fmt: String, delay := 0.0) -> void:
	l.text = fmt % 0
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float) -> void: l.text = fmt % int(round(v)), 0.0, float(to), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_result(s: Dictionary, res: String) -> void:
	var m := str(s.get("mode", mode))
	var overlay := Control.new()
	overlay.z_index = 100
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(c)
	var color := UI.GOOD if res == "win" else (UI.BAD if res == "lose" else UI.ACCENT)
	var p := UI.panel(Color("16263f").lerp(color, 0.12), 34)
	var ps := p.get_theme_stylebox("panel") as StyleBoxFlat
	ps.set_border_width_all(3)
	ps.border_width_bottom = 8
	ps.border_color = color.darkened(0.1)
	p.custom_minimum_size = Vector2(620, 0)
	c.add_child(p)
	var v := UI.vbox(14)
	p.add_child(v)
	# hero: rays + icon
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 190)
	v.add_child(hero)
	var rays := TextureRect.new()
	rays.texture = UI.tex("res://art/fx/sunburst.png")
	rays.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.set_anchors_preset(Control.PRESET_CENTER)
	rays.offset_left = -300
	rays.offset_right = 300
	rays.offset_top = -300
	rays.offset_bottom = 300
	rays.pivot_offset = Vector2(300, 300)
	rays.modulate = Color(color.lightened(0.3), 0.6 if res != "lose" else 0.2)
	hero.add_child(rays)
	rays.create_tween().set_loops().tween_property(rays, "rotation", TAU, 30.0)
	var icon_name := "trophy" if res == "win" else ("bolt" if res == "draw" else "flame")
	var ic := UI.icon(icon_name, 170)
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.offset_left = -85
	ic.offset_right = 85
	ic.offset_top = -85
	ic.offset_bottom = 85
	ic.pivot_offset = Vector2(85, 85)
	if res == "lose":
		ic.modulate = Color(0.6, 0.65, 0.8)
	hero.add_child(ic)
	var title := "VICTORY!" if res == "win" else ("DEFEAT" if res == "lose" else "DRAW")
	var tl := UI.label(title, 84, color, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(tl)
	v.add_child(UI.label(_reason_text(res, str(s.get("reason", ""))), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var wl := UI.label("%s  >  %s" % [str(s.get("start", "")).to_upper(), str(s.get("target", "")).to_upper()],
		30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	v.add_child(wl)
	var td := int(_f(s.get("trophy_delta")))
	var coins := int(_f(s.get("coin_delta")))
	var chips := UI.hbox(14)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	var tro_chip: PanelContainer = null
	if m != "friendly":
		tro_chip = UI.chip("trophy", "0", UI.GOOD if td > 0 else (UI.BAD if td < 0 else UI.MUTED))
		chips.add_child(tro_chip)
	var coin_chip := UI.chip("coin", "0", UI.ACCENT)
	chips.add_child(coin_chip)
	v.add_child(chips)
	if tro_chip != null:
		_count_up(tro_chip.get_meta("lbl"), td, "+%d" if td > 0 else "%d", 0.45)
	_count_up(coin_chip.get_meta("lbl"), coins, "+%d", 0.7)
	var streak := Game.pint("streak")
	if res == "win" and streak >= 2:
		var sc := UI.chip("flame", "%d win streak!" % streak, Color("ff9a3c"))
		var sr := UI.hbox(0)
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		sr.add_child(sc)
		v.add_child(sr)
	if coins > 0 and not bool(s.get("doubled", false)):
		var dbl := UI.btn("DOUBLE COINS  (ad)", UI.BLUE, 84, 28, "video")
		dbl.pressed.connect(func() -> void:
			dbl.disabled = true
			var ok: bool = await Ads.show_rewarded()
			if not is_inside_tree():
				return
			if ok:
				var r: Dictionary = await Game.call_api("double_reward", {"mid": match_id})
				if is_inside_tree() and r.get("ok", false):
					Game.set_profile(r["profile"])
					UI.chip_set(coin_chip, "+%d (x2)" % (coins * 2))
					Sfx.play("coin")
					UI.confetti(self, 30)
					dbl.hide()
					return
			dbl.disabled = false)
		v.add_child(dbl)
	var again := UI.btn("PLAY AGAIN", UI.GOOD, 92, 34, "swords")
	again.pressed.connect(func() -> void:
		again.disabled = true
		await Ads.after_match()
		if is_inside_tree():
			go("friend" if m == "friendly" else "match", {} if m == "friendly" else {"mode": m}))
	v.add_child(again)
	var home := UI.btn("HOME", UI.PANEL2, 76, 30)
	home.pressed.connect(func() -> void:
		home.disabled = true
		await Ads.after_match()
		if is_inside_tree():
			go("home"))
	v.add_child(home)
	add_child(overlay)
	# entrance
	p.pivot_offset = Vector2(310, 360)
	p.scale = Vector2(0.7, 0.7)
	p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	ic.scale = Vector2(0.3, 0.3)
	ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.6).set_delay(0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if res == "win":
		UI.confetti(overlay)
	var nd := Game.division()
	if m != "friendly" and nd > _div_before:
		await get_tree().create_timer(1.8).timeout
		if is_inside_tree():
			_show_promotion(nd)


func _show_promotion(d: int) -> void:
	var overlay := Control.new()
	overlay.z_index = 150
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.09, 0.95)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var col := Game.division_color(d)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(c)
	var v := UI.vbox(10)
	v.custom_minimum_size = Vector2(620, 0)
	c.add_child(v)
	v.add_child(UI.label("PROMOTED!", 80, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 520)
	v.add_child(hero)
	var rays := TextureRect.new()
	rays.texture = UI.tex("res://art/fx/sunburst.png")
	rays.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.set_anchors_preset(Control.PRESET_CENTER)
	rays.offset_left = -520
	rays.offset_right = 520
	rays.offset_top = -520
	rays.offset_bottom = 520
	rays.pivot_offset = Vector2(520, 520)
	rays.modulate = Color(col.lightened(0.35), 0.8)
	hero.add_child(rays)
	rays.create_tween().set_loops().tween_property(rays, "rotation", TAU, 24.0)
	var b := Badge.new(d, 520)
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.offset_left = -260
	b.offset_right = 260
	b.offset_top = -260
	b.offset_bottom = 260
	b.pivot_offset = Vector2(260, 260)
	hero.add_child(b)
	b.scale = Vector2.ZERO
	b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.9).set_delay(0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var nm := UI.label(Game.division_name(d).to_upper() + " DIVISION", 56, col.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(nm)
	v.add_child(UI.label("Harder puzzles, bigger rewards. Keep climbing!", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(8))
	var ok := UI.btn("AWESOME!", UI.ACCENT, 96, 38)
	ok.pressed.connect(overlay.queue_free)
	v.add_child(ok)
	add_child(overlay)
	Sfx.play("win")
	UI.buzz(200)
	UI.confetti(overlay, 120)
