-- API 包裝只使用呼叫者權限；需要特權的實作置於未暴露的 private schema。
begin;
alter function public.create_challenge_group(text, date, date, date, text[], text) set schema private;
alter function public.rotate_group_invite(uuid) set schema private;
alter function public.join_challenge_group(text, date, text[]) set schema private;
alter function public.update_enrollment(uuid, date, text[]) set schema private;
alter function public.leave_challenge_group(uuid) set schema private;
alter function public.send_cheer(uuid, uuid, text) set schema private;

create function public.create_challenge_group(p_name text, p_starts_on date, p_ends_on date,
  p_personal_start date, p_nourish text[], p_timezone text default 'Asia/Taipei') returns uuid
language sql security invoker set search_path = '' as $$
  select private.create_challenge_group(p_name, p_starts_on, p_ends_on, p_personal_start, p_nourish, p_timezone);
$$;
create function public.rotate_group_invite(p_group_id uuid) returns text
language sql security invoker set search_path = '' as $$ select private.rotate_group_invite(p_group_id); $$;
create function public.join_challenge_group(p_token text, p_starts_on date, p_nourish text[]) returns uuid
language sql security invoker set search_path = '' as $$ select private.join_challenge_group(p_token, p_starts_on, p_nourish); $$;
create function public.update_enrollment(p_group_id uuid, p_starts_on date, p_nourish text[]) returns void
language sql security invoker set search_path = '' as $$ select private.update_enrollment(p_group_id, p_starts_on, p_nourish); $$;
create function public.leave_challenge_group(p_group_id uuid) returns void
language sql security invoker set search_path = '' as $$ select private.leave_challenge_group(p_group_id); $$;
create function public.send_cheer(p_group_id uuid, p_to_user_id uuid, p_kind text) returns void
language sql security invoker set search_path = '' as $$ select private.send_cheer(p_group_id, p_to_user_id, p_kind); $$;

revoke all on function public.create_challenge_group(text, date, date, date, text[], text),
  public.rotate_group_invite(uuid), public.join_challenge_group(text, date, text[]),
  public.update_enrollment(uuid, date, text[]), public.leave_challenge_group(uuid),
  public.send_cheer(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.create_challenge_group(text, date, date, date, text[], text),
  public.rotate_group_invite(uuid), public.join_challenge_group(text, date, text[]),
  public.update_enrollment(uuid, date, text[]), public.leave_challenge_group(uuid),
  public.send_cheer(uuid, uuid, text) to authenticated;

-- 即使未來有人誤授予 table grant，仍明確拒絕直接讀取邀請碼雜湊。
create policy invites_no_direct_access on private.group_invites as restrictive
  for all to authenticated using (false) with check (false);
commit;
