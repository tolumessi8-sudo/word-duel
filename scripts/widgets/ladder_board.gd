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
var _empty: Label


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var tl := UI.label("TARGET", 22, UI.GOOD, HORIZONTAL_ALIGNMENT_CENTER, true)
	add_child(tl)
	_target_row = UI.hbox(10)
	_target_row.custom_minimum_size = Vector2(0, 92)
	add_child(_target_row)
	var card := PanelContainer.new()
	var cs := UI.box(Color("0b1422", 0.55), 24, 2, Color("22364f"))
	cs.content_margin_top = 10
	cs.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", cs)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(card)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_empty = UI.label("Your ladder builds here.\nChange one letter at a time!", 26, Color(UI.MUTED, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(_empty)
	card.add_child(_scroll)
	_hist = UI.vbox(8)
	_hist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hist.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hist.alignment = BoxContainer.ALIGNMENT_END
	_scroll.add_child(_hist)
	_msg = UI.label("", 24, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_msg.custom_minimum_size = Vector2(0, 34)
	add_child(_msg)
	_cur_row = UI.hbox(12)
	_cur_row.custom_minimum_size = Vector2(0, 118)
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
	var s := UI.box(bg, 14, 0)
	s.border_width_bottom = 5
	s.border_color = bg.darkened(0.4)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_width_bottom = bw + 4
		s.border_color = border
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
	var l := UI.label(letter.to_upper(), 34, fg, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p


func _rebuild() -> void:
	_clear(_target_row)
	for i in target_word.length():
		var t := _small_tile(target_word[i], Color("2e8b57"), Color.WHITE)
		t.custom_minimum_size = Vector2(0, 92)
		_target_row.add_child(t)
	_clear(_hist)
	var rows: Array = [start_word]
	for i in range(words.size() - 1):
		rows.append(words[i])
	for r in rows.size():
		var prev: String = rows[r - 1] if r > 0 else ""
		var h := UI.hbox(6)
		var n := UI.label(str(r) if r > 0 else "S", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
		n.custom_minimum_size = Vector2(44, 0)
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(n)
		var word: String = rows[r]
		for i in word.length():
			var changed: bool = prev != "" and prev[i] != word[i]
			h.add_child(_small_tile(word[i], Color("3a4f6b") if changed else Color("1b2c44"), UI.ACCENT if changed else UI.MUTED))
		_hist.add_child(h)
	_empty.visible = words.size() <= 1
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
		var match_target: bool = cur[i] == target_word[i]
		var bg := UI.TILE.lightened(0.12)
		var fg: Color = UI.GOOD.lightened(0.2) if match_target else Color.WHITE
		if solved:
			bg = Color("2e8b57")
			fg = Color.WHITE
		elif i == selected:
			bg = UI.ACCENT
			fg = Color("5a3200")
		elif i == hint_pos:
			bg = UI.GOOD
			fg = Color("0b3d1f")
		var b := UI.btn(cur[i].to_upper(), bg, 118, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			b.add_theme_color_override(k, fg)
		b.add_theme_constant_override("outline_size", 0)
		b.pressed.connect(_select.bind(i))
		_cur_row.add_child(b)
