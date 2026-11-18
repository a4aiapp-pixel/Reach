
-- Reach communities: upgrade private invitation circles without exposing their codes.
-- Seeded UI templates are local suggestions, not fake live groups or accounts.
ALTER TABLE public.circles
 ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'private',
 ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'Other',
 ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
 ADD COLUMN IF NOT EXISTS city text NOT NULL DEFAULT '',
 ADD COLUMN IF NOT EXISTS country text NOT NULL DEFAULT '';

ALTER TABLE public.circles DROP CONSTRAINT IF EXISTS circles_visibility_check;
ALTER TABLE public.circles ADD CONSTRAINT circles_visibility_check
  CHECK (visibility IN ('private','public'));
ALTER TABLE public.circles DROP CONSTRAINT IF EXISTS circles_category_check;
ALTER TABLE public.circles ADD CONSTRAINT circles_category_check
  CHECK (length(btrim(category)) BETWEEN 2 AND 40);
ALTER TABLE public.circles DROP CONSTRAINT IF EXISTS circles_description_check;
ALTER TABLE public.circles ADD CONSTRAINT circles_description_check
  CHECK (length(description) <= 240);
CREATE INDEX IF NOT EXISTS circles_public_discover_idx
 ON public.circles(country,city,created_at DESC) WHERE visibility='public';

-- Existing private circles retain their old schema and calling conventions.
CREATE OR REPLACE FUNCTION public.create_community(
 p_name text, p_category text, p_description text, p_visibility text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $fn$
DECLARE me uuid := auth.uid(); p public.profiles; new_id uuid; new_code text;
BEGIN
 IF me IS NULL THEN RAISE EXCEPTION 'Please sign in to create a group'; END IF;
 SELECT * INTO p FROM public.profiles WHERE id=me;
 IF NOT FOUND OR p.suspended OR p.terms_accepted_at IS NULL
     OR btrim(p.city)='' OR btrim(p.country)='' THEN
   RAISE EXCEPTION 'Complete your adult profile to create a group';
 END IF;
 IF length(btrim(coalesce(p_name,''))) NOT BETWEEN 3 AND 70 OR
    length(btrim(coalesce(p_category,''))) NOT BETWEEN 2 AND 40 OR
    length(coalesce(p_description,''))>240 OR
    p_visibility NOT IN ('private','public') THEN
   RAISE EXCEPTION 'Invalid group name, topic, description or visibility';
 END IF;
 IF (SELECT count(*) FROM public.circles WHERE owner_id=me)>=20 OR
    (SELECT count(*) FROM public.circles WHERE owner_id=me
       AND created_at > now()-interval '24 hours')>=3 THEN
   RAISE EXCEPTION 'Group creation limit reached; try again later';
 END IF;
 new_code:=upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text),1,10));
 INSERT INTO public.circles(name,category,description,visibility,city,country,invite_code,owner_id)
 VALUES(btrim(p_name),btrim(p_category),btrim(coalesce(p_description,'')),p_visibility,
        p.city,p.country,new_code,me)
 RETURNING id INTO new_id;
 INSERT INTO public.circle_members(circle_id,user_id) VALUES(new_id,me);
 RETURN new_id;
END $fn$;
REVOKE ALL ON FUNCTION public.create_community(text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_community(text,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.discover_communities(
 p_keyword text DEFAULT '', p_category text DEFAULT 'All', p_area text DEFAULT 'country')
RETURNS TABLE(id uuid,name text,description text,category text,city text,country text,
              owner_id uuid,member_count bigint,is_member boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
SELECT c.id,c.name,c.description,c.category,c.city,c.country,c.owner_id,
       (SELECT count(*) FROM public.circle_members cm WHERE cm.circle_id=c.id) AS member_count,
       EXISTS(SELECT 1 FROM public.circle_members cm WHERE cm.circle_id=c.id
              AND cm.user_id=auth.uid()) AS is_member
FROM public.circles c
JOIN public.profiles owner ON owner.id=c.owner_id AND NOT owner.suspended
JOIN public.profiles me ON me.id=auth.uid() AND NOT me.suspended
WHERE c.visibility='public'
 AND (p_keyword IS NULL OR length(btrim(p_keyword))=0
   OR c.name ILIKE '%'||left(btrim(p_keyword),80)||'%'
   OR c.description ILIKE '%'||left(btrim(p_keyword),80)||'%')
 AND (p_category IS NULL OR p_category='All' OR c.category=p_category)
 AND (p_area='global' OR (p_area='country' AND lower(c.country)=lower(me.country))
   OR (p_area='city' AND lower(c.country)=lower(me.country)
                      AND lower(c.city)=lower(me.city)))
 AND NOT public.blocked_pair(c.owner_id,auth.uid())
ORDER BY (SELECT count(*) FROM public.circle_members cm WHERE cm.circle_id=c.id) DESC,
         c.created_at DESC
LIMIT 60;
$fn$;
REVOKE ALL ON FUNCTION public.discover_communities(text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.discover_communities(text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.my_communities()
RETURNS TABLE(id uuid,name text,invite_code text,owner_id uuid,member_count bigint,
              category text,description text,visibility text,city text,country text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
SELECT c.id,c.name,c.invite_code,c.owner_id,
       (SELECT count(*) FROM public.circle_members cm2 WHERE cm2.circle_id=c.id),
       c.category,c.description,c.visibility,c.city,c.country
FROM public.circles c JOIN public.circle_members m ON m.circle_id=c.id
WHERE m.user_id=auth.uid()
ORDER BY c.created_at DESC
LIMIT 60;
$fn$;
REVOKE ALL ON FUNCTION public.my_communities() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.my_communities() TO authenticated;

CREATE OR REPLACE FUNCTION public.join_public_community(p_circle uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
DECLARE me uuid:=auth.uid(); c public.circles; p public.profiles;
BEGIN
 IF me IS NULL THEN RAISE EXCEPTION 'Sign in before joining'; END IF;
 SELECT * INTO p FROM public.profiles WHERE id=me;
 IF NOT FOUND OR p.suspended OR p.terms_accepted_at IS NULL THEN
   RAISE EXCEPTION 'This account cannot join groups'; END IF;
 SELECT * INTO c FROM public.circles WHERE id=p_circle FOR UPDATE;
 IF NOT FOUND OR c.visibility<>'public' THEN
   RAISE EXCEPTION 'Public group not available'; END IF;
 IF EXISTS(SELECT 1 FROM public.profiles WHERE id=c.owner_id AND suspended) OR
    public.blocked_pair(c.owner_id,me) THEN
   RAISE EXCEPTION 'This group is unavailable to this member'; END IF;
 IF EXISTS(SELECT 1 FROM public.circle_members WHERE circle_id=p_circle AND user_id=me) THEN
   RETURN;
 END IF;
 IF (SELECT count(*) FROM public.circle_members WHERE user_id=me)>=50 THEN
   RAISE EXCEPTION 'Membership limit reached'; END IF;
 IF (SELECT count(*) FROM public.circle_members WHERE circle_id=p_circle)>=250 THEN
   RAISE EXCEPTION 'This group is at capacity'; END IF;
 INSERT INTO public.circle_members(circle_id,user_id) VALUES(p_circle,me) ON CONFLICT DO NOTHING;
END $fn$;
REVOKE ALL ON FUNCTION public.join_public_community(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.join_public_community(uuid) TO authenticated;

-- Public groups are user-generated content and must be reportable in-app.
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_target_type_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_target_type_check
 CHECK (target_type IN ('post','user','message','group'));
CREATE OR REPLACE FUNCTION public.guard_report_abuse()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE me uuid := auth.uid();
BEGIN
 IF me IS NULL OR new.reporter_id IS DISTINCT FROM me THEN
   RAISE EXCEPTION 'Authenticated reporter required';
 END IF;
 IF new.target_id IS NULL THEN RAISE EXCEPTION 'A report target is required'; END IF;
 IF new.target_type NOT IN ('post','user','message','group') THEN
   RAISE EXCEPTION 'Unsupported report target'; END IF;
 IF new.reason NOT IN ('spam','harassment','unsafe','fraud','other',
                       'child_safety','sexual_exploitation','impersonation') THEN
   RAISE EXCEPTION 'Unsupported report category'; END IF;
 new.created_at := now();
 new.status := 'open';
 IF new.target_type='user' THEN
   IF new.target_id=me OR NOT EXISTS (
     SELECT 1 FROM public.profiles WHERE id=new.target_id
   ) THEN RAISE EXCEPTION 'Member not reportable'; END IF;
 ELSIF new.target_type='post' THEN
   IF NOT EXISTS (SELECT 1 FROM public.reaches WHERE id=new.target_id)
   THEN RAISE EXCEPTION 'Post no longer available'; END IF;
 ELSIF new.target_type='group' THEN
   IF NOT EXISTS (SELECT 1 FROM public.circles WHERE id=new.target_id
     AND visibility='public' AND owner_id<>me)
   THEN RAISE EXCEPTION 'Group not reportable'; END IF;
 ELSIF new.target_type='message' THEN
   IF NOT EXISTS (
     SELECT 1 FROM public.messages m
     JOIN public.conversations c ON c.id=m.conversation_id
     WHERE m.id=new.target_id AND (c.owner_id=me OR c.peer_id=me)
   ) THEN RAISE EXCEPTION 'Message not available'; END IF;
 END IF;
 IF (SELECT count(*) FROM public.reports
      WHERE reporter_id=me AND created_at>now()-interval '1 hour')>=10 THEN
   RAISE EXCEPTION 'Report limit reached. Try again later'; END IF;
 IF EXISTS(SELECT 1 FROM public.reports
    WHERE reporter_id=me AND target_type=new.target_type
      AND target_id=new.target_id AND created_at>now()-interval '24 hours') THEN
   RAISE EXCEPTION 'You have already reported this item'; END IF;
 RETURN new;
END $fn$;
REVOKE ALL ON FUNCTION public.guard_report_abuse() FROM PUBLIC,anon,authenticated;
