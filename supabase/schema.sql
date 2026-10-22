-- 포근길 서버 스키마 (Supabase / Postgres). SQL Editor에서 실행하세요.

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  nickname text not null default '모험가',
  mode text not null default 'walk' check (mode in ('walk','run')),
  created_at timestamptz not null default now()
);

create table crews (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner uuid not null references profiles(id),
  invite_code text not null unique default substr(md5(random()::text), 1, 6),
  created_at timestamptz not null default now()
);

create table crew_members (
  crew_id uuid references crews(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (crew_id, user_id)
);

-- 하루 1행. 걸음, 달리기 거리는 서버에서도 상한을 검증한다.
create table daily_activity (
  user_id uuid references profiles(id) on delete cascade,
  day date not null,
  steps int not null check (steps between 0 and 30000),
  run_km numeric(5,2) not null default 0 check (run_km between 0 and 60),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table profiles enable row level security;
alter table crews enable row level security;
alter table crew_members enable row level security;
alter table daily_activity enable row level security;

create policy "own profile" on profiles for all using (id = auth.uid()) with check (id = auth.uid());
create policy "own activity" on daily_activity for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "crew visible to members" on crews for select using (
  owner = auth.uid() or exists (select 1 from crew_members m where m.crew_id = crews.id and m.user_id = auth.uid())
);
create policy "create own crew" on crews for insert with check (owner = auth.uid());
create policy "see own memberships" on crew_members for select using (user_id = auth.uid());
create policy "add self as member" on crew_members for insert with check (user_id = auth.uid());

-- 초대 코드로 가입
create function join_crew(p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare v_crew uuid;
begin
  select id into v_crew from crews where invite_code = p_code;
  if v_crew is null then raise exception '유효하지 않은 초대 코드입니다'; end if;
  insert into crew_members(crew_id, user_id) values (v_crew, auth.uid()) on conflict do nothing;
end $$;

-- 크루 주간 합산 (멤버만 조회 가능). 레이드 보스 HP 계산에 사용.
create function crew_weekly_totals(p_crew uuid)
returns table (week_start date, steps bigint, run_km numeric, members bigint)
language sql security definer set search_path = public as $$
  select date_trunc('week', a.day)::date, sum(a.steps), sum(a.run_km), count(distinct a.user_id)
  from daily_activity a
  join crew_members m on m.user_id = a.user_id and m.crew_id = p_crew
  where exists (select 1 from crew_members me where me.crew_id = p_crew and me.user_id = auth.uid())
  group by 1 order by 1 desc limit 8;
$$;
