-- Read-only profile and member directory V2; original RPCs remain compatible.
BEGIN;
CREATE OR REPLACE FUNCTION public.reach_group_members_v2(p_circle uuid)
RETURNS TABLE(
 user_id uuid,display_name text,role text,joined_at timestamptz,
 avatar_path text,avatar_color text
) LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $fn$
 SELECT m.user_id,coalesce(nullif(btrim(p.display_name),''),'Member'),
  CASE WHEN c.owner_id=m.user_id THEN 'Owner' ELSE 'Member' END,
  m.joined_at,p.avatar_path,p.avatar_color
 FROM public.circle_members m
 JOIN public.circles c ON c.id=m.circle_id
 JOIN public.profiles p ON p.id=m.user_id
 WHERE m.circle_id=p_circle AND public.is_circle_member(p_circle)
  AND (m.user_id=auth.uid() OR NOT public.blocked_pair(m.user_id,auth.uid()))
 ORDER BY (c.owner_id=m.user_id) DESC,m.joined_at LIMIT 250;
$fn$;
REVOKE ALL ON FUNCTION public.reach_group_members_v2(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_group_members_v2(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.reach_discover_people_v2(
 p_area text DEFAULT 'city',p_query text DEFAULT ''
) RETURNS TABLE(id uuid,username text,display_name text,city text,
 country text,profile_visibility text,bio text,skills text[],
 connection_status text,conversation_id uuid,avatar_path text,avatar_color text
) LANGUAGE plpgsql STABLE SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE me public.profiles%ROWTYPE;needle text;
BEGIN
 IF auth.uid() IS NULL THEN RETURN; END IF;
 SELECT * INTO me FROM public.profiles p WHERE p.id=auth.uid();
 IF NOT FOUND OR me.adult_self_attested_at IS NULL OR me.suspended THEN RETURN; END IF;
 needle:=left(btrim(coalesce(p_query,'')),50);
 IF p_area NOT IN ('city','country','global') THEN RETURN; END IF;
 IF p_area='global' AND char_length(needle)<2 THEN RETURN; END IF;
 RETURN QUERY SELECT p.id,p.username,p.display_name,p.city,p.country,
  p.profile_visibility,
  CASE WHEN p.profile_visibility='public' OR mc.status='accepted'
   THEN p.bio ELSE '' END,
  CASE WHEN p.profile_visibility='public' OR mc.status='accepted'
   THEN p.skills ELSE ARRAY[]::text[] END,
  coalesce(mc.status,'none'),
  CASE WHEN mc.status='accepted' THEN mc.conversation_id ELSE NULL::uuid END,
  CASE WHEN p.profile_visibility='public' OR mc.status='accepted'
    THEN p.avatar_path ELSE NULL::text END,p.avatar_color
 FROM public.profiles p
 LEFT JOIN public.member_connections mc ON
  ((mc.sender_id=auth.uid() AND mc.recipient_id=p.id)
   OR(mc.recipient_id=auth.uid() AND mc.sender_id=p.id))
 WHERE p.id<>auth.uid() AND p.people_discoverable
  AND p.adult_self_attested_at IS NOT NULL
  AND p.terms_accepted_at IS NOT NULL AND NOT p.suspended
  AND NOT public.blocked_pair(p.id,auth.uid())
  AND (needle='' OR strpos(lower(coalesce(p.username,'')),lower(needle))>0
    OR strpos(lower(p.display_name),lower(needle))>0)
  AND (CASE p_area WHEN 'city'
   THEN p.city<>'' AND lower(btrim(p.city))=lower(btrim(me.city))
    AND lower(btrim(p.country))=lower(btrim(me.country))
   WHEN 'country' THEN p.country<>'' AND
      lower(btrim(p.country))=lower(btrim(me.country))
   ELSE true END)
 ORDER BY p.display_name,p.username LIMIT 40;
END $fn$;
REVOKE ALL ON FUNCTION public.reach_discover_people_v2(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_discover_people_v2(text,text) TO authenticated;

-- A report quarantines the file via a privileged UPDATE; this is not a
-- sender upload and must not be incorrectly treated as one.
CREATE OR REPLACE FUNCTION reach_private.guard_sensitive_attachments()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE v_kind text; allowed int;
BEGIN
 IF TG_OP='UPDATE' AND NEW.status='quarantined'
    AND OLD.status<>'quarantined' THEN RETURN NEW; END IF;
 IF auth.uid() IS NULL OR NEW.sender_id<>auth.uid() THEN
  RAISE EXCEPTION 'Only the signed-in sender may upload'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid()
   AND p.adult_self_attested_at IS NOT NULL AND p.terms_accepted_at IS NOT NULL
   AND NOT p.suspended) THEN
   RAISE EXCEPTION 'Complete account eligibility before sharing files'; END IF;
 IF reach_private.reach_text_violation(NEW.file_name) IS NOT NULL THEN
  RAISE EXCEPTION 'File name violates Reach safety rules'; END IF;
 IF NEW.mime_type LIKE 'image/%' THEN v_kind:='image';allowed:=8388608;
 ELSIF NEW.mime_type LIKE 'audio/%' THEN v_kind:='audio';allowed:=12582912;
 ELSIF NEW.mime_type LIKE 'video/%' THEN v_kind:='video';allowed:=25165824;
 ELSE v_kind:='document';allowed:=16777216; END IF;
 IF NEW.byte_size>allowed THEN
  RAISE EXCEPTION 'File exceeds the % MB category limit',(allowed/1048576); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.conversations c
   WHERE c.id=NEW.conversation_id
    AND (c.owner_id=auth.uid() OR c.peer_id=auth.uid())
    AND NOT public.blocked_pair(c.owner_id,c.peer_id)
    AND EXISTS(SELECT 1 FROM public.profiles p
      WHERE p.id=CASE WHEN c.owner_id=auth.uid()
        THEN c.peer_id ELSE c.owner_id END
        AND NOT p.suspended AND p.adult_self_attested_at IS NOT NULL))
   THEN RAISE EXCEPTION 'Conversation cannot receive attachments'; END IF;
 IF v_kind<>'document' AND NOT EXISTS(
   SELECT 1 FROM public.conversations c
     JOIN public.profiles a ON a.id=c.owner_id
     JOIN public.profiles b ON b.id=c.peer_id
   WHERE c.id=NEW.conversation_id AND a.allow_media_messages
     AND b.allow_media_messages AND NOT a.suspended AND NOT b.suspended
 ) THEN RAISE EXCEPTION 'Both people must enable media in Settings'; END IF;
 RETURN NEW;
END $fn$;
COMMIT;