class_name LadderBoard
extends VBoxContainer
## The playing field: target word, the ladder so far, and the word you are editing.
## Tap a letter tile, then press a letter on the keyboard to change it.

signal move_made(word: String)
signal rejected(reason: String)

var start_word := ""
var target_word := ""
var words: Array = []          # accepted moves (does not include the start word)
var selected := -1
var enabled := false
var hint_pos := -1

var _target_row: HBoxContainer
var _scroll: ScrollContainer
var _hist: VBoxContainer
var _cur_row: HBoxContainer
var _msg: Label


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	add_child(UI.label("TARGET", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_target_row = UI.hbox(8)
	_target_row.custom_minimum_size = Vector2(0, 76)
	add_child(_target_row)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_hist = UI.vbox(6)
	_hist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_hist)
	_msg = UI.label("", 24, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_msg.custom_minimum_size = Vector2(0, 34)
	add_child(_msg)
	_cur_row = UI.hbox(8)
	_cur_row.custom_minimum_size = Vector2(0, 112)
	add_child(_cur_row)


func setup(start: String, target: String, moves: Array = []) -> void:
	start_word = start.to_lower()
	target_word = target.to_lower()
	words = []
	for m in moves:
		words.append(str(m).to_lower())
	selected = -1
	hint_pos = -1
	_msg.text = ""
	_rebuild()


func current() -> String:
	return str(words.back()) if words.size() > 0 else start_word


func is_solved() -> bool:
	return current() == target_word


func set_message(text: String, color := UI.ACCENT) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", color)


## Called by the keyboard.
func input_letter(ch: String) -> void:
	if not enabled:
		return
	ch = ch.to_lower()
	if selected < 0:
		set_message("Tap a letter tile first", UI.MUTED)
		UI.flash(_cur_row, Color(1, 0.85, 0.5))
		return
	var cur := current()
	if cur[selected] == ch:
		return
	var cand := cur.substr(0, selected) + ch + cur.substr(selected + 1)
	if cand == start_word or words.has(cand):
		_reject("Already used", cand)
		return
	if not Game.is_word(cand):
		_reject("Not a word", cand)
		return
	words.append(cand)
	selected = -1
	hint_pos = -1
	_msg.text = ""
	_rebuild()
	Sfx.play("good")
	move_made.emit(cand)


func _reject(reason: String, _cand: String) -> void:
	set_message(reason, UI.BAD)
	UI.flash(_cur_row, Color(1, 0.45, 0.45))
	Sfx.play("bad")
	rejected.emit(reason)


func show_hint(pos: int, letter: String) -> void:
	hint_pos = pos
	selected = pos
	set_message("Hint: change letter %d to  %s" % [pos + 1, letter.to_upper()], UI.GOOD)
	_rebuild_current()


func _select(i: int) -> void:
	if not enabled:
		return
	selected = -1 if selected == i else i
	Sfx.play("tap")
	_rebuild_current()


# ------------------------------------------------------------------ drawing

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _tile_style(bg: Color, border := Color.TRANSPARENT, bw := 0) -> StyleBoxFlat:
	var s := UI.box(bg, 16, bw, border)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


func _small_tile(letter: String, bg: Color, fg: Color) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 52)
	p.add_theme_stylebox_override("panel", _tile_style(bg))
	var l := UI.label(letter.to_upper(), 32, fg, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p


func _rebuild() -> void:
	_clear(_target_row)
	for i in target_word.length():
		var t := _small_tile(target_word[i], Color("1f4d3a"), UI.GOOD)
		t.custom_minimum_size = Vector2(0, 76)
		_target_row.add_child(t)
	_clear(_hist)
	var rows: Array = [start_word]
	for i in range(words.size() - 1):
		rows.append(words[i])
	for r in rows.size():
		var prev: String = rows[r - 1] if r > 0 else ""
		var h := UI.hbox(6)
		var n := UI.label(str(r) if r > 0 else "S", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		n.custom_minimum_size = Vector2(44, 0)
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(n)
		var word: String = rows[r]
		for i in word.length():
			var changed: bool = prev != "" and prev[i] != word[i]
			h.add_child(_small_tile(word[i], Color("3a4f6b") if changed else Color("1b2c44"), UI.ACCENT if changed else UI.MUTED))
		_hist.add_child(h)
	_rebuild_current()
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _rebuild_current() -> void:
	_clear(_cur_row)
	var cur := current()
	var solved := cur == target_word
	for i in cur.length():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 112)
		b.text = cur[i].to_upper()
		b.add_theme_font_size_override("font_size", 60)
		var match_target: bool = cur[i] == target_word[i]
		var fg: Color = UI.GOOD if match_target else UI.TEXT
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			b.add_theme_color_override(k, fg)
		var border := Color.TRANSPARENT
		var bw := 0
		if i == selected:
			border = UI.ACCENT
			bw = 5
		elif i == hint_pos:
			border = UI.GOOD
			bw = 4
		var bg := Color("2f5d46") if solved else UI.TILE
		b.add_theme_stylebox_override("normal", _tile_style(bg, border, bw))
		b.add_theme_stylebox_override("hover", _tile_style(bg.lightened(0.06), border, bw))
		b.add_theme_stylebox_override("pressed", _tile_style(bg.darkened(0.1), border, bw))
		b.add_theme_stylebox_override("disabled", _tile_style(bg, border, bw))
		b.pressed.connect(_select.bind(i))
		_cur_row.add_child(b)
