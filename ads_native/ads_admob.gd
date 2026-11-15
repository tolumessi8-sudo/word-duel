extends RefCounted
## Real AdMob ads (Poing Studios plugin). This file is only copied into scripts/ by the
## "Build Android APK (real ads)" workflow, because it needs the AdMob addon to compile.
## Ads.gd loads it at runtime on Android and falls back to simulated ads if it is missing.

signal _loaded(ad)
signal _closed

var _tree: SceneTree
var _banner
var _earned := false
var ready_ok := false


func _init(tree: SceneTree) -> void:
	_tree = tree


func start() -> void:
	MobileAds.initialize()
	ready_ok = true


func show_banner(on: bool) -> void:
	if not ready_ok:
		return
	if not on:
		if _banner != null:
			_banner.destroy()
			_banner = null
		return
	if _banner != null:
		return
	_banner = AdView.new(Config.ADMOB_BANNER, AdSize.BANNER, AdPosition.BOTTOM)
	_banner.load_ad(AdRequest.new())


func _timeout(secs: float) -> void:
	_tree.create_timer(secs).timeout.connect(func() -> void: _loaded.emit(null))


func show_interstitial() -> void:
	if not ready_ok:
		return
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad) -> void: _loaded.emit(ad)
	cb.on_ad_failed_to_load = func(err) -> void:
		push_warning("Interstitial failed to load: " + str(err.message))
		_loaded.emit(null)
	InterstitialAdLoader.new().load(Config.ADMOB_INTERSTITIAL, AdRequest.new(), cb)
	_timeout(8.0)
	var ad = await _loaded
	if ad == null:
		return
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func() -> void: _closed.emit()
	fs.on_ad_failed_to_show_full_screen_content = func(_e) -> void: _closed.emit()
	ad.full_screen_content_callback = fs
	ad.show()
	await _closed
	ad.destroy()


## True if the player earned the reward.
func show_rewarded() -> bool:
	if not ready_ok:
		return false
	_earned = false
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad) -> void: _loaded.emit(ad)
	cb.on_ad_failed_to_load = func(err) -> void:
		push_warning("Rewarded failed to load: " + str(err.message))
		_loaded.emit(null)
	RewardedAdLoader.new().load(Config.ADMOB_REWARDED, AdRequest.new(), cb)
	_timeout(10.0)
	var ad = await _loaded
	if ad == null:
		return false
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func() -> void: _closed.emit()
	fs.on_ad_failed_to_show_full_screen_content = func(_e) -> void: _closed.emit()
	ad.full_screen_content_callback = fs
	var rl := OnUserEarnedRewardListener.new()
	rl.on_user_earned_reward = func(_item) -> void: _earned = true
	ad.show(rl)
	await _closed
	ad.destroy()
	return _earned
