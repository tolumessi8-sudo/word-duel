extends Node
## Global configuration. Edit the values here.

const VERSION := "1.0.0"

# --- Backend (Supabase) -----------------------------------------------------
const SUPABASE_URL := "https://aikwoaelxgxlxvzvlgyi.supabase.co"
# Public "anon" key. It is safe to ship in the app: the database only exposes the game RPC functions.
const SUPABASE_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFpa3dvYWVseGd4bHh2enZsZ3lpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ0NzA2NjIsImV4cCI6MjExMDA0NjY2Mn0.zw271IscEkB6wQq2ai74NUYz5cj46SUqBjLj3RyaXe8"

# --- Ads (Google's public TEST ids; replace with your own AdMob ids before release) ---
const ADMOB_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ADMOB_BANNER := "ca-app-pub-3940256099942544/6300978111"
const ADMOB_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const ADMOB_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const INTERSTITIAL_EVERY := 3   # show a full-screen ad after every N finished matches

# --- Divisions ---------------------------------------------------------------
const DIVISIONS := [
	{"name": "Rookie", "from": 0, "color": Color("a1887f"), "puzzle": "3-letter words, short ladders"},
	{"name": "Bronze", "from": 100, "color": Color("cd7f32"), "puzzle": "4-letter words, short ladders"},
	{"name": "Silver", "from": 300, "color": Color("c0c7d1"), "puzzle": "4-letter words, medium ladders"},
	{"name": "Gold", "from": 600, "color": Color("ffc933"), "puzzle": "4-letter words, long ladders"},
	{"name": "Platinum", "from": 1000, "color": Color("5ee0d0"), "puzzle": "5-letter words"},
	{"name": "Diamond", "from": 1500, "color": Color("5aa9ff"), "puzzle": "5-letter words, long ladders"},
	{"name": "Legend", "from": 2200, "color": Color("ff4d8d"), "puzzle": "6-letter words"},
]
