-- Word Duel backend, part 2: game logic.
-- Internal helpers live in schema wd (not reachable from the API).
-- Public RPCs (what the game calls) live in schema public.

create or replace function wd.div_of(t int) returns int language sql immutable as $$
  select case when t >= 2200 then 7 when t >= 1500 then 6 when t >= 1000 then 5
              when t >= 600 then 4 when t >= 300 then 3 when t >= 100 then 2 else 1 end $$;

create or replace function wd.div_floor(d int) returns int language sql immutable as $$
  select (array[0, 100, 300, 600, 1000, 1500, 2200])[greatest(1, least(7, d))] $$;

create or replace function wd.is_weekend() returns boolean language sql stable as $$
  select coalesce((select value = '1' from wd.settings where key = 'force_weekend'), false)
      or extract(isodow from (now() at time zone 'Africa/Lagos')) in (6, 7) $$;

create or replace function wd.today() returns date language sql stable as $$
  select (now() at time zone 'Africa/Lagos')::date $$;

create or replace function wd.auth(pid uuid, sec text) returns wd.players
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players;
begin
  select * into p from wd.players where id = pid and secret = sec;
  if not found then raise exception 'auth_failed'; end if;
  update wd.players set last_seen = now() where id = pid;
  return p;
end $$;

-- Shortest distance from a word to a target through the word graph
create or replace function wd.dist(cur text, target text) returns int language sql stable as $$
  with recursive r(w, d) as (
    select target, 0
    union
    select e.b, r.d + 1 from r join wd.word_edges e on e.a = r.w where r.d < 18
  ) select min(d) from r where w = cur $$;

create or replace function wd.hamming1(a text, b text) returns boolean language sql immutable as $$
  select length(a) = length(b) and
    (select count(*) from generate_series(1, length(a)) i where substr(a, i, 1) <> substr(b, i, 1)) = 1 $$;

create or replace function wd.event_mult(k text) returns numeric language sql stable as $$
  select coalesce(max(multiplier), 1) from wd.events where kind = k and now() between starts_at and ends_at $$;

create or replace function wd.events_json() returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('title', title, 'description', description, 'kind', kind,
    'multiplier', multiplier, 'ends_in', greatest(0, extract(epoch from (ends_at - now()))::int))
    order by ends_at), '[]'::jsonb)
  from wd.events where now() between starts_at and ends_at $$;

create or replace function wd.profile(p wd.players) returns jsonb language plpgsql stable as $$
declare d int := wd.div_of(p.trophies);
begin
  return jsonb_build_object(
    'id', p.id, 'name', p.name, 'trophies', p.trophies, 'coins', p.coins,
    'division', d, 'div_floor', wd.div_floor(d),
    'next_floor', case when d >= 7 then null else wd.div_floor(d + 1) end,
    'wins', p.wins, 'losses', p.losses, 'draws', p.draws,
    'streak', p.streak, 'best_streak', p.best_streak,
    'rank', (select count(*) + 1 from wd.players x where x.trophies > p.trophies),
    'weekend', wd.is_weekend(),
    'events', wd.events_json(),
    'daily_done', exists (select 1 from wd.daily_scores s where s.day = wd.today() and s.player_id = p.id),
    'daily_streak', p.daily_streak,
    'ads_left', case when p.ad_claim_day = wd.today() then greatest(0, 8 - p.ad_claims) else 8 end
  );
end $$;

create or replace function wd.state(m wd.matches, me uuid) returns jsonb language plpgsql as $$
declare
  v_side int := case when m.p1 = me then 1 else 2 end;
  v_now timestamptz := clock_timestamp();
  o wd.players;
  opp_name text; opp_tr int; opp_moves int := 0; opp_dist int; opp_done boolean := false;
  my_words text[]; my_dist int; my_done boolean; my_hints int; my_delta int; my_coins int; my_dbl boolean;
  el numeric; tot numeric; frac numeric; v_res text; v_in numeric; v_left numeric;
begin
  if v_side = 1 then
    my_words := m.p1_words; my_dist := coalesce(m.p1_dist, m.shortest); my_done := m.p1_done_at is not null;
    my_hints := m.p1_hints; my_delta := m.p1_delta; my_coins := m.p1_coins; my_dbl := m.p1_doubled;
    if m.p2_bot then
      opp_name := m.bot_name; opp_tr := m.bot_trophies;
      tot := greatest(1, extract(epoch from (m.bot_done_at - m.starts_at)));
      el := extract(epoch from (v_now - m.starts_at));
      frac := least(1, greatest(0, el / tot));
      opp_moves := floor(frac * m.bot_moves);
      opp_dist := m.shortest - floor(frac * m.shortest)::int;
      opp_done := v_now >= m.bot_done_at;
    elsif m.p2 is not null then
      select * into o from wd.players where id = m.p2;
      opp_name := o.name; opp_tr := o.trophies;
      opp_moves := coalesce(array_length(m.p2_words, 1), 0);
      opp_dist := coalesce(m.p2_dist, m.shortest); opp_done := m.p2_done_at is not null;
    end if;
  else
    my_words := m.p2_words; my_dist := coalesce(m.p2_dist, m.shortest); my_done := m.p2_done_at is not null;
    my_hints := m.p2_hints; my_delta := m.p2_delta; my_coins := m.p2_coins; my_dbl := m.p2_doubled;
    select * into o from wd.players where id = m.p1;
    opp_name := o.name; opp_tr := o.trophies;
    opp_moves := coalesce(array_length(m.p1_words, 1), 0);
    opp_dist := coalesce(m.p1_dist, m.shortest); opp_done := m.p1_done_at is not null;
  end if;
  if m.status = 'done' and m.p2_bot then
    opp_done := m.result = 'p2' or opp_done; opp_moves := m.bot_moves; opp_dist := case when opp_done then 0 else opp_dist end;
  end if;
  v_res := case m.result when 'draw' then 'draw'
             when 'p1' then case when v_side = 1 then 'win' else 'lose' end
             when 'p2' then case when v_side = 2 then 'win' else 'lose' end end;
  if m.starts_at is not null then
    v_in := extract(epoch from (m.starts_at - v_now));
    v_left := m.time_limit - extract(epoch from (v_now - m.starts_at));
  end if;
  return jsonb_build_object(
    'match_id', m.id, 'mode', m.mode, 'status', m.status, 'room_code', m.room_code,
    'start', m.start_word, 'target', m.target_word, 'shortest', m.shortest, 'time_limit', m.time_limit,
    'division', m.division, 'starts_in', v_in, 'time_left', v_left,
    'my_words', my_words, 'my_moves', coalesce(array_length(my_words, 1), 0), 'my_dist', my_dist,
    'my_done', my_done, 'my_hints', my_hints,
    'opp_name', opp_name, 'opp_trophies', opp_tr, 'opp_moves', opp_moves, 'opp_dist', opp_dist,
    'opp_done', opp_done, 'opp_bot', m.p2_bot,
    'result', v_res, 'reason', m.reason, 'trophy_delta', my_delta, 'coin_delta', my_coins, 'doubled', my_dbl);
end $$;

-- Pay out trophies + coins when a match ends
create or replace function wd.apply(mid uuid) returns void language plpgsql as $$
declare
  m wd.matches; v_tx numeric := wd.event_mult('trophy_x'); v_cx numeric := wd.event_mult('coin_x');
  side int; pid uuid; v_out text; d_tr int; d_co int; p wd.players; v_old int; v_new int;
begin
  select * into m from wd.matches where id = mid;
  for side in 1..2 loop
    pid := case when side = 1 then m.p1 else m.p2 end;
    continue when pid is null;
    v_out := case m.result when 'draw' then 'draw'
               when 'p1' then case when side = 1 then 'win' else 'lose' end
               else case when side = 2 then 'win' else 'lose' end end;
    select * into p from wd.players where id = pid for update;
    d_tr := 0; d_co := 0;
    if m.mode = 'ranked' then
      d_tr := case v_out when 'win' then 25 + least(p.streak, 5) * 2 when 'draw' then 5 else -15 end;
      d_co := case v_out when 'win' then 20 + 5 * m.division when 'draw' then 10 else 5 end;
    elsif m.mode = 'weekend' then
      d_tr := case v_out when 'win' then 40 + least(p.streak, 5) * 2 when 'draw' then 10 else -5 end;
      d_co := case v_out when 'win' then 60 when 'draw' then 25 else 10 end;
    else
      d_co := case v_out when 'win' then 10 when 'draw' then 5 else 2 end;
    end if;
    if d_tr > 0 then d_tr := round(d_tr * v_tx); end if;
    if v_out <> 'lose' then d_co := round(d_co * v_cx); end if;
    v_old := p.trophies;
    v_new := greatest(0, v_old + d_tr);
    if d_tr < 0 then v_new := greatest(v_new, wd.div_floor(wd.div_of(v_old))); end if;
    d_tr := v_new - v_old;
    update wd.players set
      trophies = v_new, coins = coins + d_co,
      wins = wins + case when v_out = 'win' then 1 else 0 end,
      losses = losses + case when v_out = 'lose' then 1 else 0 end,
      draws = draws + case when v_out = 'draw' then 1 else 0 end,
      streak = case v_out when 'win' then streak + 1 when 'lose' then 0 else streak end,
      best_streak = greatest(best_streak, case when v_out = 'win' then streak + 1 else streak end)
    where id = pid;
    if side = 1 then update wd.matches set p1_delta = d_tr, p1_coins = d_co where id = mid;
    else update wd.matches set p2_delta = d_tr, p2_coins = d_co where id = mid; end if;
  end loop;
end $$;

-- Decide the winner if the match can be decided now
create or replace function wd.settle(mid uuid) returns void language plpgsql as $$
declare
  m wd.matches; n timestamptz := clock_timestamp(); t_end timestamptz; d1 timestamptz; d2 timestamptz;
  v_res text; v_reason text; diff numeric; mv1 int; mv2 int; dist1 int; dist2 int; leader timestamptz;
begin
  select * into m from wd.matches where id = mid for update;
  if not found or m.status <> 'active' then return; end if;
  t_end := m.starts_at + make_interval(secs => m.time_limit);
  d1 := m.p1_done_at;
  d2 := case when m.p2_bot then m.bot_done_at else m.p2_done_at end;
  mv1 := coalesce(array_length(m.p1_words, 1), 0);
  mv2 := case when m.p2_bot then m.bot_moves else coalesce(array_length(m.p2_words, 1), 0) end;
  if d1 is not null and d2 is not null then
    diff := extract(epoch from (d2 - d1));
    if abs(diff) < 1.0 then
      if m.mode = 'weekend' and mv1 <> mv2 then
        v_res := case when mv1 < mv2 then 'p1' else 'p2' end; v_reason := 'moves';
      else v_res := 'draw'; v_reason := 'photo_finish'; end if;
    elsif diff > 0 then v_res := 'p1'; v_reason := 'finished';
    else v_res := 'p2'; v_reason := 'finished'; end if;
  elsif d1 is not null or d2 is not null then
    leader := least(coalesce(d1, 'infinity'::timestamptz), coalesce(d2, 'infinity'::timestamptz));
    if n >= leader + interval '1 second' or n >= t_end then
      v_res := case when d1 is not null then 'p1' else 'p2' end; v_reason := 'finished';
    end if;
  elsif n >= t_end then
    dist1 := coalesce(m.p1_dist, m.shortest);
    dist2 := coalesce(m.p2_dist, m.shortest);
    if dist1 <> dist2 then
      v_res := case when dist1 < dist2 then 'p1' else 'p2' end; v_reason := 'timeout';
    elsif m.mode = 'weekend' and mv1 <> mv2 then
      v_res := case when mv1 < mv2 then 'p1' else 'p2' end; v_reason := 'moves';
    else v_res := 'draw'; v_reason := 'timeout'; end if;
  end if;
  if v_res is not null then
    update wd.matches set status = 'done', result = v_res, reason = v_reason, finished_at = n where id = mid;
    perform wd.apply(mid);
  end if;
end $$;

create or replace function wd.make_bot(mid uuid) returns void language plpgsql as $$
declare m wd.matches; names text[] := array['Chidi_K','Tunde99','Amaka_W','Bayo_Wordz','NaijaBoy','Zainab_X',
  'Emeka_Pro','Kemi_Plays','Ada_Queen','Ibrahim_G','Sola_Brain','Ngozi_W','Femi_Ace','Halima_01','Obi_Wan9','Tosin_Fox'];
  v_start timestamptz := clock_timestamp() + interval '3 seconds'; v_secs numeric; t int;
begin
  select * into m from wd.matches where id = mid;
  select trophies into t from wd.players where id = m.p1;
  v_secs := m.shortest * (7.6 - 0.5 * m.division) * (0.8 + random() * 0.5);
  update wd.matches set p2_bot = true, status = 'active', starts_at = v_start,
    bot_name = names[1 + floor(random() * array_length(names, 1))::int],
    bot_trophies = greatest(0, t + floor(random() * 60)::int - 30),
    bot_moves = m.shortest + floor(random() * 2.5)::int,
    bot_done_at = v_start + make_interval(secs => v_secs)
  where id = mid;
end $$;

create or replace function wd.new_match(p wd.players, p_mode text, p_code text) returns uuid language plpgsql as $$
declare d int := wd.div_of(p.trophies); tier int; pz wd.puzzles; mid uuid;
begin
  tier := case when p_mode = 'weekend' then least(7, d + 1) else d end;
  select * into pz from wd.puzzles where division = tier order by random() limit 1;
  insert into wd.matches (mode, room_code, p1, base_div, division, start_word, target_word, shortest, time_limit)
  values (p_mode, p_code, p.id, d, tier, pz.start_word, pz.target_word, pz.dist, least(240, 40 + 15 * pz.dist))
  returning id into mid;
  return mid;
end $$;

-- ---------------------------------------------------------------- public API

create or replace function public.register_player(p_name text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players; nm text := trim(p_name);
begin
  if nm !~ '^[A-Za-z0-9_]{3,16}$' then
    return jsonb_build_object('ok', false, 'error', 'Name must be 3-16 letters, numbers or _');
  end if;
  insert into wd.players (name) values (nm) returning * into p;
  return jsonb_build_object('ok', true, 'id', p.id, 'secret', p.secret);
end $$;

create or replace function public.set_name(pid uuid, sec text, p_name text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); nm text := trim(p_name);
begin
  if nm !~ '^[A-Za-z0-9_]{3,16}$' then
    return jsonb_build_object('ok', false, 'error', 'Name must be 3-16 letters, numbers or _');
  end if;
  update wd.players set name = nm where id = pid returning * into p;
  return jsonb_build_object('ok', true, 'profile', wd.profile(p));
end $$;

create or replace function public.get_profile(pid uuid, sec text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); cur text := to_char(now(), 'YYYY-MM'); v_reward int := 0; v_prev int := 0;
begin
  if p.season <> cur then
    v_prev := wd.div_of(p.trophies);
    v_reward := v_prev * 100;
    update wd.players set season = cur, trophies = floor(trophies * 0.7)::int, coins = coins + v_reward
      where id = pid returning * into p;
  end if;
  return jsonb_build_object('ok', true, 'profile', wd.profile(p),
    'season_reward', case when v_reward > 0 then jsonb_build_object('division', v_prev, 'coins', v_reward) end);
end $$;

create or replace function public.server_info() returns jsonb
language sql security definer set search_path = wd, public as $$
  select jsonb_build_object('weekend', wd.is_weekend(), 'events', wd.events_json(), 'now', now()) $$;

create or replace function public.find_match(pid uuid, sec text, p_mode text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); m wd.matches; mid uuid;
begin
  if p_mode not in ('ranked', 'weekend') then
    return jsonb_build_object('ok', false, 'error', 'bad_mode');
  end if;
  if p_mode = 'weekend' and not wd.is_weekend() then
    return jsonb_build_object('ok', false, 'error', 'weekend_closed');
  end if;
  delete from wd.matches where status = 'waiting' and created_at < now() - interval '2 minutes';
  -- resume an unfinished match
  for m in select * from wd.matches where (p1 = pid or p2 = pid) and status in ('waiting', 'active')
           and room_code is null order by created_at desc loop
    perform wd.settle(m.id);
    select * into m from wd.matches where id = m.id;
    if m.status in ('waiting', 'active') and m.mode = p_mode then
      return jsonb_build_object('ok', true, 'match_id', m.id);
    elsif m.status = 'waiting' then
      delete from wd.matches where id = m.id;
    end if;
  end loop;
  select * into m from wd.matches where status = 'waiting' and mode = p_mode and room_code is null
    and p1 <> pid and not p2_bot and created_at > now() - interval '20 seconds'
    and abs(base_div - wd.div_of(p.trophies)) <= 1
    order by created_at limit 1 for update skip locked;
  if found then
    update wd.matches set p2 = pid, status = 'active', starts_at = clock_timestamp() + interval '4 seconds'
      where id = m.id;
    return jsonb_build_object('ok', true, 'match_id', m.id);
  end if;
  mid := wd.new_match(p, p_mode, null);
  return jsonb_build_object('ok', true, 'match_id', mid);
end $$;

create or replace function public.cancel_match(pid uuid, sec text, mid uuid) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec);
begin
  delete from wd.matches where id = mid and p1 = pid and status = 'waiting';
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.create_room(pid uuid, sec text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); code text; mid uuid; chars text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; i int;
begin
  delete from wd.matches where status = 'waiting' and room_code is not null and created_at < now() - interval '10 minutes';
  delete from wd.matches where status = 'waiting' and room_code is not null and p1 = pid;
  loop
    code := '';
    for i in 1..4 loop code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from wd.matches where room_code = code and status in ('waiting', 'active'));
  end loop;
  mid := wd.new_match(p, 'friendly', code);
  return jsonb_build_object('ok', true, 'match_id', mid, 'code', code);
end $$;

create or replace function public.join_room(pid uuid, sec text, p_code text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); m wd.matches;
begin
  select * into m from wd.matches where room_code = upper(trim(p_code)) and status = 'waiting' for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'Room not found or already started'); end if;
  if m.p1 = pid then return jsonb_build_object('ok', false, 'error', 'This is your own room'); end if;
  update wd.matches set p2 = pid, status = 'active', starts_at = clock_timestamp() + interval '4 seconds' where id = m.id;
  return jsonb_build_object('ok', true, 'match_id', m.id);
end $$;

create or replace function public.poll_match(pid uuid, sec text, mid uuid) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); m wd.matches;
begin
  select * into m from wd.matches where id = mid and (p1 = pid or p2 = pid) for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'no_match'); end if;
  if m.status = 'waiting' and m.room_code is null and m.created_at < now() - interval '7 seconds' then
    perform wd.make_bot(mid);
  end if;
  perform wd.settle(mid);
  select * into m from wd.matches where id = mid;
  return jsonb_build_object('ok', true, 'state', wd.state(m, pid));
end $$;

create or replace function public.submit_move(pid uuid, sec text, mid uuid, p_word text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare
  p wd.players := wd.auth(pid, sec); m wd.matches; side int; v_words text[]; v_last text;
  w text := lower(trim(p_word)); v_dist int; v_now timestamptz := clock_timestamp();
begin
  select * into m from wd.matches where id = mid and (p1 = pid or p2 = pid) for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'no_match'); end if;
  perform wd.settle(mid);
  select * into m from wd.matches where id = mid;
  if m.status <> 'active' then
    return jsonb_build_object('ok', false, 'error', 'not_active', 'state', wd.state(m, pid));
  end if;
  if v_now < m.starts_at - interval '0.3 seconds' then
    return jsonb_build_object('ok', false, 'error', 'not_started');
  end if;
  side := case when m.p1 = pid then 1 else 2 end;
  if (side = 1 and m.p1_done_at is not null) or (side = 2 and m.p2_done_at is not null) then
    return jsonb_build_object('ok', false, 'error', 'already_done');
  end if;
  v_words := case when side = 1 then m.p1_words else m.p2_words end;
  v_last := coalesce(v_words[array_upper(v_words, 1)], m.start_word);
  if length(w) <> length(m.start_word) then
    return jsonb_build_object('ok', false, 'error', 'bad_length');
  end if;
  if not exists (select 1 from wd.words where word = w) then
    return jsonb_build_object('ok', false, 'error', 'not_word');
  end if;
  if not wd.hamming1(w, v_last) then
    return jsonb_build_object('ok', false, 'error', 'not_one_letter');
  end if;
  if w = m.start_word or w = any (v_words) then
    return jsonb_build_object('ok', false, 'error', 'used');
  end if;
  v_dist := coalesce(wd.dist(w, m.target_word), m.shortest);
  if side = 1 then
    update wd.matches set p1_words = array_append(p1_words, w), p1_dist = v_dist,
      p1_done_at = case when w = m.target_word then v_now end where id = mid;
  else
    update wd.matches set p2_words = array_append(p2_words, w), p2_dist = v_dist,
      p2_done_at = case when w = m.target_word then v_now end where id = mid;
  end if;
  perform wd.settle(mid);
  select * into m from wd.matches where id = mid;
  return jsonb_build_object('ok', true, 'state', wd.state(m, pid));
end $$;

create or replace function public.forfeit_match(pid uuid, sec text, mid uuid) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); m wd.matches;
begin
  select * into m from wd.matches where id = mid and (p1 = pid or p2 = pid) for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'no_match'); end if;
  if m.status = 'waiting' then
    delete from wd.matches where id = mid;
    return jsonb_build_object('ok', true);
  end if;
  if m.status = 'active' then
    update wd.matches set status = 'done', reason = 'forfeit', finished_at = clock_timestamp(),
      result = case when m.p1 = pid then 'p2' else 'p1' end where id = mid;
    perform wd.apply(mid);
  end if;
  select * into m from wd.matches where id = mid;
  return jsonb_build_object('ok', true, 'state', wd.state(m, pid));
end $$;

create or replace function public.get_hint(pid uuid, sec text, mid uuid, via_ad boolean) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare
  p wd.players := wd.auth(pid, sec); m wd.matches; side int; v_words text[]; v_last text; v_next text;
  v_hints int; i int;
begin
  select * into m from wd.matches where id = mid and (p1 = pid or p2 = pid) for update;
  if not found or m.status <> 'active' then return jsonb_build_object('ok', false, 'error', 'not_active'); end if;
  side := case when m.p1 = pid then 1 else 2 end;
  v_hints := case when side = 1 then m.p1_hints else m.p2_hints end;
  if v_hints >= 2 then return jsonb_build_object('ok', false, 'error', 'No hints left in this match'); end if;
  if not via_ad and p.coins < 15 then return jsonb_build_object('ok', false, 'error', 'Not enough coins'); end if;
  v_words := case when side = 1 then m.p1_words else m.p2_words end;
  v_last := coalesce(v_words[array_upper(v_words, 1)], m.start_word);
  with recursive r(w, d) as (
    select m.target_word, 0
    union
    select e.b, r.d + 1 from r join wd.word_edges e on e.a = r.w where r.d < 18
  ), dd as (select w, min(d) d from r group by w)
  select e.b into v_next from wd.word_edges e join dd on dd.w = e.b
  where e.a = v_last and dd.d = (select d from dd where w = v_last) - 1 and not (e.b = any (v_words))
  order by random() limit 1;
  if v_next is null then return jsonb_build_object('ok', false, 'error', 'No hint available'); end if;
  i := 0;
  while i < length(v_last) and substr(v_last, i + 1, 1) = substr(v_next, i + 1, 1) loop
    i := i + 1;
  end loop;
  if side = 1 then update wd.matches set p1_hints = p1_hints + 1 where id = mid;
  else update wd.matches set p2_hints = p2_hints + 1 where id = mid; end if;
  if not via_ad then update wd.players set coins = coins - 15 where id = pid; end if;
  return jsonb_build_object('ok', true, 'pos', i, 'letter', substr(v_next, i + 1, 1),
    'coins', p.coins - case when via_ad then 0 else 15 end);
end $$;

create or replace function public.double_reward(pid uuid, sec text, mid uuid) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); m wd.matches; side int; c int;
begin
  select * into m from wd.matches where id = mid and (p1 = pid or p2 = pid) for update;
  if not found or m.status <> 'done' then return jsonb_build_object('ok', false); end if;
  side := case when m.p1 = pid then 1 else 2 end;
  if (side = 1 and m.p1_doubled) or (side = 2 and m.p2_doubled) then return jsonb_build_object('ok', false); end if;
  c := coalesce(case when side = 1 then m.p1_coins else m.p2_coins end, 0);
  if side = 1 then update wd.matches set p1_doubled = true where id = mid;
  else update wd.matches set p2_doubled = true where id = mid; end if;
  update wd.players set coins = coins + c where id = pid returning * into p;
  return jsonb_build_object('ok', true, 'coins_added', c, 'profile', wd.profile(p));
end $$;

create or replace function public.claim_ad_reward(pid uuid, sec text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec);
begin
  if p.ad_claim_day is distinct from wd.today() then
    update wd.players set ad_claim_day = wd.today(), ad_claims = 0 where id = pid returning * into p;
  end if;
  if p.ad_claims >= 8 then return jsonb_build_object('ok', false, 'error', 'Daily ad reward limit reached'); end if;
  update wd.players set coins = coins + 25, ad_claims = ad_claims + 1 where id = pid returning * into p;
  return jsonb_build_object('ok', true, 'coins_added', 25, 'profile', wd.profile(p));
end $$;

create or replace function public.daily_puzzle() returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare pz wd.puzzles;
begin
  select * into pz from wd.puzzles where division in (2, 3, 4, 5)
    order by md5(id::text || to_char(wd.today(), 'YYYYMMDD')) limit 1;
  return jsonb_build_object('day', wd.today(), 'start', pz.start_word, 'target', pz.target_word, 'shortest', pz.dist);
end $$;

create or replace function public.submit_daily(pid uuid, sec text, p_path text[], p_seconds numeric) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare
  p wd.players := wd.auth(pid, sec); pz jsonb := public.daily_puzzle(); prev text; w text; seen text[] := '{}';
  v_moves int; v_first boolean; v_award int := 0; v_streak int; v_rank int; v_best wd.daily_scores;
begin
  prev := pz ->> 'start';
  if p_path is null or array_length(p_path, 1) is null then return jsonb_build_object('ok', false, 'error', 'empty'); end if;
  foreach w in array p_path loop
    w := lower(w);
    if not exists (select 1 from wd.words where word = w) or not wd.hamming1(w, prev) or w = any (seen) or w = pz ->> 'start' then
      return jsonb_build_object('ok', false, 'error', 'invalid_path');
    end if;
    seen := array_append(seen, w); prev := w;
  end loop;
  if prev <> pz ->> 'target' then return jsonb_build_object('ok', false, 'error', 'invalid_path'); end if;
  v_moves := array_length(p_path, 1);
  v_first := not exists (select 1 from wd.daily_scores where day = wd.today() and player_id = pid);
  insert into wd.daily_scores as ds (day, player_id, moves, seconds) values (wd.today(), pid, v_moves, greatest(1, p_seconds))
  on conflict (day, player_id) do update set
    moves = excluded.moves, seconds = excluded.seconds
    where (excluded.moves, excluded.seconds) < (ds.moves, ds.seconds);
  if v_first then
    v_streak := case when p.last_daily = wd.today() - 1 then p.daily_streak + 1 else 1 end;
    v_award := 30 + least(v_streak, 7) * 5;
    update wd.players set coins = coins + v_award, daily_streak = v_streak, last_daily = wd.today()
      where id = pid returning * into p;
  end if;
  select * into v_best from wd.daily_scores where day = wd.today() and player_id = pid;
  select count(*) + 1 into v_rank from wd.daily_scores s where s.day = wd.today()
    and (s.moves, s.seconds) < (v_best.moves, v_best.seconds);
  return jsonb_build_object('ok', true, 'moves', v_moves, 'best_moves', v_best.moves, 'rank', v_rank,
    'coins_added', v_award, 'streak', p.daily_streak, 'profile', wd.profile(p));
end $$;

create or replace function public.daily_leaderboard(pid uuid, sec text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec);
begin
  return jsonb_build_object('ok', true,
    'rows', coalesce((select jsonb_agg(jsonb_build_object('name', x.name, 'moves', x.moves, 'seconds', x.seconds, 'me', x.id = pid))
      from (select pl.id, pl.name, s.moves, s.seconds from wd.daily_scores s join wd.players pl on pl.id = s.player_id
            where s.day = wd.today() order by s.moves, s.seconds limit 30) x), '[]'::jsonb));
end $$;

create or replace function public.leaderboard(pid uuid, sec text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec);
begin
  return jsonb_build_object('ok', true,
    'rows', coalesce((select jsonb_agg(jsonb_build_object('name', x.name, 'trophies', x.trophies,
        'division', wd.div_of(x.trophies), 'me', x.id = pid) order by x.trophies desc, x.name)
      from (select id, name, trophies from wd.players order by trophies desc, name limit 50) x), '[]'::jsonb),
    'my_rank', (select count(*) + 1 from wd.players where trophies > p.trophies));
end $$;

-- Only the public RPCs are callable from the app
revoke all on schema wd from public, anon, authenticated;

-- Events and settings seed
insert into wd.events (title, description, kind, multiplier, starts_at, ends_at) values
  ('Harmattan Words Week', 'Double coins on every win and draw.', 'coin_x', 2, '2026-11-12 00:00+01', '2026-11-20 00:00+01'),
  ('Black Friday Trophy Rush', 'Double trophies for every win!', 'trophy_x', 2, '2026-11-27 00:00+01', '2026-11-30 00:00+01'),
  ('December Detty Double', 'Double trophies all festive season.', 'trophy_x', 2, '2026-12-20 00:00+01', '2027-01-03 00:00+01');
