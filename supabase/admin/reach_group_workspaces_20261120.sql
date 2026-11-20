-- Reach group workspaces, 2026-11-20. Authenticated, opt-in and member-only.
-- Safe to reapply. All private group data remains behind membership checks.
BEGIN;

CREATE TABLE IF NOT EXISTS public.reach_group_messages(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id uuid NOT NULL REFERENCES public.circles(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_name text NOT NULL DEFAULT 'Member',
  body text NOT NULL CHECK(char_length(btrim(body)) BETWEEN 1 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS reach_group_messages_recent
  ON public.reach_group_messages(circle_id,created_at DESC);
CREATE INDEX IF NOT EXISTS reach_group_messages_sender_rate
  ON public.reach_group_messages(sender_id,created_at DESC);
ALTER TABLE public.reach_group_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rgm_read_members ON public.reach_group_messages;
CREATE POLICY rgm_read_members ON public.reach_group_messages FOR SELECT TO authenticated
 USING (public.is_circle_member(circle_id));
DROP POLICY IF EXISTS rgm_post_members ON public.reach_group_messages;
CREATE POLICY rgm_post_members ON public.reach_group_messages FOR INSERT TO authenticated
 WITH CHECK(sender_id=(select auth.uid()) AND public.is_circle_member(circle_id));
REVOKE ALL ON public.reach_group_messages FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.reach_group_messages TO authenticated;
GRANT INSERT(circle_id,sender_id,body) ON public.reach_group_messages TO authenticated;

CREATE TABLE IF NOT EXISTS public.reach_group_resources(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id uuid NOT NULL REFERENCES public.circles(id) ON DELETE CASCADE,
  creator_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  creator_name text NOT NULL DEFAULT 'Member',
  kind text NOT NULL CHECK(kind IN ('note','link')),
  title text NOT NULL CHECK(char_length(btrim(title)) BETWEEN 3 AND 100),
  note text NOT NULL DEFAULT '' CHECK(char_length(note)<=3000),
  url text CHECK(url IS NULL OR (char_length(url)<=1024 AND url ~* '^https://[^[:space:]]+$')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reach_group_resource_kind CHECK(
    (kind='note' AND url IS NULL) OR (kind='link' AND url IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS reach_group_resources_recent
  ON public.reach_group_resources(circle_id,created_at DESC);
CREATE INDEX IF NOT EXISTS reach_group_resources_creator_rate
  ON public.reach_group_resources(creator_id,created_at DESC);
ALTER TABLE public.reach_group_resources ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rgr_read_members ON public.reach_group_resources;
CREATE POLICY rgr_read_members ON public.reach_group_resources FOR SELECT TO authenticated
 USING(public.is_circle_member(circle_id));
DROP POLICY IF EXISTS rgr_add_members ON public.reach_group_resources;
CREATE POLICY rgr_add_members ON public.reach_group_resources FOR INSERT TO authenticated
 WITH CHECK(creator_id=(select auth.uid()) AND public.is_circle_member(circle_id));
DROP POLICY IF EXISTS rgr_remove_author_owner ON public.reach_group_resources;
CREATE POLICY rgr_remove_author_owner ON public.reach_group_resources FOR DELETE TO authenticated
 USING(public.is_circle_member(circle_id) AND (
   creator_id=(select auth.uid()) OR EXISTS(
     SELECT 1 FROM public.circles c WHERE c.id=circle_id AND c.owner_id=(select auth.uid()))
 ));
REVOKE ALL ON public.reach_group_resources FROM PUBLIC,anon,authenticated;
GRANT SELECT,DELETE ON public.reach_group_resources TO authenticated;
GRANT INSERT(circle_id,creator_id,kind,title,note,url)
 ON public.reach_group_resources TO authenticated;

CREATE OR REPLACE FUNCTION reach_private.reach_guard_group_workspace()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $func$
DECLARE member_name text; reason text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.profiles p
   WHERE p.id=auth.uid() AND NOT p.suspended
    AND p.terms_accepted_at IS NOT NULL AND p.adult_self_attested_at IS NOT NULL)
 THEN RAISE EXCEPTION 'Confirm adult eligibility before contributing to a group'; END IF;
 IF NOT public.is_circle_member(NEW.circle_id) THEN
  RAISE EXCEPTION 'Join this group before contributing'; END IF;
 IF TG_TABLE_NAME='reach_group_messages' THEN
  IF NEW.sender_id IS DISTINCT FROM auth.uid() THEN
   RAISE EXCEPTION 'Cannot send on behalf of another person'; END IF;
  IF (SELECT count(*) FROM public.reach_group_messages m
   WHERE m.sender_id=auth.uid() AND m.created_at>now()-interval '10 minutes')>=25 THEN
   RAISE EXCEPTION 'Message rate limit reached; try again later'; END IF;
  reason:=reach_private.reach_text_violation(NEW.body);
 ELSE
  IF NEW.creator_id IS DISTINCT FROM auth.uid() THEN
   RAISE EXCEPTION 'Cannot publish on behalf of another person'; END IF;
  IF (SELECT count(*) FROM public.reach_group_resources r
    WHERE r.creator_id=auth.uid() AND r.created_at>now()-interval '24 hours')>=30 THEN
    RAISE EXCEPTION 'Resource sharing limit reached; try again later'; END IF;
  reason:=reach_private.reach_text_violation(NEW.title || ' ' || NEW.note || ' ' || coalesce(NEW.url,''));
 END IF;
 IF reason IS NOT NULL THEN
  RAISE EXCEPTION 'Content blocked by Reach safety rules. Revise and try again'; END IF;
 SELECT coalesce(nullif(btrim(p.display_name),''),'Member') INTO member_name
  FROM public.profiles p WHERE p.id=auth.uid();
 IF TG_TABLE_NAME='reach_group_messages' THEN NEW.sender_name:=member_name;
 ELSE NEW.creator_name:=member_name; END IF;
 NEW.created_at:=now();
 RETURN NEW;
END $func$;
REVOKE ALL ON FUNCTION reach_private.reach_guard_group_workspace() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reach_group_message_guard ON public.reach_group_messages;
CREATE TRIGGER reach_group_message_guard
 BEFORE INSERT ON public.reach_group_messages FOR EACH ROW
 EXECUTE FUNCTION reach_private.reach_guard_group_workspace();
DROP TRIGGER IF EXISTS reach_group_resource_guard ON public.reach_group_resources;
CREATE TRIGGER reach_group_resource_guard
 BEFORE INSERT ON public.reach_group_resources FOR EACH ROW
 EXECUTE FUNCTION reach_private.reach_guard_group_workspace();

-- Group participants can see only minimal member directory data,
-- regardless of private profile settings. Do not expose email/phone.
CREATE OR REPLACE FUNCTION public.reach_group_members(p_circle uuid)
RETURNS TABLE(user_id uuid,display_name text,role text,joined_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=public,pg_temp AS $func$
 SELECT m.user_id,
   coalesce(nullif(btrim(p.display_name),''),'Member'),
   CASE WHEN c.owner_id=m.user_id THEN 'Owner' ELSE 'Member' END,
   m.joined_at
 FROM public.circle_members m
 JOIN public.circles c ON c.id=m.circle_id
 JOIN public.profiles p ON p.id=m.user_id
 WHERE m.circle_id=p_circle AND public.is_circle_member(p_circle)
  AND (m.user_id=auth.uid() OR NOT public.blocked_pair(m.user_id,auth.uid()))
 ORDER BY (c.owner_id=m.user_id) DESC,m.joined_at ASC
 LIMIT 250;
$func$;
REVOKE ALL ON FUNCTION public.reach_group_members(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_group_members(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.reach_group_posts(p_circle uuid)
RETURNS TABLE(id uuid,owner_id uuid,owner_name text,title text,detail text,
 kind text,category text,city text,country text,expires_at timestamptz,
 created_at timestamptz,circle_name text,scope text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $func$
 SELECT r.id,r.owner_id,coalesce(nullif(btrim(p.display_name),''),'Member'),
   r.title,r.detail,r.kind,r.category,r.city,r.country,
   r.expires_at,r.created_at,c.name,r.scope
 FROM public.reaches r
 JOIN public.circles c ON c.id=r.circle_id
 JOIN public.profiles p ON p.id=r.owner_id
 WHERE r.circle_id=p_circle AND r.scope='circle'
  AND r.status='open' AND r.expires_at>now()
  AND public.is_circle_member(p_circle)
  AND (r.owner_id=auth.uid() OR NOT public.blocked_pair(r.owner_id,auth.uid()))
 ORDER BY r.created_at DESC
 LIMIT 100;
$func$;
REVOKE ALL ON FUNCTION public.reach_group_posts(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_group_posts(uuid) TO authenticated;

-- Owners can revoke compromised invitation codes; members see/share codes
-- only for groups to which they already belong.
CREATE OR REPLACE FUNCTION public.reach_rotate_group_invite(p_circle uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=public,pg_temp AS $func$
DECLARE next_code text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.circles c WHERE c.id=p_circle AND c.owner_id=auth.uid())
 THEN RAISE EXCEPTION 'Only the owner can reset this group invitation'; END IF;
 next_code:=upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text),1,10));
 UPDATE public.circles SET invite_code=next_code WHERE id=p_circle;
 RETURN next_code;
END $func$;
REVOKE ALL ON FUNCTION public.reach_rotate_group_invite(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_rotate_group_invite(uuid) TO authenticated;

-- Harden old invite-code entry to match public-join age/block/capacity limits.
CREATE OR REPLACE FUNCTION public.join_circle(p_code text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $func$
DECLARE me uuid:=auth.uid(); circle_row public.circles;
BEGIN
 IF me IS NULL THEN RAISE EXCEPTION 'Sign in before joining'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p
    WHERE p.id=me AND NOT p.suspended AND p.adult_self_attested_at IS NOT NULL
      AND p.terms_accepted_at IS NOT NULL) THEN
   RAISE EXCEPTION 'Complete your adult profile before joining groups'; END IF;
 IF (SELECT count(*) FROM public.circle_members
     WHERE user_id=me AND joined_at>now()-interval '1 hour')>=5 THEN
   RAISE EXCEPTION 'Group join limit reached; try again later'; END IF;
 SELECT * INTO circle_row FROM public.circles
 WHERE invite_code=upper(btrim(coalesce(p_code,''))) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Invitation code is invalid or has expired'; END IF;
 IF EXISTS(SELECT 1 FROM public.profiles WHERE id=circle_row.owner_id AND suspended)
   OR public.blocked_pair(circle_row.owner_id,me) THEN
  RAISE EXCEPTION 'This group is unavailable'; END IF;
 IF EXISTS(SELECT 1 FROM public.circle_members
   WHERE circle_id=circle_row.id AND user_id=me) THEN RETURN; END IF;
 IF (SELECT count(*) FROM public.circle_members WHERE user_id=me)>=50 THEN
  RAISE EXCEPTION 'You have reached the group membership limit'; END IF;
 IF (SELECT count(*) FROM public.circle_members WHERE circle_id=circle_row.id)>=250 THEN
  RAISE EXCEPTION 'This group is at capacity'; END IF;
 INSERT INTO public.circle_members(circle_id,user_id)
 VALUES(circle_row.id,me) ON CONFLICT DO NOTHING;
END $func$;
REVOKE ALL ON FUNCTION public.join_circle(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.join_circle(text) TO authenticated;

-- A distinct Calls controller can list only each signed-in user's records.
CREATE OR REPLACE FUNCTION public.reach_my_call_history()
RETURNS TABLE(id uuid,peer_id uuid,peer_name text,kind text,status text,
 created_at timestamptz,ended_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $func$
 SELECT c.id,
  CASE WHEN c.caller_id=auth.uid() THEN c.callee_id ELSE c.caller_id END,
  coalesce(nullif(btrim(p.display_name),''),'Member'),
  c.kind,c.status,c.created_at,c.ended_at
 FROM public.reach_calls c
 JOIN public.profiles p ON p.id=CASE WHEN c.caller_id=auth.uid()
   THEN c.callee_id ELSE c.caller_id END
 WHERE (c.caller_id=auth.uid() OR c.callee_id=auth.uid())
  AND NOT public.blocked_pair(c.caller_id,c.callee_id)
 ORDER BY c.created_at DESC LIMIT 60;
$func$;
REVOKE ALL ON FUNCTION public.reach_my_call_history() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_my_call_history() TO authenticated;

DO $do$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_publication_tables
  WHERE pubname='supabase_realtime' AND schemaname='public'
    AND tablename='reach_group_messages') THEN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.reach_group_messages;
 END IF;
END $do$;
COMMIT;