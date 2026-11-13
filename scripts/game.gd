extends Node
## Global game state: account, profile, dictionary, helpers shared by every screen.

signal profile_changed
signal auth_lost

const SAVE_PATH := "user://word_duel.cfg"

var player_id := ""
var secret := ""
var profile: Dictionary = {}
var sound_on := true
var matches_since_ad := 0

var words: Dictionary = {}          # word -> true
var _buckets: Dictionary = {}       # "len:pos:pattern" -> Array[String]
var _dist_cache: Dictionary = {}    # target -> Dictionary(word -> distance)


func _ready() -> void:
	load_settings()
	load_words()


# ---------------------------------------------------------------- save data

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	player_id = str(cfg.get_value("auth", "id", ""))
	secret = str(cfg.get_value("auth", "secret", ""))
	sound_on = bool(cfg.get_value("settings", "sound", true))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "id", player_id)
	cfg.set_value("auth", "secret", secret)
	cfg.set_value("settings", "sound", sound_on)
	cfg.save(SAVE_PATH)


func has_account() -> bool:
	return player_id != "" and secret != ""


func set_account(id: String, sec: String) -> void:
	player_id = id
	secret = sec
	save_settings()


func clear_account() -> void:
	player_id = ""
	secret = ""
	profile = {}
	save_settings()


# ---------------------------------------------------------------- server calls

## Calls an RPC that needs the player's credentials.
func call_api(fn: String, args: Dictionary = {}) -> Dictionary:
	var a := args.duplicate()
	a["pid"] = player_id
	a["sec"] = secret
	var r: Dictionary = await Api.call_rpc(fn, a)
	if not r.get("ok", true) and str(r.get("error", "")) == "auth_failed":
		auth_lost.emit()
	return r


func refresh_profile() -> Dictionary:
	var r: Dictionary = await call_api("get_profile")
	if r.get("ok", false) and r.has("profile"):
		set_profile(r["profile"])
	return r


func set_profile(p: Dictionary) -> void:
	profile = p
	profile_changed.emit()


func pint(key: String, default := 0) -> int:
	var v = profile.get(key, default)
	return int(v) if v != null else default


func coins() -> int:
	return pint("coins")


func division() -> int:
	return clampi(pint("division", 1), 1, 7)


func division_name(d: int) -> String:
	return str(Config.DIVISIONS[clampi(d, 1, 7) - 1]["name"])


func division_color(d: int) -> Color:
	return Config.DIVISIONS[clampi(d, 1, 7) - 1]["color"]


# ---------------------------------------------------------------- dictionary

func load_words() -> void:
	if not words.is_empty():
		return
	var txt := FileAccess.get_file_as_string("res://data/words.txt")
	for line in txt.split("\n", false):
		var w := line.strip_edges().to_lower()
		if w != "":
			words[w] = true
	for w in words.keys():
		for i in w.length():
			var key := _bucket_key(w, i)
			if not _buckets.has(key):
				_buckets[key] = []
			_buckets[key].append(w)


func _bucket_key(w: String, i: int) -> String:
	return "%d:%d:%s" % [w.length(), i, w.substr(0, i) + "_" + w.substr(i + 1)]


func is_word(w: String) -> bool:
	return words.has(w.to_lower())


func differs_by_one(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var n := 0
	for i in a.length():
		if a[i] != b[i]:
			n += 1
	return n == 1


func neighbors(w: String) -> Array:
	var out: Array = []
	for i in w.length():
		for n in _buckets.get(_bucket_key(w, i), []):
			if n != w:
				out.append(n)
	return out


## Distance (in moves) from every word to the target, computed once per target.
func dist_map(target: String) -> Dictionary:
	if _dist_cache.has(target):
		return _dist_cache[target]
	var d := {target: 0}
	var q := [target]
	var head := 0
	while head < q.size():
		var w: String = q[head]
		head += 1
		for n in neighbors(w):
			if not d.has(n):
				d[n] = d[w] + 1
				q.append(n)
	if _dist_cache.size() > 6:
		_dist_cache.clear()
	_dist_cache[target] = d
	return d


func local_dist(word: String, target: String) -> int:
	return int(dist_map(target).get(word, 99))


## A local hint: {pos, letter} for the next step on a shortest path, or {}.
func local_hint(current: String, target: String, used: Array) -> Dictionary:
	var d := dist_map(target)
	if not d.has(current):
		return {}
	var best := []
	for n in neighbors(current):
		if d.get(n, 99) == d[current] - 1 and not used.has(n):
			best.append(n)
	if best.is_empty():
		return {}
	var nxt: String = best[randi() % best.size()]
	for i in current.length():
		if current[i] != nxt[i]:
			return {"pos": i, "letter": nxt[i]}
	return {}
