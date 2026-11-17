-- Additional hardening + optional push token storage.
create or replace function public.is_circle_member(p_circle uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.circle_members where circle_id=p_circle and user_id=auth.uid());
$$;
revoke all on function public.is_circle_member(uuid) from public;
grant execute on function public.is_circle_member(uuid) to authenticated;
drop policy if exists circle_read on public.circles;
drop policy if exists circle_members_read on public.circle_members;
create policy circle_read on public.circles for select to authenticated using (public.is_circle_member(id));
create policy circle_members_read on public.circle_members for select to authenticated using (public.is_circle_member(circle_id));

create table public.device_tokens (
 user_id uuid not null references auth.users(id) on delete cascade,
 token text not null check(length(token) between 20 and 2000),
 updated_at timestamptz not null default now(),
 primary key(user_id,token)
);
alter table public.device_tokens enable row level security;
create policy token_select on public.device_tokens for select to authenticated using(user_id=auth.uid());
create policy token_insert on public.device_tokens for insert to authenticated with check(user_id=auth.uid());
create policy token_update on public.device_tokens for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy token_delete on public.device_tokens for delete to authenticated using(user_id=auth.uid());
-- Follow README to configure a secured database webhook to send-push.

-- Tighten visibility: profile fields are non-sensitive, no auth email or GPS in public profiles.
-- Include Realtime publication for the messages stream (idempotent for repeat installs).
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then
  alter publication supabase_realtime add table public.messages;
 end if;
end $$;
