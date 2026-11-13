extends Node
## Ads layer. The game only talks to this file.
##
## Right now it runs SIMULATED test ads (a full-screen placeholder with a countdown), so the whole
## ad flow (banner, interstitial every N matches, rewarded ads for hints/coins/double rewards) can be
## played and tested without any plugin. To show real AdMob ads, add an AdMob plugin for Godot 4
## (see README.md, "Real AdMob ads") and call it from the three marked places below.

signal banner_changed

var banner_enabled := true
var _layer: CanvasLayer
signal _ad_closed(completed: bool)


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)


## Height reserved at the bottom of the screen for the banner.
func banner_height() -> int:
	return 90 if banner_enabled else 0


func set_banner(on: bool) -> void:
	banner_enabled = on
	banner_changed.emit()
	# REAL ADS: show or hide the AdMob banner here (Config.ADMOB_BANNER).


## Call after every finished match. Shows a full-screen ad every Config.INTERSTITIAL_EVERY matches.
func after_match() -> void:
	Game.matches_since_ad += 1
	if Game.matches_since_ad >= Config.INTERSTITIAL_EVERY:
		Game.matches_since_ad = 0
		await show_interstitial()


func show_interstitial() -> void:
	# REAL ADS: load + show Config.ADMOB_INTERSTITIAL here and await its closed signal.
	await _fake_ad("Interstitial ad (test)", 3, false)


## Returns true if the player watched the ad to the end and earned the reward.
func show_rewarded() -> bool:
	# REAL ADS: load + show Config.ADMOB_REWARDED here, return true when the reward callback fires.
	return await _fake_ad("Rewarded ad (test)\nWatch to the end to earn your reward", 5, true)


func _fake_ad(title: String, secs: int, rewarded: bool) -> bool:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.1, 0.98)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 38)
	box.add_child(t)
	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 64)
	box.add_child(count)
	var close := Button.new()
	close.custom_minimum_size = Vector2(420, 90)
	close.add_theme_font_size_override("font_size", 32)
	box.add_child(close)

	var state := {"left": secs}
	var refresh := func() -> void:
		count.text = str(state["left"]) if state["left"] > 0 else "Done"
		if state["left"] > 0:
			close.text = "Close (no reward)" if rewarded else "Please wait..."
			close.disabled = not rewarded
		else:
			close.text = "Claim reward" if rewarded else "Close"
			close.disabled = false
	refresh.call()
	close.pressed.connect(func() -> void: _ad_closed.emit(state["left"] <= 0))
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		state["left"] = maxi(0, state["left"] - 1)
		refresh.call())
	root.add_child(timer)
	_layer.add_child(root)
	var completed: bool = await _ad_closed
	root.queue_free()
	return completed
