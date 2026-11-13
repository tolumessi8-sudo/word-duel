class_name Screen
extends Control
## Base class for every screen. `main` is set by main.gd before start() is called.

var main: Node


func start(_args: Dictionary) -> void:
	pass


## Android back button / escape. Override to customise.
func on_back() -> void:
	go("home")


func go(screen: String, args: Dictionary = {}) -> void:
	main.go(screen, args)


## Standard padded content column that respects the phone's notch / gesture bar.
func make_root(pad := 28) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := safe_insets()
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_top", pad + int(safe.x))
	m.add_theme_constant_override("margin_bottom", pad + int(safe.y))
	add_child(m)
	var v := UI.vbox(16)
	m.add_child(v)
	return v


## (top, bottom) safe-area insets converted to viewport units.
func safe_insets() -> Vector2:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var vp := get_viewport_rect().size
	var k := vp.x / float(win.x)
	var top := maxf(0.0, float(safe.position.y)) * k
	var bottom := maxf(0.0, float(win.y - (safe.position.y + safe.size.y))) * k
	return Vector2(minf(top, 120.0), minf(bottom, 120.0))


## A header row with a back button and a title.
func make_header(title: String, back_text := "Back") -> HBoxContainer:
	var h := UI.hbox(16)
	var b := UI.btn(back_text, UI.PANEL2, 72, 26)
	b.custom_minimum_size = Vector2(150, 72)
	b.pressed.connect(on_back)
	h.add_child(b)
	var t := UI.label(title, 40, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(150, 0)
	h.add_child(pad)
	return h


func show_howto() -> void:
	await UI.choose(self, "How to play",
		"Turn the START word into the TARGET word.\n\nChange ONE letter at a time. Every step must be a real word.\n\nExample:\nCOLD > CORD > CARD > WARD > WARM\n\nFirst player to reach the target wins. If both finish within 1 second it is a draw. In weekend matches a draw is decided by the fewest moves.",
		["Got it"], [UI.ACCENT])


func banner_strip() -> Control:
	var p := UI.panel(Color("0b1422"), 12)
	p.custom_minimum_size = Vector2(0, Ads.banner_height())
	p.add_child(UI.label("Ad space (test banner)", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	p.visible = Ads.banner_enabled
	return p
