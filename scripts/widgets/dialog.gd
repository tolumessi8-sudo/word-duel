class_name Dialog
extends Control
## Modal popup used through UI.choose() / UI.confirm().

signal chosen(index: int)


func setup(title: String, text: String, options: Array, colors: Array) -> void:
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
	var v := UI.vbox(20)
	p.add_child(v)
	v.add_child(UI.label(title, 40, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	if text != "":
		v.add_child(UI.label(text, 28, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	for i in options.size():
		var c: Color = colors[i] if i < colors.size() else UI.PANEL2
		var b := UI.btn(str(options[i]), c, 80, 30)
		b.pressed.connect(func() -> void: chosen.emit(i))
		v.add_child(b)
