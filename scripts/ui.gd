class_name UI
extends RefCounted
## Shared look & feel plus small widget factories.

const BG := Color("0f1b2d")
const PANEL := Color("18283f")
const PANEL2 := Color("22364f")
const ACCENT := Color("ffb703")
const GOOD := Color("2ecc71")
const BAD := Color("e74c3c")
const BLUE := Color("3b82f6")
const PURPLE := Color("8b5cf6")
const TEXT := Color("f1f5f9")
const MUTED := Color("8fa3bd")
const TILE := Color("243750")
const DARK_TEXT := Color("0f1b2d")


static func box(color: Color, radius := 20, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 28
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 10))
	t.set_stylebox("background", "ProgressBar", box(Color("0b1422"), 10))
	t.set_stylebox("normal", "LineEdit", box(Color("0b1422"), 16, 2, Color("2c4466")))
	t.set_stylebox("focus", "LineEdit", box(Color("0b1422"), 16, 3, ACCENT))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_font_size("font_size", "LineEdit", 34)
	t.set_color("font_color", "CheckButton", TEXT)
	return t


static func btn(text: String, color := ACCENT, h := 84, fs := 32) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	var fc := DARK_TEXT if color.get_luminance() > 0.5 else TEXT
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.5))
	b.add_theme_stylebox_override("normal", box(color, 22))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.08), 22))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.18), 22))
	b.add_theme_stylebox_override("disabled", box(color.darkened(0.5), 22))
	return b


static func label(text: String, size := 28, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func panel(color := PANEL, radius := 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius))
	return p


static func vbox(sep := 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h := 16) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func grow(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func bar(max_value: float, color := ACCENT, h := 22) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_stylebox_override("fill", box(color, 10))
	return b


static func fmt_time(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]


## Quick pulse + colour flash on a control (used for feedback instead of moving it inside containers).
static func flash(n: Control, color: Color) -> void:
	if not n.is_inside_tree():
		return
	n.pivot_offset = n.size / 2.0
	var tw := n.create_tween()
	tw.tween_property(n, "modulate", color, 0.08)
	tw.parallel().tween_property(n, "scale", Vector2(1.08, 1.08), 0.08)
	tw.tween_property(n, "modulate", Color.WHITE, 0.25)
	tw.parallel().tween_property(n, "scale", Vector2.ONE, 0.25)


static func toast(host: Control, text: String, color := PANEL2) -> void:
	var p := panel(color, 18)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, 26, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	host.add_child(p)
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.anchor_left = 0.08
	p.anchor_right = 0.92
	p.anchor_top = 0.80
	p.anchor_bottom = 0.80
	p.offset_left = 0
	p.offset_right = 0
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var tw := p.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


## Modal dialog with any number of buttons. Returns the chosen index, or -1 if dismissed.
static func choose(host: Node, title: String, text: String, options: Array, colors: Array = []) -> int:
	var d := Dialog.new()
	host.add_child(d)
	d.setup(title, text, options, colors)
	var idx: int = await d.chosen
	d.queue_free()
	return idx


static func confirm(host: Node, title: String, text: String, yes := "Yes", no := "Cancel") -> bool:
	var i: int = await choose(host, title, text, [yes, no], [ACCENT, PANEL2])
	return i == 0
