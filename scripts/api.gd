extends Node
## Thin HTTP client for the Supabase RPC functions.
## Every call returns a Dictionary. Network problems come back as {"ok": false, "net": true}.

var timeout_s := 12.0
var base_url := ""    # tests can override this; empty = Config.SUPABASE_URL


func call_rpc(fn: String, args: Dictionary = {}) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = timeout_s
	add_child(req)
	var headers := PackedStringArray([
		"apikey: " + Config.SUPABASE_KEY,
		"Authorization: Bearer " + Config.SUPABASE_KEY,
		"Content-Type: application/json",
	])
	var root := base_url if base_url != "" else Config.SUPABASE_URL
	var err := req.request(root + "/rest/v1/rpc/" + fn, headers, HTTPClient.METHOD_POST, JSON.stringify(args))
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "network", "net": true}
	var res: Array = await req.request_completed
	req.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var body: PackedByteArray = res[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "network", "net": true}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if code < 200 or code >= 300:
		var msg := "server"
		if parsed is Dictionary:
			msg = str(parsed.get("message", "server"))
		return {"ok": false, "error": msg, "net": code >= 500, "code": code}
	if parsed is Dictionary:
		return parsed
	return {"ok": false, "error": "bad_response"}
