-- Correct transactional throttling: failed RPC calls roll back attempt inserts.
-- Enforce durable successful-join limits instead of claiming failed-attempt tracking.
create or replace function public.join_circle(p_code text) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare c uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 if (select count(*) from public.circle_members
     where user_id=auth.uid() and joined_at>now()-interval '1 hour') >= 5 then
   raise exception 'Circle join limit reached; try later';
 end if;
 select id into c from public.circles where invite_code=upper(trim(p_code));
 if c is null then raise exception 'Circle invitation not found'; end if;
 insert into public.circle_members(circle_id,user_id) values(c,auth.uid()) on conflict do nothing;
end $$;
drop table public.circle_join_attempts;
revoke all on function public.join_circle(text) from public,anon;
grant execute on function public.join_circle(text) to authenticated;
