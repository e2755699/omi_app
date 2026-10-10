-- 在新建開發專案執行。測試帳號與紀錄全部位於同一交易，結尾 rollback。
-- 不寄信、不建立密碼、不上傳檔案；測試 Supabase 真實資料庫的 Auth FK 與 RLS。
begin;
set local timezone = 'UTC';
select set_config('omi.test.alice', gen_random_uuid()::text, true);
select set_config('omi.test.bob', gen_random_uuid()::text, true);
select set_config('omi.test.eve', gen_random_uuid()::text, true);
insert into auth.users(id) values
  (current_setting('omi.test.alice')::uuid),
  (current_setting('omi.test.bob')::uuid),
  (current_setting('omi.test.eve')::uuid);

set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('omi.test.alice'), true);
select set_config('omi.test.group', public.create_challenge_group(
  'Omi rollback test', current_date-2, current_date+20, current_date-2,
  array['produce','water'], 'UTC')::text, true);
select set_config('omi.test.invite', public.rotate_group_invite(current_setting('omi.test.group')::uuid), true);
insert into public.profiles(user_id, display_name) values(auth.uid(), 'Test Alice');
insert into public.personal_settings(group_id,user_id,weight_kg)
  values(current_setting('omi.test.group')::uuid, auth.uid(), 60);
insert into public.reflections(group_id,user_id,period_date,item_id,answers)
  values(current_setting('omi.test.group')::uuid, auth.uid(), current_date, 'noticed', array['private test']);
insert into public.checkins(group_id,user_id,period_date,item_id,amount)
  values(current_setting('omi.test.group')::uuid, auth.uid(), current_date, 'reading', 1);
update public.checkins set amount=0,version=1
  where group_id=current_setting('omi.test.group')::uuid and item_id='reading';
do $$ begin
  if not exists(select 1 from public.checkins where group_id=current_setting('omi.test.group')::uuid
      and item_id='noticed' and amount=1) then raise exception 'FAIL reflection projection'; end if;
  begin
    update public.checkins set amount=1,version=1 where group_id=current_setting('omi.test.group')::uuid and item_id='reading';
    raise exception 'FAIL stale version accepted';
  exception when serialization_failure then null; end;
end $$;

select set_config('request.jwt.claim.sub', current_setting('omi.test.bob'), true);
select public.join_challenge_group(current_setting('omi.test.invite'),current_date-2,array['produce','water']);
do $$ begin
  if (select count(*) from public.checkins where group_id=current_setting('omi.test.group')::uuid) <> 2 then
    raise exception 'FAIL peer cannot see checkins'; end if;
  if exists(select 1 from public.reflections where group_id=current_setting('omi.test.group')::uuid) then
    raise exception 'FAIL peer sees private reflections'; end if;
  if exists(select 1 from public.personal_settings where group_id=current_setting('omi.test.group')::uuid) then
    raise exception 'FAIL peer sees private settings'; end if;
  begin
    perform * from private.group_invites;
    raise exception 'FAIL invite hashes exposed';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.checkins(group_id,user_id,period_date,item_id,amount)
      values(current_setting('omi.test.group')::uuid,current_setting('omi.test.alice')::uuid,current_date,'sleep',1);
    raise exception 'FAIL can impersonate another user';
  exception when insufficient_privilege then null; end;
end $$;
select public.send_cheer(current_setting('omi.test.group')::uuid,current_setting('omi.test.alice')::uuid,'cheer');
select public.send_cheer(current_setting('omi.test.group')::uuid,current_setting('omi.test.alice')::uuid,'cheer');
do $$ begin
  if (select count(*) from public.cheers where group_id=current_setting('omi.test.group')::uuid) <> 1 then
    raise exception 'FAIL cheer retry duplicated'; end if;
end $$;
select public.leave_challenge_group(current_setting('omi.test.group')::uuid);
do $$ begin
  if exists(select 1 from public.checkins where group_id=current_setting('omi.test.group')::uuid) then
    raise exception 'FAIL former member sees peer data'; end if;
end $$;

select set_config('request.jwt.claim.sub', current_setting('omi.test.eve'), true);
do $$ begin
  if exists(select 1 from public.checkins where group_id=current_setting('omi.test.group')::uuid) then
    raise exception 'FAIL unrelated user sees checkins'; end if;
  begin
    perform public.rotate_group_invite(current_setting('omi.test.group')::uuid);
    raise exception 'FAIL unrelated user can rotate invite';
  exception when insufficient_privilege then null; end;
end $$;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
  begin
    perform * from public.profiles;
    raise exception 'FAIL anonymous user can read profiles';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
select 'PASS: cloud transaction smoke tests; all fixtures rolled back' as result;
