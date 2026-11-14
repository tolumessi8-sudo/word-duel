class_name Badge
extends TextureRect
## Division badge sprite (res://art/badges/div_N.png).

var division := 1:
	set(v):
		division = clampi(v, 1, 7)
		texture = UI.tex("res://art/badges/div_%d.png" % division)
var dimmed := false:
	set(v):
		dimmed = v
		modulate = Color(0.45, 0.45, 0.5, 0.8) if dimmed else Color.WHITE


func _init(d := 1, px := 120) -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px, px)
	division = d
