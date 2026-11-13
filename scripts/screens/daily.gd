extends Screen
## Daily puzzle: same puzzle for everyone today. Fewest moves (then fastest) tops the board.

var puzzle: Dictionary = {}
var _board: LadderBoard
var _kb: Keyboard
var _timer_l: Label
var _info: Label
var _hint_btn: Button
var _begin_ms := 0
var _solved := false
var _busy := false


func start(_args: Dictionary) -> void:
	var root := make_root(20)
	root.add_theme_constant_override("separation", 12)
	root.add_child(make_header("Daily Puzzle"))
	var row := UI.hbox(12)
	_info = UI.label("Loading today's puzzle...", 26, UI.MUTED)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_info)
	_timer_l = UI.label("0:00", 40, UI.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_timer_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_timer_l)
	root.add_child(row)
	_board = LadderBoard.new()
	_board.move_made.connect(_on_move)
	root.add_child(_board)
	var br := UI.hbox(12)
	_hint_btn = UI.btn("Hint (watch an ad)", UI.PANEL2, 64, 24)
	_hint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_btn.pressed.connect(_on_hint)
	br.add_child(_hint_btn)
	var restart := UI.btn("Restart", UI.PANEL2, 64, 24)
	restart.custom_minimum_size = Vector2(170, 64)
	restart.pressed.connect(_restart)
	br.add_child(restart)
	root.add_child(br)
	_kb = Keyboard.new()
	_kb.key.connect(_board.input_letter)
	root.add_child(_kb)

	var r: Dictionary = await Api.call_rpc("daily_puzzle")
	if not is_inside_tree():
		return
	if not r.has("start"):
		await UI.choose(self, "Can't load puzzle", "Check your internet connection and try again.", ["OK"], [UI.ACCENT])
		if is_inside_tree():
			go("home")
		return
	puzzle = r
	_info.text = "%s    Best possible: %d moves" % [str(r.get("day", "")), int(r.get("shortest", 0))]
	_restart()


func _restart() -> void:
	if puzzle.is_empty():
		return
	_solved = false
	_board.setup(str(puzzle["start"]), str(puzzle["target"]))
	_board.enabled = true
	_kb.highlight("")
	_begin_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if puzzle.is_empty() or _solved:
		return
	_timer_l.text = UI.fmt_time((Time.get_ticks_msec() - _begin_ms) / 1000.0)


func _on_hint() -> void:
	if puzzle.is_empty() or _solved or _busy:
		return
	_busy = true
	var ok: bool = await Ads.show_rewarded()
	_busy = false
	if not is_inside_tree():
		return
	if not ok:
		UI.toast(self, "Watch the whole ad to get a hint")
		return
	var used: Array = _board.words.duplicate()
	used.append(_board.start_word)
	var h: Dictionary = Game.local_hint(_board.current(), _board.target_word, used)
	if h.is_empty():
		UI.toast(self, "No hint available - try Restart")
		return
	_board.show_hint(int(h["pos"]), str(h["letter"]))
	_kb.highlight(str(h["letter"]))


func _on_move(_word: String) -> void:
	_kb.highlight("")
	if not _board.is_solved():
		return
	_solved = true
	_board.enabled = false
	var secs := (Time.get_ticks_msec() - _begin_ms) / 1000.0
	Sfx.play("win")
	var r: Dictionary = await Game.call_api("submit_daily", {"p_path": _board.words, "p_seconds": secs})
	if not is_inside_tree():
		return
	var text := ""
	if r.get("ok", false):
		Game.set_profile(r["profile"])
		text = "Moves: %d  (best possible %d)\nYour best today: %d moves\nToday's rank: #%d" % [
			int(r["moves"]), int(puzzle.get("shortest", 0)), int(r["best_moves"]), int(r["rank"])]
		if int(r.get("coins_added", 0)) > 0:
			text += "\n+%d coins   Streak: %d day(s)" % [int(r["coins_added"]), int(r.get("streak", 1))]
			Sfx.play("coin")
	else:
		text = "Solved in %d moves!\nCould not reach the server to save your score." % _board.words.size()
	var c: int = await UI.choose(self, "Puzzle solved!", text,
		["Daily leaderboard", "Try for fewer moves", "Home"], [UI.ACCENT, UI.BLUE, UI.PANEL2])
	if not is_inside_tree():
		return
	if c == 0:
		go("leaderboard", {"tab": "daily"})
	elif c == 1:
		_restart()
	else:
		go("home")
