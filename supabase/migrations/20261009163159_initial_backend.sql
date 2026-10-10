-- Omi 第一版後端：群組隔離、私人心得、照片與加油。
-- 透過 migration 套用在專用的新 Supabase 專案；不要在既有資料庫直接重跑。
begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 60),
  avatar text not null default '😀' check (char_length(avatar) between 1 and 32),
  version bigint not null default 1,
  updated_at timestamptz not null default now()
);

create table public.challenge_groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  name text not null check (char_length(btrim(name)) between 1 and 100),
  starts_on date not null,
  ends_on date not null,
  timezone text not null default 'Asia/Taipei',
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

create table public.memberships (
  group_id uuid not null references public.challenge_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  starts_on date not null,
  nourish_choice text[] not null,
  active boolean not null default true,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id),
  check (nourish_choice <@ array['produce', 'protein', 'water']::text[]),
  check (array_position(nourish_choice, null) is null),
  check (cardinality(nourish_choice) between 2 and 3),
  check ((case when 'produce' = any(nourish_choice) then 1 else 0 end
        + case when 'protein' = any(nourish_choice) then 1 else 0 end
        + case when 'water' = any(nourish_choice) then 1 else 0 end) = cardinality(nourish_choice))
);
create index memberships_by_user on public.memberships(user_id, group_id) where active;
create index memberships_user_fk on public.memberships(user_id);
create index groups_owner_fk on public.challenge_groups(owner_id);

create table public.personal_settings (
  group_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  weight_kg numeric check (weight_kg > 0 and weight_kg <= 500),
  bedtime integer check (bedtime between 0 and 1439),
  wake_time integer check (wake_time between 0 and 1439),
  book text not null default '' check (char_length(book) <= 1000),
  week1_move text not null default '' check (char_length(week1_move) <= 5000),
  week1_obstacle text not null default '' check (char_length(week1_obstacle) <= 5000),
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  primary key (group_id, user_id),
  foreign key (group_id, user_id) references public.memberships(group_id, user_id) on delete cascade
);

create table public.checkins (
  group_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  period_date date not null,
  item_id text not null check (item_id in (
    'aerobic', 'strength', 'alcohol', 'produce', 'protein', 'water',
    'reading', 'sleep', 'schedule', 'noticed', 'review', 'photo')),
  amount integer not null default 0 check (amount >= 0),
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  primary key (group_id, user_id, period_date, item_id),
  foreign key (group_id, user_id) references public.memberships(group_id, user_id) on delete cascade,
  check (amount <= case item_id when 'aerobic' then 1440 when 'strength' then 100
      when 'review' then 3 else 1 end)
);

create table public.reflections (
  group_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  period_date date not null,
  item_id text not null check (item_id in ('noticed', 'review')),
  answers text[] not null,
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  primary key (group_id, user_id, period_date, item_id),
  foreign key (group_id, user_id) references public.memberships(group_id, user_id) on delete cascade,
  check (cardinality(answers) = case item_id when 'noticed' then 1 else 3 end),
  check (array_position(answers, null) is null),
  check (octet_length(answers::text) <= 60000)
);

create table public.weekly_photos (
  group_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  period_date date not null,
  object_path text,
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  primary key (group_id, user_id, period_date),
  unique (object_path),
  foreign key (group_id, user_id) references public.memberships(group_id, user_id) on delete cascade,
  check (object_path is null or (
    split_part(object_path, '/', 1) = group_id::text and
    split_part(object_path, '/', 2) = user_id::text and
    split_part(object_path, '/', 3) = period_date::text and
    object_path ~ '^[^/]+/[^/]+/[0-9]{4}-[0-9]{2}-[0-9]{2}/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$'))
);

create table public.cheers (
  group_id uuid not null,
  from_user_id uuid not null references auth.users(id) on delete cascade,
  to_user_id uuid not null references auth.users(id) on delete cascade,
  cheer_date date not null,
  kind text not null check (kind in ('cheer', 'celebrate')),
  created_at timestamptz not null default now(),
  primary key (group_id, from_user_id, to_user_id, cheer_date),
  foreign key (group_id, from_user_id) references public.memberships(group_id, user_id) on delete cascade,
  foreign key (group_id, to_user_id) references public.memberships(group_id, user_id) on delete cascade,
  check (from_user_id <> to_user_id)
);
create index cheers_received on public.cheers(group_id, to_user_id, cheer_date);
create index cheers_sender_fk on public.cheers(from_user_id);
create index cheers_recipient_fk on public.cheers(to_user_id);
create index settings_user_fk on public.personal_settings(user_id);
create index checkins_user_fk on public.checkins(user_id);
create index reflections_user_fk on public.reflections(user_id);
create index photos_user_fk on public.weekly_photos(user_id);

create table private.group_invites (
  group_id uuid primary key references public.challenge_groups(id) on delete cascade,
  token_hash bytea not null unique,
  expires_at timestamptz not null
);
alter table private.group_invites enable row level security;

-- Helper 只判斷呼叫者，不接受可冒充的 viewer_id；固定 search_path 避免物件置換。
create function private.is_member(g uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.memberships
    where group_id = g and user_id = (select auth.uid()) and active);
$$;

create function private.can_read_member(g uuid, target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) = target or (
    private.is_member(g) and exists(select 1 from public.memberships
      where group_id = g and user_id = target and active));
$$;

create function private.is_peer(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) = target or exists(
    select 1 from public.memberships a join public.memberships b using (group_id)
    where a.user_id = (select auth.uid()) and b.user_id = target and a.active and b.active);
$$;

-- 更新需攜帶之前讀到的 version；伺服器負責下一個版本與時間。
create function private.bump_version() returns trigger
language plpgsql set search_path = '' as $$
begin
  if TG_OP = 'UPDATE' and new.version is distinct from old.version then
    raise exception '資料已在另一裝置更新，請重新讀取' using errcode = '40001';
  end if;
  new.version := case when TG_OP = 'INSERT' then 1 else old.version + 1 end;
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

create function private.validate_period() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  first_day date;
  last_day date;
  today date;
  weekly boolean;
begin
  select m.starts_on, g.ends_on, (now() at time zone g.timezone)::date
    into first_day, last_day, today
    from public.memberships m join public.challenge_groups g on g.id = m.group_id
    where m.group_id = new.group_id and m.user_id = new.user_id and m.active;
  if not found then raise exception '不是目前成員' using errcode = '42501'; end if;
  if TG_TABLE_NAME = 'weekly_photos' then weekly := true;
  else weekly := new.item_id in ('review', 'photo'); end if;
  if weekly then
    if extract(isodow from new.period_date) <> 1 or new.period_date + 6 < first_day
      or new.period_date > last_day or greatest(new.period_date, first_day) > today then
      raise exception '週次不在可記錄期間' using errcode = '23514';
    end if;
  elsif new.period_date < first_day or new.period_date > last_day or new.period_date > today then
    raise exception '日期不在可記錄期間' using errcode = '23514';
  end if;
  return new;
end;
$$;

-- 共享表只有完成數量；不複製心得、回答或照片路徑。
create function private.sync_reflection_status() returns trigger
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  select count(*) into n from unnest(new.answers) a where btrim(a) <> '';
  insert into public.checkins(group_id, user_id, period_date, item_id, amount)
    values(new.group_id, new.user_id, new.period_date, new.item_id, n)
    on conflict(group_id, user_id, period_date, item_id) do update set amount = excluded.amount;
  return new;
end;
$$;

create function private.sync_photo_status() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.object_path is not null and not exists(
    select 1 from storage.objects where bucket_id = 'weekly-photos' and name = new.object_path
  ) then raise exception '請先上傳照片' using errcode = '23514'; end if;
  insert into public.checkins(group_id, user_id, period_date, item_id, amount)
    values(new.group_id, new.user_id, new.period_date, 'photo', case when new.object_path is null then 0 else 1 end)
    on conflict(group_id, user_id, period_date, item_id) do update set amount = excluded.amount;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['profiles', 'challenge_groups', 'memberships', 'personal_settings',
      'checkins', 'reflections', 'weekly_photos', 'cheers'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  foreach t in array array['profiles', 'personal_settings', 'checkins', 'reflections', 'weekly_photos'] loop
    execute format('create trigger version_before_write before insert or update on public.%I
      for each row execute function private.bump_version()', t);
  end loop;
  foreach t in array array['checkins', 'reflections', 'weekly_photos'] loop
    execute format('create trigger period_before_write before insert or update on public.%I
      for each row execute function private.validate_period()', t);
  end loop;
end;
$$;
create trigger reflection_after_write after insert or update on public.reflections
  for each row execute function private.sync_reflection_status();
create trigger photo_after_write after insert or update on public.weekly_photos
  for each row execute function private.sync_photo_status();

grant insert (user_id, display_name, avatar) on public.profiles to authenticated;
grant update (display_name, avatar, version) on public.profiles to authenticated;
grant insert (group_id, user_id, weight_kg, bedtime, wake_time, book, week1_move, week1_obstacle)
  on public.personal_settings to authenticated;
grant update (weight_kg, bedtime, wake_time, book, week1_move, week1_obstacle, version)
  on public.personal_settings to authenticated;
grant insert (group_id, user_id, period_date, item_id, amount) on public.checkins to authenticated;
grant update (amount, version) on public.checkins to authenticated;
grant insert (group_id, user_id, period_date, item_id, answers) on public.reflections to authenticated;
grant update (answers, version) on public.reflections to authenticated;
grant insert (group_id, user_id, period_date, object_path) on public.weekly_photos to authenticated;
grant update (object_path, version) on public.weekly_photos to authenticated;

create policy profiles_read on public.profiles for select to authenticated using (private.is_peer(user_id));
create policy profiles_insert on public.profiles for insert to authenticated with check (user_id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy groups_read on public.challenge_groups for select to authenticated
  using (private.is_member(id) or owner_id = (select auth.uid()));
create policy members_read on public.memberships for select to authenticated
  using (private.can_read_member(group_id, user_id));

create policy settings_read on public.personal_settings for select to authenticated using (user_id = (select auth.uid()));
create policy settings_insert on public.personal_settings for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_member(group_id));
create policy settings_update on public.personal_settings for update to authenticated
  using (user_id = (select auth.uid()) and private.is_member(group_id))
  with check (user_id = (select auth.uid()) and private.is_member(group_id));

create policy checkins_read on public.checkins for select to authenticated
  using (private.can_read_member(group_id, user_id));
create policy checkins_insert on public.checkins for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_member(group_id)
    and item_id not in ('noticed', 'review', 'photo'));
create policy checkins_update on public.checkins for update to authenticated
  using (user_id = (select auth.uid()) and private.is_member(group_id)
    and item_id not in ('noticed', 'review', 'photo'))
  with check (user_id = (select auth.uid()) and private.is_member(group_id)
    and item_id not in ('noticed', 'review', 'photo'));

create policy reflections_read on public.reflections for select to authenticated using (user_id = (select auth.uid()));
create policy reflections_insert on public.reflections for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_member(group_id));
create policy reflections_update on public.reflections for update to authenticated
  using (user_id = (select auth.uid()) and private.is_member(group_id))
  with check (user_id = (select auth.uid()) and private.is_member(group_id));

create policy photos_read on public.weekly_photos for select to authenticated using (private.can_read_member(group_id, user_id));
create policy photos_insert on public.weekly_photos for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_member(group_id));
create policy photos_update on public.weekly_photos for update to authenticated
  using (user_id = (select auth.uid()) and private.is_member(group_id))
  with check (user_id = (select auth.uid()) and private.is_member(group_id));
create policy cheers_read on public.cheers for select to authenticated using (private.is_member(group_id));

-- 邀請碼只有雜湊留在私有表；原碼只回傳給建立者一次，有效期七天。
create function public.rotate_group_invite(p_group_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare token text := replace(gen_random_uuid()::text, '-', '');
begin
  if not exists(select 1 from public.challenge_groups where id = p_group_id and owner_id = auth.uid()) then
    raise exception '只有建立者可以建立邀請' using errcode = '42501';
  end if;
  insert into private.group_invites(group_id, token_hash, expires_at)
    values(p_group_id, sha256(convert_to(token, 'UTF8')), now() + interval '7 days')
    on conflict(group_id) do update set token_hash = excluded.token_hash, expires_at = excluded.expires_at;
  return token;
end;
$$;

create function public.create_challenge_group(p_name text, p_starts_on date, p_ends_on date,
    p_personal_start date, p_nourish text[], p_timezone text default 'Asia/Taipei')
returns uuid language plpgsql security definer set search_path = '' as $$
declare g uuid;
begin
  if auth.uid() is null then raise exception '請先登入' using errcode = '42501'; end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names where name = p_timezone) then
    raise exception '無效時區' using errcode = '23514';
  end if;
  if p_personal_start is null or p_personal_start < p_starts_on or p_personal_start > p_ends_on then
    raise exception '開跑日不在挑戰期間' using errcode = '23514';
  end if;
  insert into public.challenge_groups(owner_id, name, starts_on, ends_on, timezone)
    values(auth.uid(), p_name, p_starts_on, p_ends_on, p_timezone) returning id into g;
  insert into public.memberships(group_id, user_id, starts_on, nourish_choice)
    values(g, auth.uid(), p_personal_start, p_nourish);
  return g;
end;
$$;

create function public.join_challenge_group(p_token text, p_starts_on date, p_nourish text[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare g public.challenge_groups;
begin
  if auth.uid() is null then raise exception '請先登入' using errcode = '42501'; end if;
  select c.* into g from public.challenge_groups c join private.group_invites i on i.group_id = c.id
    where i.token_hash = sha256(convert_to(p_token, 'UTF8')) and i.expires_at > now();
  if not found then raise exception '邀請無效或已過期' using errcode = '42501'; end if;
  if p_starts_on is null or p_starts_on < g.starts_on or p_starts_on > g.ends_on then
    raise exception '開跑日不在挑戰期間' using errcode = '23514';
  end if;
  insert into public.memberships(group_id, user_id, starts_on, nourish_choice)
    values(g.id, auth.uid(), p_starts_on, p_nourish)
    on conflict(group_id, user_id) do update set active = true;
  return g.id;
end;
$$;

create function public.update_enrollment(p_group_id uuid, p_starts_on date, p_nourish text[])
returns void language plpgsql security definer set search_path = '' as $$
declare m public.memberships; g public.challenge_groups;
begin
  select * into m from public.memberships where group_id = p_group_id and user_id = auth.uid() and active for update;
  if not found then raise exception '不是目前成員' using errcode = '42501'; end if;
  select * into g from public.challenge_groups where id = p_group_id;
  if p_starts_on is null or p_starts_on < g.starts_on or p_starts_on > g.ends_on
    or (m.starts_on <= (now() at time zone g.timezone)::date and m.starts_on <> p_starts_on) then
    raise exception '不能變更開跑日' using errcode = '23514';
  end if;
  update public.memberships set starts_on = p_starts_on, nourish_choice = p_nourish
    where group_id = p_group_id and user_id = auth.uid();
end;
$$;

create function public.leave_challenge_group(p_group_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.memberships set active = false where group_id = p_group_id and user_id = auth.uid();
end;
$$;

create function public.send_cheer(p_group_id uuid, p_to_user_id uuid, p_kind text) returns void
language plpgsql security definer set search_path = '' as $$
declare today date; last_day date;
begin
  if not private.is_member(p_group_id) or p_to_user_id = auth.uid() then
    raise exception '只能幫同組其他成員加油' using errcode = '42501';
  end if;
  select (now() at time zone timezone)::date, ends_on into today, last_day
    from public.challenge_groups where id = p_group_id;
  if today > last_day or not exists(select 1 from public.memberships
    where group_id = p_group_id and user_id = p_to_user_id and active and starts_on <= today)
    or not exists(select 1 from public.memberships where group_id = p_group_id
      and user_id = auth.uid() and starts_on <= today) then
    raise exception '目前不能加油' using errcode = '42501';
  end if;
  insert into public.cheers(group_id, from_user_id, to_user_id, cheer_date, kind)
    values(p_group_id, auth.uid(), p_to_user_id, today, p_kind)
    on conflict(group_id, from_user_id, to_user_id, cheer_date) do nothing;
end;
$$;

-- 函數預設 PUBLIC 可執行；逐一收回，再僅授權 App 所需的 RPC。
revoke all on all tables in schema private from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.is_member(uuid), private.can_read_member(uuid, uuid), private.is_peer(uuid) to authenticated;
revoke all on function public.create_challenge_group(text, date, date, date, text[], text),
  public.rotate_group_invite(uuid), public.join_challenge_group(text, date, text[]),
  public.update_enrollment(uuid, date, text[]), public.leave_challenge_group(uuid),
  public.send_cheer(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.create_challenge_group(text, date, date, date, text[], text),
  public.rotate_group_invite(uuid), public.join_challenge_group(text, date, text[]),
  public.update_enrollment(uuid, date, text[]), public.leave_challenge_group(uuid),
  public.send_cheer(uuid, uuid, text) to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
  values('weekly-photos', 'weekly-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']);

create policy omi_photo_read on storage.objects for select to authenticated using (
  bucket_id = 'weekly-photos' and exists(
    select 1 from public.weekly_photos p where p.object_path = name
      and private.can_read_member(p.group_id, p.user_id))
);
create policy omi_photo_upload on storage.objects for insert to authenticated with check (
  bucket_id = 'weekly-photos' and split_part(name, '/', 2) = (select auth.uid())::text
  and exists(select 1 from public.memberships m where m.group_id::text = split_part(name, '/', 1)
    and m.user_id = (select auth.uid()) and m.active)
);
-- 每次換照片用新檔名，不提供 overwrite。刪除前先清空或換掉 metadata。
create policy omi_photo_owner_cleanup_read on storage.objects for select to authenticated using (
  bucket_id = 'weekly-photos' and split_part(name, '/', 2) = (select auth.uid())::text
);
create policy omi_photo_delete on storage.objects for delete to authenticated using (
  bucket_id = 'weekly-photos' and split_part(name, '/', 2) = (select auth.uid())::text
  and not exists(select 1 from public.weekly_photos p where p.object_path = name)
);

commit;
