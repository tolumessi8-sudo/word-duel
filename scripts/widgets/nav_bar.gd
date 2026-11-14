class_name NavBar
extends Control
## Bottom tab bar shown on the main screens.

signal selected(tab: String)

const TABS := [
	["home", "Home", "home"],
	["divisions", "Divisions", "crown"],
	["leaderboard", "Ranks", "ranks"],
	["events", "Events", "gift"],
	["settings", "Settings", "gear"],
]

var _items := {}
var _active := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func build(safe_bottom: float) -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_right = 0
	offset_top = -(UI.NAV_H + safe_bottom)
	offset_bottom = 0
	var bg := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("0c1627")
	s.corner_radius_top_left = 30
	s.corner_radius_top_right = 30
	s.border_width_top = 2
	s.border_color = Color("2c4466")
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, -4)
	bg.add_theme_stylebox_override("panel", s)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(bg)
	add_child(bg)
	var row := HBoxContainer.new()
	_fill(row)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 10
	row.offset_bottom = -(safe_bottom + 6)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	for t in TABS:
		var key: String = t[0]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var pill := Panel.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(UI.ACCENT, 0.16)
		ps.set_corner_radius_all(24)
		ps.border_width_bottom = 4
		ps.border_color = UI.ACCENT
		pill.add_theme_stylebox_override("panel", ps)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill(pill)
		pill.offset_left = 4
		pill.offset_right = -4
		pill.visible = false
		b.add_child(pill)
		var v := VBoxContainer.new()
		_fill(v)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := UI.icon(t[2], 54)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.pivot_offset = Vector2(27, 27)
		ic.modulate = Color(1, 1, 1, 0.6)
		v.add_child(ic)
		var l := UI.label(t[1], 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(l)
		b.pressed.connect(func() -> void:
			UI.tap()
			selected.emit(key))
		row.add_child(b)
		_items[key] = {"pill": pill, "icon": ic, "label": l}


func set_active(tab: String) -> void:
	_active = tab
	for k in _items:
		var it: Dictionary = _items[k]
		var on: bool = k == tab
		(it["pill"] as Panel).visible = on
		var ic: TextureRect = it["icon"]
		ic.modulate = Color.WHITE if on else Color(1, 1, 1, 0.6)
		(it["label"] as Label).add_theme_color_override("font_color", UI.ACCENT if on else UI.MUTED)
		if on and ic.is_inside_tree():
			var tw := ic.create_tween()
			ic.scale = Vector2(0.8, 0.8)
			tw.tween_property(ic, "scale", Vector2(1.12, 1.12), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			ic.scale = Vector2.ONE


static func _fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
