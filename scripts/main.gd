extends Control
## Root scene: owns the background and swaps screens.

const SCREENS := {
	"boot": preload("res://scripts/screens/boot.gd"),
	"name": preload("res://scripts/screens/name_entry.gd"),
	"home": preload("res://scripts/screens/home.gd"),
	"match": preload("res://scripts/screens/match.gd"),
	"daily": preload("res://scripts/screens/daily.gd"),
	"friend": preload("res://scripts/screens/friend.gd"),
	"divisions": preload("res://scripts/screens/divisions.gd"),
	"leaderboard": preload("res://scripts/screens/leaderboard.gd"),
	"events": preload("res://scripts/screens/events.gd"),
	"settings": preload("res://scripts/screens/settings.gd"),
}

var current: Screen


func _ready() -> void:
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	get_tree().set_auto_accept_quit(false)
	get_tree().quit_on_go_back = false
	Game.auth_lost.connect(_on_auth_lost)
	go("boot")


func go(screen: String, args: Dictionary = {}) -> void:
	if current != null:
		current.queue_free()
		current = null
	var s: Screen = SCREENS[screen].new()
	s.main = self
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(s)
	current = s
	s.start(args)


func _on_auth_lost() -> void:
	Game.clear_account()
	go("name", {"notice": "Your session expired. Please pick a username again."})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current != null:
			current.on_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
