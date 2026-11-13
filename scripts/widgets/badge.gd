class_name Badge
extends Control
## Division badge. If res://art/badges/div_N.png exists it is used (drop your own sprites there),
## otherwise a simple shield is drawn.

var division := 1:
	set(v):
		division = clampi(v, 1, 7)
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()


func _init(d := 1, px := 120) -> void:
	division = d
	custom_minimum_size = Vector2(px, px)


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	var col: Color = Game.division_color(division)
	if dimmed:
		col = col.darkened(0.55)
	var path := "res://art/badges/div_%d.png" % division
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(s, s)), false, Color(1, 1, 1, 0.45 if dimmed else 1.0))
		return
	var c := Vector2(size.x / 2.0, size.y / 2.0)
	var r := s / 2.0
	var shield := PackedVector2Array([
		c + Vector2(-0.80, -0.86) * r, c + Vector2(0.80, -0.86) * r,
		c + Vector2(0.86, 0.10) * r, c + Vector2(0.0, 0.98) * r, c + Vector2(-0.86, 0.10) * r,
	])
	var inner := PackedVector2Array([
		c + Vector2(-0.62, -0.68) * r, c + Vector2(0.62, -0.68) * r,
		c + Vector2(0.67, 0.05) * r, c + Vector2(0.0, 0.76) * r, c + Vector2(-0.67, 0.05) * r,
	])
	draw_colored_polygon(shield, col.darkened(0.35))
	draw_colored_polygon(inner, col)
	var font := ThemeDB.fallback_font
	var fs := int(r * 0.95)
	var txt := str(division)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, Vector2(c.x - tw.x / 2.0, c.y + fs * 0.30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.DARK_TEXT)
