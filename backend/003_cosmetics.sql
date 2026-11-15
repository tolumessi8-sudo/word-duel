alter table wd.players add column if not exists avatar int not null default -1;
alter table wd.players add column if not exists frame int not null default 0;
alter table wd.players add column if not exists owned text[] not null default '{}';
alter table wd.matches add column if not exists p1_emote text;
alter table wd.matches add column if not exists p1_emote_n int not null default 0;
alter table wd.matches add column if not exists p2_emote text;
alter table wd.matches add column if not exists p2_emote_n int not null default 0;

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
    'avatar', p.avatar, 'frame', p.frame, 'owned', to_jsonb(p.owned),
    'ads_left', case when p.ad_claim_day = wd.today() then greatest(0, 8 - p.ad_claims) else 8 end
  );
end $$;

create or replace function wd.state(m wd.matches, me uuid) returns jsonb language plpgsql as $$
declare
  v_side int := case when m.p1 = me then 1 else 2 end;
  v_now timestamptz := clock_timestamp();
  o wd.players;
  opp_av int := -1; opp_fr int := 0; opp_em text; opp_em_n int := 0;
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
      opp_em := m.p2_emote; opp_em_n := m.p2_emote_n;
    elsif m.p2 is not null then
      select * into o from wd.players where id = m.p2;
      opp_name := o.name; opp_tr := o.trophies; opp_av := o.avatar; opp_fr := o.frame;
      opp_em := m.p2_emote; opp_em_n := m.p2_emote_n;
      opp_moves := coalesce(array_length(m.p2_words, 1), 0);
      opp_dist := coalesce(m.p2_dist, m.shortest); opp_done := m.p2_done_at is not null;
    end if;
  else
    my_words := m.p2_words; my_dist := coalesce(m.p2_dist, m.shortest); my_done := m.p2_done_at is not null;
    my_hints := m.p2_hints; my_delta := m.p2_delta; my_coins := m.p2_coins; my_dbl := m.p2_doubled;
    select * into o from wd.players where id = m.p1;
    opp_name := o.name; opp_tr := o.trophies; opp_av := o.avatar; opp_fr := o.frame;
    opp_em := m.p1_emote; opp_em_n := m.p1_emote_n;
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
    'opp_avatar', opp_av, 'opp_frame', opp_fr, 'opp_emote', opp_em, 'opp_emote_n', opp_em_n,
    'result', v_res, 'reason', m.reason, 'trophy_delta', my_delta, 'coin_delta', my_coins, 'doubled', my_dbl);
end $$;

create or replace function public.leaderboard(pid uuid, sec text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec);
begin
  return jsonb_build_object('ok', true,
    'rows', coalesce((select jsonb_agg(jsonb_build_object('name', x.name, 'trophies', x.trophies,
        'division', wd.div_of(x.trophies), 'avatar', x.avatar, 'frame', x.frame, 'me', x.id = pid) order by x.trophies desc, x.name)
      from (select id, name, trophies, avatar, frame from wd.players order by trophies desc, name limit 50) x), '[]'::jsonb),
    'my_rank', (select count(*) + 1 from wd.players where trophies > p.trophies));
end $$;

-- ---------------------------------------------------------------- cosmetics + emotes
create or replace function wd.item_price(p_item text) returns int language sql immutable as $$
  select case p_item
    when 'av_0' then 0 when 'av_1' then 0 when 'av_2' then 0 when 'av_3' then 0 when 'av_4' then 0 when 'av_5' then 0
    when 'av_6' then 200 when 'av_7' then 200 when 'av_8' then 300 when 'av_9' then 300 when 'av_10' then 500 when 'av_11' then 500
    when 'fr_0' then 0 when 'fr_1' then 150 when 'fr_2' then 250 when 'fr_3' then 250 when 'fr_4' then 400 when 'fr_5' then 800
  end
$$;

create or replace function public.buy_item(pid uuid, sec text, p_item text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); v_price int := wd.item_price(p_item);
begin
  if v_price is null then return jsonb_build_object('ok', false, 'error', 'unknown_item'); end if;
  if v_price = 0 or p_item = any (p.owned) then return jsonb_build_object('ok', false, 'error', 'already_owned'); end if;
  if p.coins < v_price then return jsonb_build_object('ok', false, 'error', 'not_enough_coins'); end if;
  update wd.players set coins = coins - v_price, owned = array_append(owned, p_item) where id = pid returning * into p;
  return jsonb_build_object('ok', true, 'profile', wd.profile(p));
end $$;

create or replace function public.equip_item(pid uuid, sec text, p_slot text, p_idx int) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); v_id text;
begin
  if p_slot not in ('avatar', 'frame') or p_idx < 0 or p_idx > 11 then return jsonb_build_object('ok', false, 'error', 'bad_item'); end if;
  v_id := case when p_slot = 'avatar' then 'av_' else 'fr_' end || p_idx;
  if wd.item_price(v_id) is null then return jsonb_build_object('ok', false, 'error', 'bad_item'); end if;
  if wd.item_price(v_id) > 0 and not (v_id = any (p.owned)) then return jsonb_build_object('ok', false, 'error', 'not_owned'); end if;
  if p_slot = 'avatar' then update wd.players set avatar = p_idx where id = pid returning * into p;
  else update wd.players set frame = p_idx where id = pid returning * into p; end if;
  return jsonb_build_object('ok', true, 'profile', wd.profile(p));
end $$;

create or replace function public.send_emote(pid uuid, sec text, mid uuid, p_emote text) returns jsonb
language plpgsql security definer set search_path = wd, public as $$
declare p wd.players := wd.auth(pid, sec); m wd.matches;
begin
  if p_emote not in ('gg', 'wow', 'oops', 'fast', 'nice', 'hmm') then return jsonb_build_object('ok', false, 'error', 'bad_emote'); end if;
  select * into m from wd.matches where id = mid and (p1 = pid or p2 = pid) and status <> 'waiting';
  if not found then return jsonb_build_object('ok', false, 'error', 'no_match'); end if;
  if m.p1 = pid then
    update wd.matches set p1_emote = p_emote, p1_emote_n = p1_emote_n + 1,
      p2_emote = case when p2_bot then 'nice' else p2_emote end, p2_emote_n = case when p2_bot then p2_emote_n + 1 else p2_emote_n end where id = mid;
  else
    update wd.matches set p2_emote = p_emote, p2_emote_n = p2_emote_n + 1 where id = mid;
  end if;
  return jsonb_build_object('ok', true);
end $$;


revoke all on schema wd from public, anon, authenticated;
