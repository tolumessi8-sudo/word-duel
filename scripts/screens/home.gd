extends Screen
## Main menu.

var _name_l: Label
var _coins: PanelContainer
var _badge: Badge
var _div_l: Label
var _tro: PanelContainer
var _rank: PanelContainer
var _bar: ProgressBar
var _next_l: Label
var _event_box: VBoxContainer
var _weekend_btn: Button
var _ad_btn: Button
var _rays: TextureRect
var _hero: PanelContainer
var _avatar_slot: Control
var _streak: PanelContainer


func start(args: Dictionary) -> void:
	tab = "home"
	var root := make_root(24)
	root.add_theme_constant_override("separation", 14)

	# ---- top bar: avatar, name, coins, help
	var top := UI.hbox(14)
	_avatar_slot = Control.new()
	_avatar_slot.custom_minimum_size = Vector2(84, 84)
	top.add_child(_avatar_slot)
	var who := UI.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_l = UI.label("", 36, UI.TEXT)
	_name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_l.clip_text = true
	who.add_child(_name_l)
	var sub := UI.label("Word Duel", 22, UI.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	who.add_child(sub)
	top.add_child(who)
	_coins = UI.chip("coin", "0", UI.ACCENT)
	_coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_coins)
	var help := UI.btn("?", UI.BLUE, 64, 34)
	help.custom_minimum_size = Vector2(64, 64)
	help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	help.pressed.connect(show_howto)
	top.add_child(help)
	root.add_child(top)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	var body := UI.vbox(18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# ---- hero: division badge on a rotating sunburst
	_hero = UI.panel(UI.PANEL, 32)
	var hv := UI.vbox(6)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero.add_child(hv)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 250)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.clip_contents = false
	hv.add_child(holder)
	_rays = TextureRect.new()
	_rays.texture = UI.tex("res://art/fx/sunburst.png")
	_rays.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rays.stretch_mode = TextureRect.STRETCH_SCALE
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_preset(Control.PRESET_CENTER)
	_rays.offset_left = -300
	_rays.offset_right = 300
	_rays.offset_top = -300
	_rays.offset_bottom = 300
	_rays.pivot_offset = Vector2(300, 300)
	holder.add_child(_rays)
	_badge = Badge.new(1, 330)
	_badge.set_anchors_preset(Control.PRESET_CENTER)
	_badge.offset_left = -165
	_badge.offset_right = 165
	_badge.offset_top = -165
	_badge.offset_bottom = 165
	_badge.pivot_offset = Vector2(165, 165)
	holder.add_child(_badge)
	_div_l = UI.label("", 58, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	hv.add_child(_div_l)
	var stats := UI.hbox(12)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_tro = UI.chip("trophy", "0")
	_rank = UI.chip("star", "#1")
	stats.add_child(_tro)
	stats.add_child(_rank)
	_streak = UI.chip("flame", "0", Color("ff9a3c"))
	stats.add_child(_streak)
	hv.add_child(stats)
	hv.add_child(UI.spacer(6))
	_bar = UI.bar(100, UI.ACCENT, 26)
	hv.add_child(_bar)
	_next_l = UI.label("", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hv.add_child(_next_l)
	body.add_child(_hero)

	_event_box = UI.vbox(10)
	body.add_child(_event_box)

	# ---- play
	var play := UI.btn("PLAY RANKED", UI.GOOD, 116, 50, "swords")
	play.pressed.connect(func() -> void: go("match", {"mode": "ranked"}))
	body.add_child(play)
	play.pivot_offset = Vector2(336, 64)
	var pulse := play.create_tween().set_loops()
	pulse.tween_property(play, "modulate", Color(1.1, 1.1, 1.1), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)

	_weekend_btn = UI.btn("", UI.PURPLE, 100, 34, "crown")
	_weekend_btn.pressed.connect(_on_weekend)
	body.add_child(_weekend_btn)

	var row1 := UI.hbox(16)
	var daily := UI.btn("DAILY", UI.BLUE, 108, 32, "calendar")
	daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	daily.pressed.connect(func() -> void: go("daily"))
	row1.add_child(daily)
	var friend := UI.btn("FRIEND", Color("14b8a6"), 108, 32, "friends")
	friend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friend.pressed.connect(func() -> void: go("friend"))
	row1.add_child(friend)
	body.add_child(row1)

	_ad_btn = UI.btn("", Color("c2410c"), 88, 28, "video")
	_ad_btn.pressed.connect(_on_watch_ad)
	body.add_child(_ad_btn)
	body.add_child(UI.spacer(6))

	root.add_child(banner_strip())

	# gentle idle animation
	_rays.create_tween().set_loops().tween_property(_rays, "rotation", TAU, 50.0)
	var breathe := _badge.create_tween().set_loops()
	breathe.tween_property(_badge, "scale", Vector2(1.04, 1.04), 1.4).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_badge, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_SINE)

	Game.profile_changed.connect(_refresh)
	_refresh()

	if args.get("welcome", false):
		show_howto()
	else:
		var sr = args.get("season")
		if sr is Dictionary:
			UI.choose(self, "New season!", "You finished last season in %s.\nReward: +%d coins" % [
				Game.division_name(int(sr.get("division", 1))), int(sr.get("coins", 0))], ["Awesome"], [UI.ACCENT])
	var r: Dictionary = await Game.refresh_profile()
	if is_inside_tree() and not r.get("ok", false) and r.get("net", false):
		UI.toast(self, "Offline - some info may be out of date")


func on_back() -> void:
	var yes: bool = await UI.confirm(self, "Exit Word Duel?", "", "Exit", "Stay")
	if yes:
		get_tree().quit()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var d := Game.division()
	var tro := Game.pint("trophies")
	var nm := str(Game.profile.get("name", ""))
	_name_l.text = nm
	for c in _avatar_slot.get_children():
		c.queue_free()
	var av := UI.avatar(nm, 84)
	_avatar_slot.add_child(av)
	UI.chip_set(_coins, str(Game.coins()))
	_badge.division = d
	var col := Game.division_color(d)
	_div_l.text = Game.division_name(d).to_upper()
	_div_l.add_theme_color_override("font_color", col.lightened(0.25))
	_rays.modulate = Color(col.lightened(0.3), 0.55)
	_hero.add_theme_stylebox_override("panel", _hero_box(col))
	UI.chip_set(_tro, str(tro))
	UI.chip_set(_rank, "#%d" % Game.pint("rank", 1))
	var streak := Game.pint("streak")
	_streak.visible = streak >= 2
	UI.chip_set(_streak, str(streak))
	var fill := UI.box(col, 13)
	_bar.add_theme_stylebox_override("fill", fill)
	var floor_t := Game.pint("div_floor")
	var next_v = Game.profile.get("next_floor")
	if next_v == null:
		_bar.max_value = 1
		_bar.value = 1
		_next_l.text = "Top division reached!"
	else:
		var nf := int(next_v)
		_bar.max_value = maxf(1.0, float(nf - floor_t))
		_bar.value = float(tro - floor_t)
		_next_l.text = "%d more trophies to %s" % [nf - tro, Game.division_name(d + 1)]
	var weekend: bool = bool(Game.profile.get("weekend", false))
	_weekend_btn.text = "WEEKEND MATCH - OPEN!" if weekend else "WEEKEND MATCH - SAT & SUN"
	var pc := UI.PURPLE if weekend else UI.PURPLE.darkened(0.5)
	_weekend_btn.add_theme_stylebox_override("normal", UI.chunk(pc, 30, 10))
	var left := Game.pint("ads_left", 8)
	_ad_btn.text = "WATCH AD: +25 COINS  (%d)" % left
	_ad_btn.disabled = left <= 0
	for c in _event_box.get_children():
		_event_box.remove_child(c)
		c.queue_free()
	for e in Game.profile.get("events", []):
		var p := UI.panel(Color("4a3406"), 22)
		var h := UI.hbox(14)
		p.add_child(h)
		h.add_child(UI.icon("gift", 64))
		var v := UI.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(str(e.get("title", "")), 30, UI.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, true))
		v.add_child(UI.label(str(e.get("description", "")), 22, UI.TEXT))
		h.add_child(v)
		_event_box.add_child(p)


func _hero_box(col: Color) -> StyleBoxFlat:
	var base := Color("16263f").lerp(col, 0.16)
	var s := UI.card_box(base, 34)
	s.border_color = col.darkened(0.1)
	s.set_border_width_all(3)
	s.border_width_bottom = 8
	return s


func _on_weekend() -> void:
	if bool(Game.profile.get("weekend", false)):
		go("match", {"mode": "weekend"})
	else:
		UI.toast(self, "Weekend matches open on Saturday and Sunday!")


func _on_watch_ad() -> void:
	_ad_btn.disabled = true
	var watched: bool = await Ads.show_rewarded()
	if not is_inside_tree():
		return
	if not watched:
		UI.toast(self, "Watch the whole ad to get the reward")
		_ad_btn.disabled = false
		return
	var r: Dictionary = await Game.call_api("claim_ad_reward")
	if not is_inside_tree():
		return
	if r.get("ok", false):
		Game.set_profile(r["profile"])
		Sfx.play("coin")
		UI.toast(self, "+25 coins!", UI.GOOD.darkened(0.4))
	else:
		UI.toast(self, str(r.get("error", "Could not give the reward")))
		_refresh()
