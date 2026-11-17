-- Reach zero-cost trust controls for chat and invitations.
-- Database enforcement is independent of the Android client.
create or replace function public.guard_message_trust() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare account_age interval;
begin
 if not public.reach_account_eligible(auth.uid(), interval '10 minutes') then
   raise exception 'Confirm your email before messaging';
 end if;
 select now()-created_at into account_age from auth.users where id=auth.uid();
 if account_age < interval '24 hours'
    and new.body ~* '(https?://|www[.]|t[.]me/|wa[.]me/|bit[.]ly/|tinyurl[.]com/)' then
   raise exception 'New accounts cannot send links during the first 24 hours';
 end if;
 if (select count(*) from public.messages
     where sender_id=auth.uid() and created_at>now()-interval '1 minute') >= 12 then
   raise exception 'Message rate limit reached; please wait';
 end if;
 if (select count(*) from public.messages
     where sender_id=auth.uid() and created_at>now()-interval '1 hour') >= 120 then
   raise exception 'Hourly message limit reached; please try later';
 end if;
 if exists(select 1 from public.messages
     where sender_id=auth.uid() and body= new.body
       and created_at>now()-interval '3 minutes') then
   raise exception 'Repeated identical messages are temporarily restricted';
 end if;
 return new;
end $$;
create trigger message_trust before insert on public.messages
 for each row execute function public.guard_message_trust();
revoke all on function public.guard_message_trust() from public,anon,authenticated;

-- Reduce automated circle-invite enumeration by limiting join attempts.
create table public.circle_join_attempts (
 user_id uuid not null references auth.users(id) on delete cascade,
 attempted_at timestamptz not null default now()
);
create index circle_join_attempts_idx on public.circle_join_attempts(user_id,attempted_at desc);
alter table public.circle_join_attempts enable row level security;
revoke all on public.circle_join_attempts from anon,authenticated;
create or replace function public.join_circle(p_code text) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare c uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 if (select count(*) from public.circle_join_attempts
     where user_id=auth.uid() and attempted_at>now()-interval '1 hour') >= 10 then
   raise exception 'Too many circle join attempts; try again later';
 end if;
 insert into public.circle_join_attempts(user_id) values(auth.uid());
 select id into c from public.circles where invite_code=upper(trim(p_code));
 if c is null then raise exception 'Circle invitation not found'; end if;
 insert into public.circle_members(circle_id,user_id) values(c,auth.uid()) on conflict do nothing;
end $$;
revoke all on function public.join_circle(text) from public,anon;
grant execute on function public.join_circle(text) to authenticated;
