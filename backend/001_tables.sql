-- Word Duel backend, part 1: tables (private schema "wd", not exposed through the API)
create extension if not exists http with schema extensions;
create schema if not exists wd;

create table wd.words (
  word text primary key,
  len int generated always as (length(word)) stored
);
create table wd.word_edges (
  a text not null,
  b text not null,
  primary key (a, b)
);
create index on wd.word_edges (b);

create table wd.puzzles (
  id serial primary key,
  start_word text not null,
  target_word text not null,
  len int not null,
  dist int not null,
  division int not null
);
create index on wd.puzzles (division);

create table wd.settings (key text primary key, value text);

create table wd.players (
  id uuid primary key default gen_random_uuid(),
  secret text not null default replace(gen_random_uuid()::text, '-', ''),
  name text not null,
  trophies int not null default 0,
  coins int not null default 100,
  wins int not null default 0,
  losses int not null default 0,
  draws int not null default 0,
  streak int not null default 0,
  best_streak int not null default 0,
  season text not null default to_char(now(), 'YYYY-MM'),
  daily_streak int not null default 0,
  last_daily date,
  ad_claims int not null default 0,
  ad_claim_day date,
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now()
);
create index on wd.players (trophies desc);

create table wd.matches (
  id uuid primary key default gen_random_uuid(),
  mode text not null check (mode in ('ranked', 'weekend', 'friendly')),
  room_code text,
  p1 uuid not null references wd.players (id) on delete cascade,
  p2 uuid references wd.players (id) on delete cascade,
  p2_bot boolean not null default false,
  bot_name text,
  bot_trophies int,
  bot_moves int,
  bot_done_at timestamptz,
  base_div int not null,
  division int not null,
  start_word text not null,
  target_word text not null,
  shortest int not null,
  time_limit int not null,
  status text not null default 'waiting' check (status in ('waiting', 'active', 'done')),
  created_at timestamptz not null default now(),
  starts_at timestamptz,
  p1_words text[] not null default '{}',
  p2_words text[] not null default '{}',
  p1_dist int,
  p2_dist int,
  p1_done_at timestamptz,
  p2_done_at timestamptz,
  p1_hints int not null default 0,
  p2_hints int not null default 0,
  p1_doubled boolean not null default false,
  p2_doubled boolean not null default false,
  result text check (result in ('p1', 'p2', 'draw')),
  reason text,
  p1_delta int,
  p2_delta int,
  p1_coins int,
  p2_coins int,
  finished_at timestamptz
);
create index on wd.matches (status, mode, created_at);
create index on wd.matches (p1);
create index on wd.matches (p2);
create index on wd.matches (room_code) where room_code is not null;

create table wd.events (
  id serial primary key,
  title text not null,
  description text not null default '',
  kind text not null check (kind in ('trophy_x', 'coin_x', 'info')),
  multiplier numeric not null default 1,
  starts_at timestamptz not null,
  ends_at timestamptz not null
);

create table wd.daily_scores (
  day date not null,
  player_id uuid not null references wd.players (id) on delete cascade,
  moves int not null,
  seconds numeric not null,
  primary key (day, player_id)
);

alter table wd.words enable row level security;
alter table wd.word_edges enable row level security;
alter table wd.puzzles enable row level security;
alter table wd.settings enable row level security;
alter table wd.players enable row level security;
alter table wd.matches enable row level security;
alter table wd.events enable row level security;
alter table wd.daily_scores enable row level security;

-- Data: loaded from the public GitHub repo
insert into wd.words (word)
select w from unnest(string_to_array(trim((extensions.http_get(
  'https://raw.githubusercontent.com/tolumessi8-sudo/word-duel/main/data/words.txt')).content), E'\n')) as w
where w <> '';

insert into wd.puzzles (start_word, target_word, len, dist, division)
select split_part(l, ',', 1), split_part(l, ',', 2), split_part(l, ',', 3)::int,
       split_part(l, ',', 4)::int, split_part(l, ',', 5)::int
from unnest(string_to_array(trim((extensions.http_get(
  'https://raw.githubusercontent.com/tolumessi8-sudo/word-duel/main/backend/seed/puzzles.csv')).content), E'\n')) with ordinality as t(l, n)
where n > 1 and l <> '';

-- Word graph: two words are neighbours when they differ in exactly one letter
create temp table wb on commit drop as
select w.word, i as pos, overlay(w.word placing '_' from i for 1) as pat
from wd.words w, lateral generate_series(1, w.len) as i;
create index on wb (pos, pat);
insert into wd.word_edges (a, b)
select distinct x.word, y.word from wb x join wb y
  on x.pos = y.pos and x.pat = y.pat and x.word <> y.word;
