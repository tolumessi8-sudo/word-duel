extends Screen
## Guided first game: a coach walks the player through COT > DIG, one tap at a time.

const START := "cot"
const TARGET := "dig"

var _board: LadderBoard
var _kb: Keyboard
var _coach: Label
var _hint_tile := -1
var _done := false
var _t := 0.0


func start(_args: Dictionary) -> void:
	var root := make_root(20)
	root.add_theme_constant_override("separation", 12)
	var top := UI.hbox(12)
	var title := UI.label("HOW TO PLAY", 36, UI.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(title)
	var skip := UI.btn("SKIP", UI.PANEL2, 60, 24)
	skip.custom_minimum_size = Vector2(130, 60)
	skip.pressed.connect(_finish.bind(false))
	top.add_child(skip)
	root.add_child(top)

	# coach: avatar + speech bubble
	var cp := UI.panel(Color("23375a"), 26)
	var ch := UI.hbox(14)
	cp.add_child(ch)
	ch.add_child(UI.avatar("coach", 96, 0, 1))
	_coach = UI.label("", 28, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	_coach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coach.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(_coach)
	cp.custom_minimum_size = Vector2(0, 150)
	root.add_child(cp)

	_board = LadderBoard.new()
	_board.move_made.connect(_on_move)
	root.add_child(_board)
	_kb = Keyboard.new()
	_kb.key.connect(_on_key)
	root.add_child(_kb)
	_board.setup(START, TARGET)
	_board.enabled = false
	await get_tree().process_frame
	await UI.choose(self, "Welcome to Word Duel!",
		"Turn COT into DIG.\n\nChange ONE letter at a time, and every step must be a real word.\n\nIn a real match you race an opponent - first to the target wins!",
		["Show me"], [UI.GOOD])
	if not is_inside_tree():
		return
	_board.enabled = true
	_next_step()


func on_back() -> void:
	_finish(false)


func _process(delta: float) -> void:
	_t += delta
	if _board == null or _board._cur_row == null:
		return
	var kids := _board._cur_row.get_children()
	for i in kids.size():
		var k := kids[i] as Control
		if i == _hint_tile and not _done:
			var s := 0.5 + 0.5 * sin(_t * 7.0)
			k.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.5, 1.0), s)
		else:
			k.modulate = Color.WHITE


func _next_step() -> void:
	if _done:
		return
	var used: Array = _board.words.duplicate()
	used.append(_board.start_word)
	var h: Dictionary = Game.local_hint(_board.current(), TARGET, used)
	if h.is_empty():
		_coach.text = "Hmm, that path is stuck. Tap RESTART in the next step!"
		_board.setup(START, TARGET)
		_board.enabled = true
		return
	var pos := int(h["pos"])
	var letter := str(h["letter"]).to_upper()
	if _board.selected != pos:
		_hint_tile = pos
		_coach.text = "Step %d: tap the glowing tile - letter %s." % [_board.words.size() + 1, _board.current()[pos].to_upper()]
		_kb.highlight("")
	else:
		_hint_tile = -1
		_coach.text = "Now tap %s on the keyboard to change it." % letter
		_kb.highlight(letter.to_lower())


func _on_key(letter: String) -> void:
	_board.input_letter(letter)


func _on_move(_word: String) -> void:
	_kb.highlight("")
	_hint_tile = -1
	Sfx.play("good")
	if _board.is_solved():
		_win()
		return
	_coach.text = "Nice! %s is a real word. Keep going toward %s!" % [_board.current().to_upper(), TARGET.to_upper()]
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		_next_step()


func _input(event: InputEvent) -> void:
	# after the player taps a tile, move the coach on to the keyboard step
	if _done or _board == null:
		return
	if event is InputEventMouseButton and not event.pressed:
		await get_tree().process_frame
		if is_inside_tree() and not _done and _hint_tile >= 0 and _board.selected == _hint_tile:
			_next_step()


func _win() -> void:
	_done = true
	_board.enabled = false
	Sfx.play("win")
	UI.buzz(100)
	UI.confetti(self, 100)
	_coach.text = "You did it! " + " > ".join(([START] + _board.words).map(func(w): return str(w).to_upper()))
	await get_tree().create_timer(1.4).timeout
	if not is_inside_tree():
		return
	await UI.choose(self, "You're ready!",
		"Quick tips:\n- Fewer moves and a faster finish beat your rival.\n- Stuck? A hint costs coins or a short ad.\n- Win matches to climb 7 divisions and earn coins.",
		["Let's play!"], [UI.GOOD])
	if is_inside_tree():
		_finish(true)


func _finish(_completed: bool) -> void:
	Game.tutorial_done = true
	Game.save_settings()
	go("home")
