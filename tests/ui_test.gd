extends SceneTree
## Headless smoke test: drives the real game against the mock server.

var main
var fails := 0
var _dlg = null
var game
var api


func _initialize() -> void:
	call_deferred("_run")


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func wait_until(fn: Callable, timeout := 10.0) -> bool:
	var t := 0.0
	while t < timeout:
		if fn.call():
			return true
		await create_timer(0.1).timeout
		t += 0.1
	return false


func screen_is(name: String) -> bool:
	return main.current != null and main.current.get_script().resource_path.ends_with(name + ".gd")


func solve(board) -> void:
	var tries := 0
	while not board.is_solved() and tries < 30:
		tries += 1
		var cur: String = board.current()
		var d: Dictionary = game.dist_map(board.target_word)
		for n in game.neighbors(cur):
			if d.get(n, 99) == d[cur] - 1 and not board.words.has(n):
				for i in cur.length():
					if cur[i] != n[i]:
						board._select(i)
						board.input_letter(n[i])
						break
				break
		await create_timer(0.35).timeout


func find_dialog(node: Node):
	for c in node.get_children():
		if c is Dialog:
			return c
	return null


func _run() -> void:
	var r := get_root()
	api = r.get_node("Api")
	game = r.get_node("Game")
	api.base_url = "http://127.0.0.1:8765"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://word_duel.cfg"))
	game.clear_account()
	check(game.words.size() > 2000, "dictionary loaded (%d words)" % game.words.size())
	check(game.is_word("fire") and not game.is_word("zzzz"), "word lookup")
	check(game.differs_by_one("cold", "cord"), "one-letter check")

	main = load("res://scenes/main.tscn").instantiate()
	r.add_child(main)
	check(await wait_until(func(): return screen_is("name_entry")), "first launch shows name entry")
	main.current._edit.text = "tester1"
	main.current._submit()
	check(await wait_until(func(): return screen_is("home")), "registered and reached home")
	check(game.has_account() and str(game.profile.get("name", "")) == "tester1", "profile loaded")
	await create_timer(0.5).timeout
	check(game.coins() == 100, "coins shown = 100")

	# rewarded ad flow on home
	main.current._on_watch_ad()
	await create_timer(0.4).timeout
	api.get_parent()  # no-op
	r.get_node("Ads")._ad_closed.emit(true)
	check(await wait_until(func(): return game.coins() == 125), "rewarded ad granted +25 coins")

	# ---- match
	main.go("match", {"mode": "ranked"})
	check(await wait_until(func(): return main.current.phase == "countdown"), "match found -> countdown")
	check(await wait_until(func(): return main.current.phase == "play", 8.0), "countdown -> play")
	var m = main.current
	check(m._board.enabled, "board enabled during play")
	# bad input
	m._board.input_letter("a")
	check(m._board.words.size() == 0, "letter without selected tile ignored")
	# hint
	m._on_hint()
	await create_timer(0.3).timeout
	var dlg = find_dialog(m)
	check(dlg != null, "hint dialog opened")
	if dlg:
		dlg.chosen.emit(0)
	check(await wait_until(func(): return m._board.hint_pos >= 0), "hint shown on board")
	await solve(m._board)
	check(await wait_until(func(): return m.finished), "match finished after solving")
	check(str(m.st.get("result")) == "win", "result is win")
	check(game.coins() >= 150, "coins updated from server")
	await create_timer(0.6).timeout

	# ---- daily
	main.go("daily")
	check(await wait_until(func(): return not main.current.puzzle.is_empty()), "daily puzzle loaded")
	await create_timer(0.3).timeout
	await solve(main.current._board)
	check(await wait_until(func():
		_dlg = find_dialog(main.current)
		return _dlg != null), "daily result dialog shown")
	if _dlg:
		_dlg.chosen.emit(2)
	check(await wait_until(func(): return screen_is("home")), "daily -> home")

	# ---- other screens
	for s in ["divisions", "events", "settings", "friend"]:
		main.go(s)
		await create_timer(0.4).timeout
		check(screen_is(s), "screen " + s + " opens")
	main.go("leaderboard")
	await create_timer(0.6).timeout
	check(screen_is("leaderboard") and main.current._list.get_child_count() >= 2, "leaderboard rows")
	main.current._set_tab("daily")
	await create_timer(0.6).timeout
	check(main.current._list.get_child_count() >= 1, "daily leaderboard rows")
	main.go("friend")
	await create_timer(0.3).timeout
	main.current._create()
	check(await wait_until(func(): return main.current._code_l.text == "ABCD"), "friend room created with code")
	check(await wait_until(func(): return screen_is("match"), 6.0), "friend match starts when joined")

	# ---- auth lost -> back to name entry
	game.secret = "wrong"
	main.go("home")
	await create_timer(1.0).timeout
	check(screen_is("name_entry"), "bad credentials -> name entry")

	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
