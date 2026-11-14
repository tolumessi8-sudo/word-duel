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
const NAV_H := 124
const WGHT := 2003265652  # OpenType 'wght' axis tag

static var _head: Font
static var _body: Font
static var _tex := {}


static func head_font() -> Font:
	if _head == null:
		_head = load("res://art/fonts/LilitaOne-Regular.ttf")
	return _head


static func body_font() -> Font:
	if _body == null:
		var fv := FontVariation.new()
		fv.base_font = load("res://art/fonts/Nunito-Variable.ttf")
		fv.variation_opentype = {WGHT: 800}
		_body = fv
	return _body


static func tap() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var sfx := tree.root.get_node_or_null("Sfx")
		if sfx != null:
			sfx.call("play", "tap")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Icon from res://art/icons/<name>.png as a fixed-size, centered TextureRect.
static func icon(name: String, px := 48) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex("res://art/icons/%s.png" % name)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


static func avatar_index(seed_text: String) -> int:
	return int(seed_text.hash() % 12)


static func avatar(seed_text: String, px := 88) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex("res://art/avatars/av_%d.png" % avatar_index(seed_text))
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## Rounded pill with an icon and a number/text. Update with chip_set(chip, text).
static func chip(icon_name: String, text: String, color := TEXT) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(Color("0b1422"), 40, 2, Color("2c4466"))
	s.content_margin_left = 10
	s.content_margin_right = 20
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	var h := hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	if icon_name != "":
		h.add_child(icon(icon_name, 40))
	var l := label(text, 30, color, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	p.set_meta("lbl", l)
	return p


static func chip_set(c: Control, text: String) -> void:
	(c.get_meta("lbl") as Label).text = text


## Insets (top, bottom) of the phone's cutouts / gesture bar in viewport units.
static func safe_insets(vp_size: Vector2) -> Vector2:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var k := vp_size.x / float(win.x)
	var top := maxf(0.0, float(safe.position.y)) * k
	var bottom := maxf(0.0, float(win.y - (safe.position.y + safe.size.y))) * k
	return Vector2(minf(top, 120.0), minf(bottom, 120.0))


## Chunky "3D" style: coloured face with a darker lip underneath.
static func chunk(color: Color, radius := 24, depth := 8, pressed := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_width_bottom = 2 if pressed else depth
	s.border_color = color.darkened(0.38)
	s.shadow_color = Color(0, 0, 0, 0.0 if pressed else 0.32)
	s.shadow_size = 0 if pressed else 8
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 4 + (depth - 2 if pressed else 0)
	s.content_margin_bottom = 4 + (2 if pressed else depth)
	return s


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
	t.default_font = body_font()
	t.default_font_size = 28
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 12))
	t.set_stylebox("background", "ProgressBar", box(Color("0b1422"), 10))
	t.set_stylebox("normal", "LineEdit", box(Color("0b1422"), 16, 2, Color("2c4466")))
	t.set_stylebox("focus", "LineEdit", box(Color("0b1422"), 16, 3, ACCENT))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_font_size("font_size", "LineEdit", 34)
	t.set_font("font", "LineEdit", head_font())
	t.set_color("font_color", "CheckButton", TEXT)
	return t


static func btn(text: String, color := ACCENT, h := 84, fs := 32, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = false
	b.add_theme_font_override("font", head_font())
	b.add_theme_font_size_override("font_size", fs)
	var light := color.get_luminance() > 0.45
	var fc := color.darkened(0.72) if light else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.55))
	if not light:
		b.add_theme_color_override("font_outline_color", color.darkened(0.5))
		b.add_theme_constant_override("outline_size", maxi(4, fs / 6))
	var r := clampi(h / 3, 14, 30)
	var d := clampi(h / 10, 5, 10)
	b.add_theme_stylebox_override("normal", chunk(color, r, d))
	b.add_theme_stylebox_override("hover", chunk(color.lightened(0.06), r, d))
	b.add_theme_stylebox_override("pressed", chunk(color.darkened(0.08), r, d, true))
	b.add_theme_stylebox_override("disabled", chunk(color.darkened(0.55), r, d))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icon_name != "":
		b.icon = tex("res://art/icons/%s.png" % icon_name)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(h * 0.56))
		b.add_theme_constant_override("h_separation", 14)
		b.add_theme_color_override("icon_normal_color", Color.WHITE)
		b.add_theme_color_override("icon_pressed_color", Color.WHITE)
		b.add_theme_color_override("icon_hover_color", Color.WHITE)
		b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.45))
	# glossy highlight on the upper half of the face
	var g := Panel.new()
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(1, 1, 1, 0.17)
	gs.corner_radius_top_left = r - 4
	gs.corner_radius_top_right = r - 4
	gs.corner_radius_bottom_left = r
	gs.corner_radius_bottom_right = r
	g.add_theme_stylebox_override("panel", gs)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_preset(Control.PRESET_TOP_WIDE)
	g.anchor_bottom = 0.0
	g.offset_left = 10
	g.offset_right = -10
	g.offset_top = 5
	g.offset_bottom = maxf(14.0, h * 0.40)
	b.add_child(g)
	b.button_down.connect(func() -> void:
		tap()
		b.pivot_offset = b.size / 2.0
		g.visible = false
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.97, 0.97), 0.06))
	b.button_up.connect(func() -> void:
		g.visible = not b.disabled
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


static func label(text: String, size := 28, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, head := false) -> Label:
	var l := Label.new()
	l.text = text
	if head or size >= 34:
		l.add_theme_font_override("font", head_font())
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.32))
		l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 16))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func card_box(color: Color, radius := 24) -> StyleBoxFlat:
	var s := box(color, radius, 2, color.lightened(0.16))
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	return s


static func panel(color := PANEL, radius := 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(color, radius))
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
	var f := box(color, h / 2, 0)
	f.border_width_top = 0
	b.add_theme_stylebox_override("fill", f)
	b.add_theme_stylebox_override("background", box(Color("0b1422"), h / 2, 2, Color("2c4466")))
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
	p.z_index = 100
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


## One-shot confetti: a rain from the top plus two side cannons. Frees itself.
static func confetti(host: Control, rain := 80) -> void:
	var size := host.get_viewport_rect().size
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.colors = PackedColorArray([Color("ffc933"), Color("ff4d8d"), Color("5aa9ff"), Color("2ecc71"), Color("ff6a2c"), Color("b07cff")])
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.34, 0.51, 0.68, 0.85])
	var tx := tex("res://art/fx/confetti.png")
	var specs := [
		[Vector2(size.x * 0.5, -30), Vector2(0, 1), 80.0, 250.0, 550.0, 700.0, rain, 0.3],
		[Vector2(-10, size.y * 0.62), Vector2(1, -1.1), 24.0, 800.0, 1300.0, 1500.0, 70, 0.95],
		[Vector2(size.x + 10, size.y * 0.62), Vector2(-1, -1.1), 24.0, 800.0, 1300.0, 1500.0, 70, 0.95],
	]
	for sp in specs:
		var p := CPUParticles2D.new()
		p.position = sp[0]
		p.direction = sp[1]
		p.spread = sp[2]
		p.initial_velocity_min = sp[3]
		p.initial_velocity_max = sp[4]
		p.gravity = Vector2(0, sp[5])
		p.amount = sp[6]
		p.explosiveness = sp[7]
		p.lifetime = 3.2
		p.one_shot = true
		p.texture = tx
		p.color_initial_ramp = g
		p.angular_velocity_min = -400.0
		p.angular_velocity_max = 400.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.1
		p.z_index = 200
		host.add_child(p)
		p.emitting = true
		host.get_tree().create_timer(4.5).timeout.connect(p.queue_free)


static func buzz(ms := 30) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
