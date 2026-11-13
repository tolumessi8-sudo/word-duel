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

var _title: Label
var _timer_l: Label
var _opp_name: Label
var _opp_info: Label
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
	var back := UI.btn("Leave", UI.PANEL2, 64, 24)
	back.custom_minimum_size = Vector2(130, 64)
	back.pressed.connect(on_back)
	h.add_child(back)
	_title = UI.label("", 30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_title)
	_timer_l = UI.label("--:--", 48, UI.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_timer_l.custom_minimum_size = Vector2(150, 0)
	_timer_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(_timer_l)
	root.add_child(h)

	var pn := UI.panel(UI.PANEL, 22)
	var pv := UI.vbox(6)
	pn.add_child(pv)
	var r1 := UI.hbox(8)
	_opp_name = UI.label("Opponent", 28, UI.TEXT)
	_opp_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opp_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	r1.add_child(_opp_name)
	_opp_info = UI.label("", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_opp_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	r1.add_child(_opp_info)
	pv.add_child(r1)
	_opp_bar = UI.bar(4, UI.BAD, 16)
	pv.add_child(_opp_bar)
	var r2 := UI.hbox(8)
	var me := UI.label("You", 28, UI.TEXT)
	me.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(me)
	_me_info = UI.label("0 moves", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_me_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	r2.add_child(_me_info)
	pv.add_child(r2)
	_me_bar = UI.bar(4, UI.GOOD, 16)
	pv.add_child(_me_bar)
	root.add_child(pn)

	_board = LadderBoard.new()
	_board.move_made.connect(_on_move)
	root.add_child(_board)

	_status = UI.label("", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_status.custom_minimum_size = Vector2(0, 30)
	root.add_child(_status)

	_hint_btn = UI.btn("Hint  (15 coins or watch an ad)", UI.PANEL2, 64, 24)
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
	_overlay_label = UI.label("", 64, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	ov.add_child(_overlay_label)
	_overlay_sub = UI.label("", 30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	ov.add_child(_overlay_sub)
	_cancel_btn = UI.btn("Cancel", UI.PANEL2, 80, 28)
	_cancel_btn.pressed.connect(on_back)
	ov.add_child(_cancel_btn)
	add_child(_overlay)


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
	_opp_name.text = "%s  (%d)" % [str(s.get("opp_name", "Opponent")), int(_f(s.get("opp_trophies")))]
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
	Game.refresh_profile()
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


func _show_result(s: Dictionary, res: String) -> void:
	var m := str(s.get("mode", mode))
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(c)
	var p := UI.panel(UI.PANEL, 30)
	p.custom_minimum_size = Vector2(610, 0)
	c.add_child(p)
	var v := UI.vbox(18)
	p.add_child(v)
	var title := "VICTORY!" if res == "win" else ("DEFEAT" if res == "lose" else "DRAW")
	var color := UI.GOOD if res == "win" else (UI.BAD if res == "lose" else UI.ACCENT)
	v.add_child(UI.label(title, 76, color, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(_reason_text(res, str(s.get("reason", ""))), 28, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("%s  >  %s" % [str(s.get("start", "")).to_upper(), str(s.get("target", "")).to_upper()],
		30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var td := int(_f(s.get("trophy_delta")))
	var coins := int(_f(s.get("coin_delta")))
	if m != "friendly":
		var tcol := UI.GOOD if td > 0 else (UI.BAD if td < 0 else UI.MUTED)
		v.add_child(UI.label("%s%d trophies" % ["+" if td > 0 else "", td], 40, tcol, HORIZONTAL_ALIGNMENT_CENTER))
	var coin_l := UI.label("+%d coins" % coins, 36, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(coin_l)
	if coins > 0 and not bool(s.get("doubled", false)):
		var dbl := UI.btn("DOUBLE COINS  (watch an ad)", UI.BLUE, 84, 28)
		dbl.pressed.connect(func() -> void:
			dbl.disabled = true
			var ok: bool = await Ads.show_rewarded()
			if not is_inside_tree():
				return
			if ok:
				var r: Dictionary = await Game.call_api("double_reward", {"mid": match_id})
				if is_inside_tree() and r.get("ok", false):
					Game.set_profile(r["profile"])
					coin_l.text = "+%d coins (doubled!)" % (coins * 2)
					Sfx.play("coin")
					dbl.hide()
					return
			dbl.disabled = false)
		v.add_child(dbl)
	var again := UI.btn("PLAY AGAIN", UI.ACCENT, 92, 34)
	again.pressed.connect(func() -> void:
		again.disabled = true
		await Ads.after_match()
		if is_inside_tree():
			go("friend" if m == "friendly" else "match", {} if m == "friendly" else {"mode": m}))
	v.add_child(again)
	var home := UI.btn("HOME", UI.PANEL2, 80, 30)
	home.pressed.connect(func() -> void:
		home.disabled = true
		await Ads.after_match()
		if is_inside_tree():
			go("home"))
	v.add_child(home)
	add_child(overlay)
