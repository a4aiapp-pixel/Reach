-- Reach 1.0: hosted PostgreSQL schema, privacy rules and discovery.
-- Run once in a NEW Supabase SQL Editor project; install + audit before production.
create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '', bio text not null default '',
  city text not null default '', country text not null default '',
  skills text[] not null default '{}', notify_on boolean not null default true,
  terms_accepted_at timestamptz, location_opt_in boolean not null default false,
  suspended boolean not null default false,
  created_at timestamptz not null default now(),
  constraint profile_name_len check(char_length(display_name) <= 80),
  constraint bio_len check(char_length(bio) <= 500),
  constraint city_len check(char_length(city) <= 100),
  constraint country_len check(char_length(country) <= 100),
  constraint skill_count check(cardinality(skills) <= 20)
);
create or replace function public.handle_new_user() returns trigger language plpgsql
security definer set search_path = public, pg_temp as $$
begin
 insert into public.profiles (id,display_name)
 values (new.id,left(coalesce(new.raw_user_meta_data->>'display_name',''),80))
 on conflict (id) do nothing;
 return new;
end $$;
create trigger auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- Stored coordinates are rounded in the client; exposed only through coarse-distance matching.
create table public.approx_locations (
  user_id uuid primary key references auth.users(id) on delete cascade,
  lat numeric(4,1) not null check(lat between -90 and 90),
  lon numeric(4,1) not null check(lon between -180 and 180),
  updated_at timestamptz not null default now()
);

create table public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null check(length(btrim(name)) between 3 and 70),
  invite_code text not null unique,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table public.circle_members (
  circle_id uuid not null references public.circles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(circle_id,user_id)
);
create table public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id,blocked_id),
  constraint not_self_block check(blocker_id <> blocked_id)
);

create or replace function public.blocked_pair(a uuid, b uuid) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists (select 1 from public.blocks where
 (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a));
$$;
revoke all on function public.blocked_pair(uuid,uuid) from public;
grant execute on function public.blocked_pair(uuid,uuid) to authenticated;

create table public.reaches (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check(kind in ('offer','request')),
  title text not null check(length(btrim(title)) between 8 and 110),
  detail text not null default '' check(length(detail) <= 1500),
  category text not null default 'Other' check(length(category) <= 40),
  city text not null default '', country text not null default '',
  scope text not null default 'public' check(scope in ('public','circle')),
  circle_id uuid references public.circles(id) on delete cascade,
  status text not null default 'open' check(status in ('open','closed')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  constraint circle_scope check((scope='public' and circle_id is null) or (scope='circle' and circle_id is not null))
);
create index reaches_discovery_idx on public.reaches(country,city,expires_at desc)
 where status = 'open';
create index reaches_owner_idx on public.reaches(owner_id,created_at desc);
create index reaches_circle_idx on public.reaches(circle_id,created_at desc);

create or replace function public.guard_reach() returns trigger language plpgsql
security definer set search_path=public,pg_temp as $$
declare p public.profiles;
begin
 if TG_OP = 'INSERT' then
   if new.owner_id <> auth.uid() then raise exception 'You can only post as yourself'; end if;
   select * into p from public.profiles where id = auth.uid();
   if p.suspended or p.terms_accepted_at is null then raise exception 'Complete your profile and accept the rules'; end if;
   if length(btrim(p.city))=0 or length(btrim(p.country))=0 then raise exception 'Set your city and country first'; end if;
   if new.expires_at <= now() or new.expires_at > now()+interval '7 days 1 minute' then
     raise exception 'Invalid availability window'; end if;
   if (select count(*) from public.reaches where owner_id=auth.uid() and status='open' and expires_at>now()) >= 10 then
     raise exception 'Close an existing availability before adding another'; end if;
   if new.circle_id is not null and not exists(select 1 from public.circle_members
     where circle_id=new.circle_id and user_id=auth.uid()) then raise exception 'Not a member of this circle'; end if;
   new.city := p.city; new.country := p.country;
 else
   if new.owner_id<>old.owner_id or new.title<>old.title or new.detail<>old.detail or
      new.kind<>old.kind or new.category<>old.category or new.city<>old.city or
      new.country<>old.country or new.scope<>old.scope or
      new.circle_id is distinct from old.circle_id or new.expires_at<>old.expires_at then
     raise exception 'A posted reach is immutable; close it and create a new one';
   end if;
 end if;
 return new;
end $$;
create trigger guard_reaches before insert or update on public.reaches
for each row execute function public.guard_reach();

create table public.connection_requests (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.reaches(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message text not null check(length(btrim(message)) between 2 and 400),
  status text not null default 'pending' check(status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  unique(post_id,sender_id)
);
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.reaches(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  peer_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(post_id,peer_id)
);
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check(length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index messages_chat_time on public.messages(conversation_id, created_at);

create table public.alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null, body text not null default '',
  related_id uuid, read_at timestamptz,
  created_at timestamptz not null default now()
);
create index alerts_user on public.alerts(user_id,created_at desc);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null check(target_type in ('post','user','message')),
  target_id uuid not null,
  reason text not null check(reason in ('spam','harassment','unsafe','fraud','other')),
  detail text not null default '' check(length(detail) <= 1000),
  status text not null default 'open' check(status in ('open','reviewing','resolved')),
  created_at timestamptz not null default now()
);

-- RLS across every public table; report queue is NOT readable by regular users.
alter table public.profiles enable row level security;
alter table public.approx_locations enable row level security;
alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.blocks enable row level security;
alter table public.reaches enable row level security;
alter table public.connection_requests enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.alerts enable row level security;
alter table public.reports enable row level security;

create policy profile_read on public.profiles for select to authenticated using (true);
create policy profile_update on public.profiles for update to authenticated using (id=auth.uid()) with check(id=auth.uid());
revoke update on public.profiles from authenticated;
grant update(display_name,bio,city,country,skills,notify_on,terms_accepted_at,location_opt_in)
  on public.profiles to authenticated;

create policy loc_select on public.approx_locations for select to authenticated using(user_id=auth.uid());
create policy loc_insert on public.approx_locations for insert to authenticated with check(user_id=auth.uid());
create policy loc_update on public.approx_locations for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy loc_delete on public.approx_locations for delete to authenticated using(user_id=auth.uid());

create policy circle_read on public.circles for select to authenticated using (
 owner_id=auth.uid() or exists(select 1 from public.circle_members m where m.circle_id=id and m.user_id=auth.uid()));
create policy circle_members_read on public.circle_members for select to authenticated using(
 user_id=auth.uid() or exists(select 1 from public.circles c where c.id=circle_id and c.owner_id=auth.uid()));
create policy block_read on public.blocks for select to authenticated using(blocker_id=auth.uid());
create policy block_insert on public.blocks for insert to authenticated with check(blocker_id=auth.uid());
create policy block_delete on public.blocks for delete to authenticated using(blocker_id=auth.uid());

create policy reaches_read on public.reaches for select to authenticated using(
 owner_id=auth.uid() or (
 not public.blocked_pair(owner_id,auth.uid()) and
 (scope='public' or exists(select 1 from public.circle_members cm where cm.circle_id=reaches.circle_id and cm.user_id=auth.uid()))));
create policy reaches_insert on public.reaches for insert to authenticated with check(owner_id=auth.uid());
create policy reaches_update on public.reaches for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
revoke update on public.reaches from authenticated;
grant update(status) on public.reaches to authenticated;

create policy request_read on public.connection_requests for select to authenticated using(
 sender_id=auth.uid() or exists(select 1 from public.reaches r where r.id=post_id and r.owner_id=auth.uid()));
create policy request_insert on public.connection_requests for insert to authenticated with check (
 sender_id=auth.uid() and exists(select 1 from public.reaches r where r.id=post_id and r.owner_id<>auth.uid()
 and r.status='open' and r.expires_at>now() and not public.blocked_pair(r.owner_id,auth.uid())));

create policy conv_read on public.conversations for select to authenticated using(
 (owner_id=auth.uid() or peer_id=auth.uid()) and not public.blocked_pair(owner_id,peer_id));
create policy message_read on public.messages for select to authenticated using(exists(
 select 1 from public.conversations c where c.id=conversation_id and
 (c.owner_id=auth.uid() or c.peer_id=auth.uid()) and not public.blocked_pair(c.owner_id,c.peer_id)));
create policy message_insert on public.messages for insert to authenticated with check(
 sender_id=auth.uid() and exists(select 1 from public.conversations c where c.id=conversation_id and
 (c.owner_id=auth.uid() or c.peer_id=auth.uid()) and not public.blocked_pair(c.owner_id,c.peer_id)));
create policy alerts_read on public.alerts for select to authenticated using(user_id=auth.uid());
create policy alerts_update on public.alerts for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
revoke update on public.alerts from authenticated;
grant update(read_at) on public.alerts to authenticated;
create policy report_insert on public.reports for insert to authenticated with check(reporter_id=auth.uid());
-- service_role or Supabase Dashboard admins review all reports; RLS denies read to app users.

-- Post and message spam guards, and server-side alerts.
create or replace function public.guard_request() returns trigger language plpgsql
security definer set search_path=public,pg_temp as $$
begin
 if new.sender_id<>auth.uid() then raise exception 'Invalid sender'; end if;
 if (select count(*) from public.connection_requests where sender_id=auth.uid() and created_at>now()-interval '1 minute') >= 6 then
 raise exception 'Too many requests. Try again shortly.'; end if;
 return new;
end $$;
create trigger guard_requests before insert on public.connection_requests
 for each row execute function public.guard_request();
create or replace function public.notify_request() returns trigger language plpgsql
security definer set search_path=public,pg_temp as $$
declare owner uuid;
begin
 select owner_id into owner from public.reaches where id=new.post_id;
 insert into public.alerts(user_id,title,body,related_id)
 values(owner,'New connection request','Someone wants to connect about your availability',new.id);
 return new;
end $$;
create trigger after_request after insert on public.connection_requests
 for each row execute function public.notify_request();

create or replace function public.guard_message() returns trigger language plpgsql
security definer set search_path=public,pg_temp as $$
begin
 if new.sender_id<>auth.uid() then raise exception 'Invalid sender'; end if;
 if exists(select 1 from public.messages where sender_id=auth.uid() and created_at>now()-interval '1 second') then
 raise exception 'Please slow down'; end if;
 return new;
end $$;
create trigger guard_messages before insert on public.messages for each row execute function public.guard_message();
create or replace function public.notify_message() returns trigger language plpgsql
security definer set search_path=public,pg_temp as $$
declare recipient uuid;
begin
 select case when owner_id=new.sender_id then peer_id else owner_id end into recipient
 from public.conversations where id=new.conversation_id;
 if recipient is not null then
  insert into public.alerts(user_id,title,body,related_id)
    values(recipient,'New message','You received a new message in Reach',new.conversation_id);
 end if;
 return new;
end $$;
create trigger after_message after insert on public.messages for each row execute function public.notify_message();

-- Discovery returns posts + only public city and country, never raw location.
create or replace function public.discover_reaches(
 p_area text default 'city', p_keyword text default '',p_category text default 'All',
 p_kind text default 'All',p_radius_km int default 25)
returns table(id uuid, owner_id uuid, owner_name text, title text, detail text,
 kind text, category text, city text, country text, expires_at timestamptz,
 created_at timestamptz,circle_name text, scope text)
language sql stable security definer set search_path=public,pg_temp as $$
 select r.id,r.owner_id,p.display_name,r.title,r.detail,r.kind,r.category,
 r.city,r.country,r.expires_at,r.created_at,coalesce(c.name,''),r.scope
 from public.reaches r join public.profiles p on p.id=r.owner_id
 cross join public.profiles me
 left join public.circles c on c.id=r.circle_id
 left join public.approx_locations mine on mine.user_id=auth.uid()
 left join public.approx_locations theirs on theirs.user_id=r.owner_id
 where me.id=auth.uid() and r.owner_id<>auth.uid() and not p.suspended
 and r.status='open' and r.expires_at>now()
 and not public.blocked_pair(r.owner_id,auth.uid())
 and (r.scope='public' or exists(select 1 from public.circle_members cm
  where cm.circle_id=r.circle_id and cm.user_id=auth.uid()))
 and (p_category='All' or r.category=p_category)
 and (p_kind='All' or r.kind=p_kind)
 and (length(trim(p_keyword))=0 or r.title ilike '%' || left(trim(p_keyword),80) || '%'
  or r.detail ilike '%' || left(trim(p_keyword),80) || '%')
 and (case p_area
  when 'city' then r.city<>'' and lower(r.city)=lower(me.city) and lower(r.country)=lower(me.country)
  when 'country' then r.country<>'' and lower(r.country)=lower(me.country)
  when 'nearby' then coalesce(me.location_opt_in,false) and mine.user_id is not null
   and theirs.user_id is not null and exists(select 1 from public.profiles theirprofile
   where theirprofile.id=r.owner_id and theirprofile.location_opt_in)
   and (6371*acos(least(1,greatest(-1,
     cos(radians(mine.lat::float8))*cos(radians(theirs.lat::float8))*
     cos(radians(theirs.lon::float8-mine.lon::float8))+
     sin(radians(mine.lat::float8))*sin(radians(theirs.lat::float8))
   )))) <= least(greatest(p_radius_km,5),100)
  when 'global' then true
  else false end)
 order by r.created_at desc limit 100;
$$;
revoke all on function public.discover_reaches(text,text,text,text,int) from public;
grant execute on function public.discover_reaches(text,text,text,text,int) to authenticated;

create or replace function public.my_reaches()
returns table(id uuid,owner_id uuid,owner_name text,title text,detail text,
 kind text,category text,city text,country text,expires_at timestamptz,
 created_at timestamptz,circle_name text,scope text)
language sql stable security definer set search_path=public,pg_temp as $$
select r.id,r.owner_id,p.display_name,r.title,r.detail,r.kind,r.category,
 r.city,r.country,r.expires_at,r.created_at,coalesce(c.name,''),r.scope
 from public.reaches r join public.profiles p on p.id=r.owner_id
 left join public.circles c on c.id=r.circle_id
 where r.owner_id=auth.uid() order by r.created_at desc limit 150;
$$;
revoke all on function public.my_reaches() from public;
grant execute on function public.my_reaches() to authenticated;

create or replace function public.list_connection_requests(p_incoming boolean default true)
returns table(id uuid,post_id uuid,post_title text,sender_id uuid,sender_name text,
 message text,status text,created_at timestamptz)
language sql stable security definer set search_path=public,pg_temp as $$
 select q.id,q.post_id,r.title,q.sender_id,p.display_name,q.message,q.status,q.created_at
 from public.connection_requests q join public.reaches r on r.id=q.post_id
 join public.profiles p on p.id=q.sender_id
 where (case when p_incoming then r.owner_id=auth.uid() else q.sender_id=auth.uid() end)
 and not public.blocked_pair(r.owner_id,q.sender_id)
 order by q.created_at desc limit 100;
$$;
revoke all on function public.list_connection_requests(boolean) from public;
grant execute on function public.list_connection_requests(boolean) to authenticated;

create or replace function public.answer_connection_request(p_request_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare q public.connection_requests; r public.reaches;
begin
 select * into q from public.connection_requests where id=p_request_id for update;
 if not found or q.status<>'pending' then raise exception 'Request unavailable'; end if;
 select * into r from public.reaches where id=q.post_id;
 if r.owner_id<>auth.uid() then raise exception 'Not allowed'; end if;
 if public.blocked_pair(r.owner_id,q.sender_id) then raise exception 'User blocked'; end if;
 update public.connection_requests set status=(case when p_accept then 'accepted' else 'declined' end) where id=q.id;
 if p_accept then
  insert into public.conversations(post_id,owner_id,peer_id) values(q.post_id,r.owner_id,q.sender_id)
   on conflict (post_id,peer_id) do nothing;
 end if;
 insert into public.alerts(user_id,title,body,related_id) values(q.sender_id,
 case when p_accept then 'Connection accepted' else 'Request declined' end,
 case when p_accept then 'You can now chat privately' else 'The request was declined' end,q.post_id);
end $$;
revoke all on function public.answer_connection_request(uuid,boolean) from public;
grant execute on function public.answer_connection_request(uuid,boolean) to authenticated;

create or replace function public.my_conversations()
returns table(id uuid,post_title text,peer_id uuid,peer_name text,
 last_body text, last_at timestamptz)
language sql stable security definer set search_path=public,pg_temp as $$
select c.id,r.title,
 case when c.owner_id=auth.uid() then c.peer_id else c.owner_id end,
 p.display_name,coalesce(m.body,''),coalesce(m.created_at,c.created_at)
from public.conversations c join public.reaches r on r.id=c.post_id
join public.profiles p on p.id=(case when c.owner_id=auth.uid() then c.peer_id else c.owner_id end)
left join lateral (select body,created_at from public.messages where conversation_id=c.id
 order by created_at desc limit 1) m on true
where (c.owner_id=auth.uid() or c.peer_id=auth.uid())
and not public.blocked_pair(c.owner_id,c.peer_id)
order by coalesce(m.created_at,c.created_at) desc limit 100;
$$;
revoke all on function public.my_conversations() from public;
grant execute on function public.my_conversations() to authenticated;

create or replace function public.create_circle(p_name text) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare new_id uuid; c text;
begin
 if length(trim(p_name))<3 or length(trim(p_name))>70 then raise exception 'Circle name must be 3–70 characters'; end if;
 if (select count(*) from public.circles where owner_id=auth.uid()) >= 20 then raise exception 'Circle limit reached'; end if;
 c := upper(substr(md5(random()::text || clock_timestamp()::text),1,10));
 insert into public.circles(name,invite_code,owner_id) values(trim(p_name),c,auth.uid()) returning id into new_id;
 insert into public.circle_members(circle_id,user_id) values(new_id,auth.uid());
 return new_id;
end $$;
create or replace function public.join_circle(p_code text) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare c uuid;
begin
 select id into c from public.circles where invite_code=upper(trim(p_code));
 if c is null then raise exception 'Circle invitation not found'; end if;
 insert into public.circle_members(circle_id,user_id) values(c,auth.uid()) on conflict do nothing;
end $$;
create or replace function public.leave_circle(p_circle uuid) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if exists(select 1 from public.circles where id=p_circle and owner_id=auth.uid()) then
  raise exception 'Circle owner cannot leave. Delete the circle from the admin dashboard.';
 end if;
 delete from public.circle_members where circle_id=p_circle and user_id=auth.uid();
end $$;
create or replace function public.my_circles()
returns table(id uuid,name text,invite_code text,owner_id uuid,member_count bigint)
language sql stable security definer set search_path=public,pg_temp as $$
select c.id,c.name,c.invite_code,c.owner_id,
 (select count(*) from public.circle_members cm2 where cm2.circle_id=c.id)
from public.circles c join public.circle_members cm on cm.circle_id=c.id
where cm.user_id=auth.uid() order by c.created_at desc;
$$;
create or replace function public.my_blocks()
returns table(id uuid,display_name text)
language sql stable security definer set search_path=public,pg_temp as $$
select b.blocked_id,p.display_name from public.blocks b
join public.profiles p on p.id=b.blocked_id where b.blocker_id=auth.uid();
$$;

-- Deleting account is immediate; cascade removes user data and auth identity.
-- Admins should separately address any legally necessary retention obligations.
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Not signed in'; end if;
 delete from auth.users where id=auth.uid();
end $$;

revoke all on function public.create_circle(text),public.join_circle(text),
 public.leave_circle(uuid),public.my_circles(),public.my_blocks(),public.delete_my_account() from public;
grant execute on function public.create_circle(text),public.join_circle(text),
 public.leave_circle(uuid),public.my_circles(),public.my_blocks(),public.delete_my_account() to authenticated;

-- Supabase Dashboard -> Database -> Publications must include messages and alerts for realtime streams.
-- Never embed service_role key in the Android binary.
