"""Tiny stand-in for the Supabase RPC API, used only to test the Godot client headlessly."""
import json, sys, time, uuid, random, collections
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPO = sys.argv[1]
words = set(open(REPO + '/data/words.txt').read().split())
puzzles = [l.strip().split(',') for l in open(REPO + '/backend/seed/puzzles.csv').read().split('\n')[1:] if l.strip()]
puzzles = [p for p in puzzles if p[4] == '1']

def neighbors(w):
    for i in range(len(w)):
        for c in 'abcdefghijklmnopqrstuvwxyz':
            n = w[:i] + c + w[i+1:]
            if n != w and n in words:
                yield n

def dist_from(target):
    d = {target: 0}; q = collections.deque([target])
    while q:
        w = q.popleft()
        for n in neighbors(w):
            if n not in d:
                d[n] = d[w] + 1; q.append(n)
    return d

players = {}
matches = {}
daily_scores = []


def profile(p):
    return {'id': p['id'], 'name': p['name'], 'trophies': p['trophies'], 'coins': p['coins'], 'division': 1,
            'div_floor': 0, 'next_floor': 100, 'wins': p['wins'], 'losses': 0, 'draws': 0, 'streak': 0,
            'best_streak': 0, 'rank': 1, 'weekend': False, 'daily_done': False, 'daily_streak': 0, 'ads_left': 8,
            'events': [{'title': 'Harmattan Words Week', 'description': 'Double coins.', 'kind': 'coin_x',
                        'multiplier': 2, 'ends_in': 100000}]}

def state(m, me):
    now = time.time()
    res = m.get('result')
    return {'match_id': m['id'], 'mode': m['mode'], 'status': 'done' if res else 'active', 'room_code': None,
            'start': m['start'], 'target': m['target'], 'shortest': m['shortest'], 'time_limit': 120,
            'division': 1, 'starts_in': m['starts'] - now, 'time_left': 120 - (now - m['starts']),
            'my_words': m['words'], 'my_moves': len(m['words']), 'my_dist': m['dist'],
            'my_done': bool(m['done']), 'my_hints': m['hints'], 'opp_name': 'Kemi_Plays', 'opp_trophies': 12,
            'opp_moves': 1, 'opp_dist': max(0, m['shortest'] - 1), 'opp_done': False, 'opp_bot': True,
            'result': res, 'reason': 'finished' if res else None, 'trophy_delta': 25 if res else None,
            'coin_delta': 50 if res else None, 'doubled': m['doubled']}

def handle(fn, a):
    if fn == 'register_player':
        pid = str(uuid.uuid4()); players[pid] = {'id': pid, 'secret': 's' + pid[:8], 'name': a['p_name'], 'trophies': 0, 'coins': 100, 'wins': 0}
        return {'ok': True, 'id': pid, 'secret': players[pid]['secret']}
    if fn == 'daily_puzzle':
        return {'day': '2026-11-13', 'start': 'cold', 'target': 'warm', 'shortest': 4}
    if fn == 'server_info':
        return {'weekend': False, 'events': [], 'now': 'x'}
    p = players.get(a.get('pid'))
    if not p or p['secret'] != a.get('sec'):
        return ('ERR', {'code': 'P0001', 'message': 'auth_failed'})
    if fn == 'get_profile': return {'ok': True, 'profile': profile(p), 'season_reward': None}
    if fn == 'set_name':
        p['name'] = a['p_name']; return {'ok': True, 'profile': profile(p)}
    if fn == 'find_match' or fn == 'create_room':
        pz = random.choice(puzzles); mid = str(uuid.uuid4())
        matches[mid] = {'id': mid, 'mode': a.get('p_mode', 'friendly'), 'start': pz[0], 'target': pz[1], 'shortest': int(pz[3]),
                        'words': [], 'dist': int(pz[3]), 'done': False, 'hints': 0, 'doubled': False, 'starts': time.time() + 3.5, 'result': None}
        out = {'ok': True, 'match_id': mid}
        if fn == 'create_room': out['code'] = 'ABCD'; matches[mid]['waiting'] = time.time() + 3
        return out
    if fn == 'join_room':
        return ('ERR', {'message': 'x'}) if a['p_code'] != 'ABCD' else {'ok': False, 'error': 'Room not found or already started'}
    if fn == 'cancel_match': return {'ok': True}
    if fn == 'forfeit_match': return {'ok': True}
    if fn == 'poll_match':
        m = matches.get(a['mid'])
        if not m: return {'ok': False, 'error': 'no_match'}
        if m.get('waiting') and time.time() < m['waiting']:
            return {'ok': True, 'state': {'status': 'waiting', 'match_id': m['id']}}
        return {'ok': True, 'state': state(m, p['id'])}
    if fn == 'submit_move':
        m = matches[a['mid']]; w = a['p_word']
        last = m['words'][-1] if m['words'] else m['start']
        if w not in words: return {'ok': False, 'error': 'not_word'}
        if w not in set(neighbors(last)): return {'ok': False, 'error': 'not_one_letter'}
        m['words'].append(w); m['dist'] = dist_from(m['target']).get(w, 9)
        if w == m['target']:
            m['done'] = True; m['result'] = 'win'; p['coins'] += 50
        return {'ok': True, 'state': state(m, p['id'])}
    if fn == 'get_hint':
        m = matches[a['mid']]; m['hints'] += 1
        last = m['words'][-1] if m['words'] else m['start']
        d = dist_from(m['target']); nxt = [n for n in neighbors(last) if d.get(n, 99) == d[last] - 1][0]
        pos = [i for i in range(len(last)) if last[i] != nxt[i]][0]
        return {'ok': True, 'pos': pos, 'letter': nxt[pos], 'coins': p['coins'] - 15}
    if fn == 'double_reward':
        m = matches[a['mid']]; m['doubled'] = True; p['coins'] += 50
        return {'ok': True, 'coins_added': 50, 'profile': profile(p)}
    if fn == 'claim_ad_reward':
        p['coins'] += 25; return {'ok': True, 'coins_added': 25, 'profile': profile(p)}
    if fn == 'submit_daily':
        daily_scores.append((p['name'], len(a['p_path'])))
        return {'ok': True, 'moves': len(a['p_path']), 'best_moves': len(a['p_path']), 'rank': 1, 'coins_added': 35, 'streak': 1, 'profile': profile(p)}
    if fn == 'leaderboard':
        return {'ok': True, 'rows': [{'name': 'Ada', 'trophies': 250, 'division': 3, 'me': False}, {'name': p['name'], 'trophies': 0, 'division': 1, 'me': True}], 'my_rank': 2}
    if fn == 'daily_leaderboard':
        return {'ok': True, 'rows': [{'name': n, 'moves': m, 'seconds': 12.5, 'me': True} for n, m in daily_scores]}
    return ('ERR', {'message': 'unknown fn ' + fn})

class H(BaseHTTPRequestHandler):
    def do_POST(self):
        fn = self.path.rsplit('/', 1)[-1]
        n = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(n) or b'{}')
        ok_headers = self.headers.get('apikey') and self.headers.get('Authorization', '').startswith('Bearer ')
        r = handle(fn, body) if ok_headers else ('ERR', {'message': 'no apikey'})
        code = 200
        if isinstance(r, tuple): code, r = 400, r[1]
        data = json.dumps(r).encode()
        self.send_response(code); self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data))); self.end_headers(); self.wfile.write(data)
    def log_message(self, *a): pass

ThreadingHTTPServer(('127.0.0.1', 8765), H).serve_forever()
