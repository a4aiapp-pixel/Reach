-- Reach anti-abuse baseline: server-side controls, no paid SMS dependency.
-- New accounts must mature before posting or contacting others.
create or replace function public.reach_account_eligible(p_user uuid, p_wait interval)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(
  select 1 from auth.users u join public.profiles p on p.id=u.id
  where u.id=p_user and u.email_confirmed_at is not null
    and u.created_at <= now()-p_wait and not p.suspended
    and p.terms_accepted_at is not null
 );
$$;
revoke all on function public.reach_account_eligible(uuid,interval) from public,anon,authenticated;

create or replace function public.guard_reach_abuse() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.reach_account_eligible(auth.uid(),interval '10 minutes') then
   raise exception 'Confirm your email and wait 10 minutes before publishing';
 end if;
 if exists(select 1 from public.reaches where owner_id=auth.uid()
   and created_at>now()-interval '2 minutes') then
   raise exception 'Please wait before publishing another availability';
 end if;
 return new;
end $$;
create trigger reach_abuse before insert on public.reaches
 for each row execute function public.guard_reach_abuse();

create or replace function public.guard_connection_abuse() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.reach_account_eligible(auth.uid(),interval '10 minutes') then
   raise exception 'Confirm your email and wait 10 minutes before contacting others';
 end if;
 if (select count(*) from public.connection_requests
     where sender_id=auth.uid() and created_at>now()-interval '1 hour') >= 15 then
   raise exception 'Connection request limit reached. Try later';
 end if;
 if exists(select 1 from public.connection_requests
     where sender_id=auth.uid() and created_at>now()-interval '30 seconds') then
   raise exception 'Please wait before sending another connection request';
 end if;
 return new;
end $$;
create trigger connection_abuse before insert on public.connection_requests
 for each row execute function public.guard_connection_abuse();

create or replace function public.guard_report_abuse() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.reporter_id<>auth.uid() then raise exception 'Invalid reporter'; end if;
 if (select count(*) from public.reports
    where reporter_id=auth.uid() and created_at>now()-interval '1 hour') >= 10 then
   raise exception 'Report limit reached. Try again later';
 end if;
 if exists(select 1 from public.reports
    where reporter_id=auth.uid() and target_type=new.target_type
    and target_id=new.target_id and created_at>now()-interval '24 hours') then
   raise exception 'You have already reported this item';
 end if;
 return new;
end $$;
create trigger report_abuse before insert on public.reports
 for each row execute function public.guard_report_abuse();

revoke all on function public.guard_reach_abuse(),public.guard_connection_abuse(),
 public.guard_report_abuse() from public,anon,authenticated;
