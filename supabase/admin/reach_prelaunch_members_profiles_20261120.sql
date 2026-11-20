-- Reach prelaunch: consent-respecting member invitations & avatar profiles.
-- Explicit direct-add opt-in, pending invitations, and private avatar access.
BEGIN;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS allow_group_direct_add boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS allow_group_invites boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS avatar_path text,
  ADD COLUMN IF NOT EXISTS avatar_color text NOT NULL DEFAULT 'indigo',
  ADD COLUMN IF NOT EXISTS allow_media_messages boolean NOT NULL DEFAULT false;
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS reach_avatar_color_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT reach_avatar_color_check CHECK (
    avatar_color IN ('indigo','coral','mint','sunset','violet','sky','amber','rose'));
REVOKE UPDATE (allow_group_direct_add,allow_group_invites,avatar_path,avatar_color,allow_media_messages)
  ON public.profiles FROM PUBLIC,anon;
GRANT UPDATE (allow_group_direct_add,allow_group_invites,avatar_path,avatar_color,allow_media_messages)
  ON public.profiles TO authenticated;
CREATE INDEX IF NOT EXISTS reach_profiles_search_group_invites
  ON public.profiles(lower(username))
  WHERE people_discoverable AND allow_group_invites AND NOT suspended;

CREATE TABLE IF NOT EXISTS public.reach_group_invitations(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id uuid NOT NULL REFERENCES public.circles(id) ON DELETE CASCADE,
  target_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  inviter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','declined')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now()+interval '14 days'),
  decided_at timestamptz,
  UNIQUE(circle_id,target_id)
);
CREATE INDEX IF NOT EXISTS reach_group_invitee_pending
 ON public.reach_group_invitations(target_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS reach_group_inviter_rate
 ON public.reach_group_invitations(inviter_id,created_at DESC);
ALTER TABLE public.reach_group_invitations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS reach_group_invitation_read ON public.reach_group_invitations;
CREATE POLICY reach_group_invitation_read ON public.reach_group_invitations
 FOR SELECT TO authenticated
 USING(target_id=(select auth.uid()) OR inviter_id=(select auth.uid()));
REVOKE ALL ON public.reach_group_invitations FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.reach_group_invitations TO authenticated;

-- Only a group owner can search candidates, and only explicitly discoverable
-- people accepting invitations are exposed. Never expose email addresses.
CREATE OR REPLACE FUNCTION public.reach_group_candidates(
  p_circle uuid,p_query text DEFAULT ''
) RETURNS TABLE(
  id uuid,username text,display_name text,city text,country text,
  profile_visibility text,avatar_path text,allow_direct boolean
) LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $fn$
 SELECT p.id,p.username,p.display_name,p.city,p.country,p.profile_visibility,
   CASE WHEN p.profile_visibility='public' THEN p.avatar_path ELSE NULL END,
   p.allow_group_direct_add
 FROM public.profiles p
 WHERE auth.uid() IS NOT NULL
   AND EXISTS (SELECT 1 FROM public.circles c
     WHERE c.id=p_circle AND c.owner_id=auth.uid())
   AND p.id<>auth.uid() AND p.people_discoverable AND p.allow_group_invites
   AND p.adult_self_attested_at IS NOT NULL
   AND p.terms_accepted_at IS NOT NULL AND NOT p.suspended
   AND NOT public.blocked_pair(p.id,auth.uid())
   AND NOT EXISTS (SELECT 1 FROM public.circle_members m
     WHERE m.circle_id=p_circle AND m.user_id=p.id)
   AND (btrim(coalesce(p_query,''))='' OR
     lower(p.username) LIKE '%'||lower(left(btrim(p_query),60))||'%' OR
     lower(p.display_name) LIKE '%'||lower(left(btrim(p_query),60))||'%')
 ORDER BY p.display_name,p.username LIMIT 40;
$fn$;
REVOKE ALL ON FUNCTION public.reach_group_candidates(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_group_candidates(uuid,text) TO authenticated;

-- Owner-controlled addition by account ID, username, or exact email.
-- Unsolicited direct joining is impossible unless target opted in.
-- Email results deliberately do not reveal whether an account exists.
CREATE OR REPLACE FUNCTION public.reach_add_group_member(
 p_circle uuid,p_identity text,p_invite_only boolean DEFAULT false
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE me uuid:=auth.uid(); target public.profiles; identity_text text;
  is_email boolean; limit_count int; new_invite uuid; circle_row public.circles;
BEGIN
 IF me IS NULL THEN RAISE EXCEPTION 'Sign in to invite people'; END IF;
 SELECT * INTO circle_row FROM public.circles
  WHERE id=p_circle AND owner_id=me FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Only the group owner can add or invite people'; END IF;
 IF (SELECT count(*) FROM public.reach_group_invitations
    WHERE inviter_id=me AND created_at>now()-interval '24 hours')>=15 THEN
  RAISE EXCEPTION 'Invitation limit reached for today'; END IF;
 identity_text:=left(btrim(coalesce(p_identity,'')),254);
 IF char_length(identity_text)<3 THEN RAISE EXCEPTION 'Enter a member ID, username or email'; END IF;
 is_email:=strpos(identity_text,'@')>0;
 IF is_email THEN
   SELECT p.* INTO target FROM public.profiles p
     JOIN auth.users u ON u.id=p.id
     WHERE lower(u.email)=lower(identity_text) LIMIT 1;
 ELSIF identity_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
   SELECT * INTO target FROM public.profiles p WHERE p.id=identity_text::uuid;
 ELSE
   SELECT * INTO target FROM public.profiles p
     WHERE lower(p.username)=lower(identity_text) LIMIT 1;
 END IF;
 IF NOT FOUND OR target.id=me OR target.suspended
    OR target.adult_self_attested_at IS NULL
    OR target.terms_accepted_at IS NULL
    OR NOT target.allow_group_invites
    OR public.blocked_pair(me,target.id) THEN
   RETURN 'submitted';
 END IF;
 IF EXISTS(SELECT 1 FROM public.circle_members
    WHERE circle_id=p_circle AND user_id=target.id) THEN
   RETURN CASE WHEN is_email THEN 'submitted' ELSE 'already_member' END;
 END IF;
 IF (SELECT count(*) FROM public.circle_members WHERE circle_id=p_circle)>=250 THEN
   RAISE EXCEPTION 'Group is full'; END IF;
 IF NOT p_invite_only AND target.allow_group_direct_add THEN
   IF (SELECT count(*) FROM public.circle_members WHERE user_id=target.id)>=50 THEN
     RETURN 'submitted'; END IF;
   INSERT INTO public.circle_members(circle_id,user_id) VALUES(p_circle,target.id)
     ON CONFLICT DO NOTHING;
   INSERT INTO public.alerts(user_id,title,body,related_id)
     VALUES(target.id,'You joined a group',
       'You were added to "'||left(circle_row.name,65)||'".',p_circle);
   RETURN CASE WHEN is_email THEN 'submitted' ELSE 'added' END;
 END IF;
 INSERT INTO public.reach_group_invitations(circle_id,target_id,inviter_id)
   VALUES(p_circle,target.id,me)
   ON CONFLICT(circle_id,target_id) DO UPDATE
     SET status='pending',inviter_id=excluded.inviter_id,
       created_at=now(),expires_at=now()+interval '14 days',decided_at=NULL
     WHERE public.reach_group_invitations.status<>'pending'
       OR public.reach_group_invitations.expires_at<now()
   RETURNING id INTO new_invite;
 IF new_invite IS NOT NULL THEN
   INSERT INTO public.alerts(user_id,title,body,related_id)
     VALUES(target.id,'New group invitation',
      'You have been invited to "'||left(circle_row.name,65)||'".',p_circle);
 END IF;
 RETURN CASE WHEN is_email THEN 'submitted' ELSE 'invited' END;
END $fn$;
REVOKE ALL ON FUNCTION public.reach_add_group_member(uuid,text,boolean)
 FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_add_group_member(uuid,text,boolean)
 TO authenticated;

CREATE OR REPLACE FUNCTION public.reach_group_inbox()
RETURNS TABLE(
  id uuid,circle_id uuid,group_name text,inviter_name text,created_at timestamptz,
  expires_at timestamptz
) LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $fn$
 SELECT i.id,i.circle_id,c.name,
   coalesce(nullif(btrim(p.display_name),''),'Member'),
   i.created_at,i.expires_at
 FROM public.reach_group_invitations i
 JOIN public.circles c ON c.id=i.circle_id
 JOIN public.profiles p ON p.id=i.inviter_id
 WHERE i.target_id=auth.uid() AND i.status='pending'
   AND i.expires_at>now()
   AND NOT public.blocked_pair(i.target_id,i.inviter_id)
 ORDER BY i.created_at DESC LIMIT 50;
$fn$;
REVOKE ALL ON FUNCTION public.reach_group_inbox() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_group_inbox() TO authenticated;

CREATE OR REPLACE FUNCTION public.reach_answer_group_invitation(
 p_invitation uuid,p_accept boolean
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE inv public.reach_group_invitations;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in'; END IF;
 SELECT * INTO inv FROM public.reach_group_invitations
  WHERE id=p_invitation AND target_id=auth.uid()
    AND status='pending' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Invitation no longer available'; END IF;
 IF inv.expires_at<now() THEN RAISE EXCEPTION 'Invitation has expired'; END IF;
 IF NOT p_accept THEN
  UPDATE public.reach_group_invitations SET status='declined',decided_at=now()
   WHERE id=inv.id;
  RETURN 'declined';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid()
   AND p.adult_self_attested_at IS NOT NULL AND p.terms_accepted_at IS NOT NULL
   AND NOT p.suspended) THEN RAISE EXCEPTION 'Complete adult eligibility first'; END IF;
 IF public.blocked_pair(auth.uid(),inv.inviter_id) THEN
   RAISE EXCEPTION 'This group invitation is no longer available'; END IF;
 PERFORM 1 FROM public.circles WHERE id=inv.circle_id FOR UPDATE;
 IF (SELECT count(*) FROM public.circle_members
   WHERE circle_id=inv.circle_id)>=250 THEN
   RAISE EXCEPTION 'Group is full'; END IF;
 IF (SELECT count(*) FROM public.circle_members
   WHERE user_id=auth.uid())>=50 THEN
   RAISE EXCEPTION 'Group membership limit reached'; END IF;
 INSERT INTO public.circle_members(circle_id,user_id)
 VALUES(inv.circle_id,auth.uid()) ON CONFLICT DO NOTHING;
 UPDATE public.reach_group_invitations SET status='accepted',decided_at=now()
  WHERE id=inv.id;
 RETURN 'accepted';
END $fn$;
REVOKE ALL ON FUNCTION public.reach_answer_group_invitation(uuid,boolean)
 FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_answer_group_invitation(uuid,boolean)
 TO authenticated;

-- A person's public profile is only exposed if explicitly public and
-- discoverable; accepted direct connections and shared group members can
-- see an appropriately limited member profile. No email or phone exposed.
CREATE OR REPLACE FUNCTION public.reach_member_profile(p_member uuid)
RETURNS TABLE(id uuid,display_name text,username text,bio text,skills text[],
 city text,country text,profile_visibility text,avatar_path text,
 avatar_color text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $fn$
 SELECT p.id,p.display_name,p.username,
  CASE WHEN p.profile_visibility='public' OR p.id=auth.uid()
    OR EXISTS(SELECT 1 FROM public.member_connections mc
      WHERE mc.status='accepted'
        AND ((mc.sender_id=auth.uid() AND mc.recipient_id=p.id)
          OR(mc.recipient_id=auth.uid() AND mc.sender_id=p.id)))
    THEN p.bio ELSE '' END,
  CASE WHEN p.profile_visibility='public' OR p.id=auth.uid()
    OR EXISTS(SELECT 1 FROM public.member_connections mc
      WHERE mc.status='accepted'
       AND ((mc.sender_id=auth.uid() AND mc.recipient_id=p.id)
        OR(mc.recipient_id=auth.uid() AND mc.sender_id=p.id)))
    THEN p.skills ELSE ARRAY[]::text[] END,
  p.city,p.country,p.profile_visibility,p.avatar_path,p.avatar_color
 FROM public.profiles p
 WHERE p.id=p_member AND auth.uid() IS NOT NULL
  AND (p.id=auth.uid() OR (p.adult_self_attested_at IS NOT NULL
    AND p.terms_accepted_at IS NOT NULL AND NOT p.suspended
    AND NOT public.blocked_pair(p.id,auth.uid())
    AND ((p.people_discoverable AND p.profile_visibility='public')
      OR EXISTS(SELECT 1 FROM public.member_connections mc
         WHERE mc.status='accepted'
         AND ((mc.sender_id=auth.uid() AND mc.recipient_id=p.id)
           OR(mc.recipient_id=auth.uid() AND mc.sender_id=p.id)))
      OR EXISTS(SELECT 1 FROM public.circle_members a
        JOIN public.circle_members b ON b.circle_id=a.circle_id
        WHERE a.user_id=auth.uid() AND b.user_id=p.id))));
$fn$;
REVOKE ALL ON FUNCTION public.reach_member_profile(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_member_profile(uuid) TO authenticated;

-- Small private, profile-photo-only storage. User-controlled, no public URL.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('reach-avatars','reach-avatars',false,2097152,ARRAY['image/jpeg'])
 ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=2097152,
   allowed_mime_types=ARRAY['image/jpeg'];
DROP POLICY IF EXISTS reach_avatars_read ON storage.objects;
CREATE POLICY reach_avatars_read ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id='reach-avatars'
  AND EXISTS(SELECT 1 FROM public.profiles p
     WHERE p.id=split_part(name,'/',1)::uuid
       AND (p.id=auth.uid()
         OR ((p.profile_visibility='public' AND p.people_discoverable)
             AND NOT public.blocked_pair(p.id,auth.uid()))
         OR EXISTS(SELECT 1 FROM public.member_connections mc
           WHERE mc.status='accepted'
             AND ((mc.sender_id=auth.uid() AND mc.recipient_id=p.id)
               OR(mc.recipient_id=auth.uid() AND mc.sender_id=p.id)))
         OR EXISTS(SELECT 1 FROM public.circle_members a
            JOIN public.circle_members b ON a.circle_id=b.circle_id
            WHERE a.user_id=auth.uid() AND b.user_id=p.id))));
DROP POLICY IF EXISTS reach_avatars_insert ON storage.objects;
CREATE POLICY reach_avatars_insert ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='reach-avatars'
   AND split_part(name,'/',1)=auth.uid()::text
   AND name=auth.uid()::text||'/avatar.jpg');
DROP POLICY IF EXISTS reach_avatars_update ON storage.objects;
CREATE POLICY reach_avatars_update ON storage.objects FOR UPDATE TO authenticated
 USING(bucket_id='reach-avatars'
   AND name=auth.uid()::text||'/avatar.jpg')
 WITH CHECK(bucket_id='reach-avatars'
   AND name=auth.uid()::text||'/avatar.jpg');
DROP POLICY IF EXISTS reach_avatars_delete ON storage.objects;
CREATE POLICY reach_avatars_delete ON storage.objects FOR DELETE TO authenticated
 USING(bucket_id='reach-avatars'
   AND name=auth.uid()::text||'/avatar.jpg');
COMMIT;