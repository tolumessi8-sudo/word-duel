class_name Dialog
extends Control
## Modal popup used through UI.choose() / UI.confirm().

signal chosen(index: int)


func setup(title: String, text: String, options: Array, colors: Array) -> void:
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UI.panel(UI.PANEL, 28)
	p.custom_minimum_size = Vector2(600, 0)
	center.add_child(p)
	p.pivot_offset = Vector2(300, 200)
	p.scale = Vector2(0.85, 0.85)
	p.modulate.a = 0.0
	dim.modulate.a = 0.0
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_property(dim, "modulate:a", 1.0, 0.2)
	var v := UI.vbox(20)
	p.add_child(v)
	v.add_child(UI.label(title, 44, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	if text != "":
		v.add_child(UI.label(text, 28, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	for i in options.size():
		var c: Color = colors[i] if i < colors.size() else UI.PANEL2
		var b := UI.btn(str(options[i]).to_upper(), c, 80, 30)
		b.pressed.connect(func() -> void: chosen.emit(i))
		v.add_child(b)
