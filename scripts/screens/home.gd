extends Screen
## Main menu.

var _name_l: Label
var _coins_l: Label
var _badge: Badge
var _div_l: Label
var _tro_l: Label
var _bar: ProgressBar
var _next_l: Label
var _event_box: VBoxContainer
var _weekend_btn: Button
var _ad_btn: Button


func start(args: Dictionary) -> void:
	var root := make_root(24)
	root.add_theme_constant_override("separation", 14)

	var top := UI.hbox(12)
	_name_l = UI.label("", 36, UI.TEXT)
	_name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_name_l)
	var chip := UI.panel(UI.PANEL, 20)
	_coins_l = UI.label("", 30, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_coins_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(_coins_l)
	top.add_child(chip)
	var set_btn := UI.btn("Settings", UI.PANEL2, 64, 24)
	set_btn.custom_minimum_size = Vector2(140, 64)
	set_btn.pressed.connect(func() -> void: go("settings"))
	top.add_child(set_btn)
	root.add_child(top)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var body := UI.vbox(16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# division card
	var card := UI.panel(UI.PANEL, 28)
	var ch := UI.hbox(20)
	card.add_child(ch)
	_badge = Badge.new(1, 150)
	ch.add_child(_badge)
	var cv := UI.vbox(8)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_child(cv)
	_div_l = UI.label("", 44, UI.ACCENT)
	cv.add_child(_div_l)
	_tro_l = UI.label("", 28, UI.TEXT)
	cv.add_child(_tro_l)
	_bar = UI.bar(100, UI.ACCENT, 22)
	cv.add_child(_bar)
	_next_l = UI.label("", 24, UI.MUTED)
	cv.add_child(_next_l)
	body.add_child(card)

	_event_box = UI.vbox(10)
	body.add_child(_event_box)

	var play := UI.btn("PLAY RANKED", UI.ACCENT, 120, 46)
	play.pressed.connect(func() -> void: go("match", {"mode": "ranked"}))
	body.add_child(play)

	_weekend_btn = UI.btn("", UI.PURPLE, 96, 32)
	_weekend_btn.pressed.connect(_on_weekend)
	body.add_child(_weekend_btn)

	var row1 := UI.hbox(14)
	var daily := UI.btn("DAILY PUZZLE", UI.BLUE, 92, 28)
	daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	daily.pressed.connect(func() -> void: go("daily"))
	row1.add_child(daily)
	var friend := UI.btn("PLAY A FRIEND", Color("14b8a6"), 92, 28)
	friend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friend.pressed.connect(func() -> void: go("friend"))
	row1.add_child(friend)
	body.add_child(row1)

	var row2 := UI.hbox(12)
	for item in [["Divisions", "divisions"], ["Leaderboard", "leaderboard"], ["Events", "events"]]:
		var b := UI.btn(str(item[0]), UI.PANEL2, 80, 25)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var target: String = item[1]
		b.pressed.connect(func() -> void: go(target))
		row2.add_child(b)
	body.add_child(row2)

	_ad_btn = UI.btn("", UI.PANEL2, 80, 26)
	_ad_btn.pressed.connect(_on_watch_ad)
	body.add_child(_ad_btn)

	var how := UI.btn("How to play", UI.PANEL2, 70, 24)
	how.pressed.connect(show_howto)
	body.add_child(how)

	root.add_child(banner_strip())

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
	_name_l.text = str(Game.profile.get("name", ""))
	_coins_l.text = "%d coins" % Game.coins()
	_badge.division = d
	_div_l.text = Game.division_name(d)
	_div_l.add_theme_color_override("font_color", Game.division_color(d))
	_tro_l.text = "%d trophies   Rank #%d" % [tro, Game.pint("rank", 1)]
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
		_next_l.text = "%d more to %s" % [nf - tro, Game.division_name(d + 1)]
	var weekend: bool = bool(Game.profile.get("weekend", false))
	_weekend_btn.text = "WEEKEND MATCH  -  OPEN NOW!" if weekend else "WEEKEND MATCH  -  Sat & Sun"
	var pc := UI.PURPLE if weekend else UI.PURPLE.darkened(0.45)
	_weekend_btn.add_theme_stylebox_override("normal", UI.box(pc, 22))
	var left := Game.pint("ads_left", 8)
	_ad_btn.text = "Watch an ad: +25 coins  (%d left today)" % left
	_ad_btn.disabled = left <= 0
	for c in _event_box.get_children():
		_event_box.remove_child(c)
		c.queue_free()
	for e in Game.profile.get("events", []):
		var p := UI.panel(Color("3b2a05"), 20)
		var v := UI.vbox(2)
		p.add_child(v)
		v.add_child(UI.label("EVENT: " + str(e.get("title", "")), 28, UI.ACCENT))
		v.add_child(UI.label(str(e.get("description", "")), 24, UI.TEXT))
		_event_box.add_child(p)


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
