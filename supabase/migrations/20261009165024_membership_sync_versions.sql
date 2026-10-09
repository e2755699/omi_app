begin;
alter table public.memberships add column version bigint not null default 1;
alter table public.memberships add column updated_at timestamptz not null default now();
create trigger version_before_write before insert or update on public.memberships
  for each row execute function private.bump_version();

create function private.validate_enrollment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare g public.challenge_groups;
begin
  select * into g from public.challenge_groups where id = new.group_id;
  if new.starts_on < g.starts_on or new.starts_on > g.ends_on
    or (old.starts_on <= (now() at time zone g.timezone)::date and new.starts_on <> old.starts_on) then
    raise exception '不能變更開跑日' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.validate_enrollment() from public, anon, authenticated;
create trigger enrollment_before_update before update on public.memberships
  for each row execute function private.validate_enrollment();
grant update(starts_on, nourish_choice, version) on public.memberships to authenticated;
create policy memberships_update_self on public.memberships for update to authenticated
  using (user_id = (select auth.uid()) and active)
  with check (user_id = (select auth.uid()) and active);
commit;
