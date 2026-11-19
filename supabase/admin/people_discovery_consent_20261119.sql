-- Reach opt-in member directory, age attestation, personal contacts and calling consent.
-- Existing accounts are private/not discoverable and cannot receive calls by default.
-- A birth date is validated for age and NEVER persisted. This is self-attestation,
-- not independent ID verification. Public list returns only explicitly allowed fields.

BEGIN;
ALTER TABLE public.profiles
 ADD COLUMN IF NOT EXISTS people_discoverable boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS profile_visibility text NOT NULL DEFAULT 'private',
 ADD COLUMN IF NOT EXISTS allow_calls boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS adult_self_attested_at timestamptz;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS reach_profile_visibility_check;
ALTER TABLE public.profiles ADD CONSTRAINT reach_profile_visibility_check
 CHECK(profile_visibility IN ('private','public'));
GRANT UPDATE(people_discoverable,profile_visibility,allow_calls)
 ON public.profiles TO authenticated;

-- A general SELECT of raw profiles was exposing private bios, locations and
-- preferences. Own-row SELECT only; directory is explicitly filtered by RPC.
DROP POLICY IF EXISTS profile_read ON public.profiles;
CREATE POLICY profile_read ON public.profiles
 FOR SELECT TO authenticated USING(id=(SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.reach_confirm_adult(p_birth_date date)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $fn$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in before age confirmation'; END IF;
 IF p_birth_date IS NULL OR p_birth_date > (current_date-interval '18 years')::date
 OR p_birth_date < (current_date-interval '115 years')::date THEN
   RAISE EXCEPTION 'Reach requires members to be at least 18 years old';
 END IF;
 UPDATE public.profiles
 SET adult_self_attested_at=COALESCE(adult_self_attested_at,now())
 WHERE id=auth.uid() AND terms_accepted_at IS NOT NULL AND NOT suspended;
 IF NOT FOUND THEN RAISE EXCEPTION 'Complete your profile and accept the rules first'; END IF;
 RETURN true;
END $fn$;
REVOKE ALL ON FUNCTION public.reach_confirm_adult(date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_confirm_adult(date) TO authenticated;

CREATE TABLE IF NOT EXISTS public.member_connections(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 message text NOT NULL CHECK(length(btrim(message)) BETWEEN 2 AND 400),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','declined')),
 conversation_id uuid REFERENCES public.conversations(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 answered_at timestamptz,
 CHECK(sender_id<>recipient_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS member_connections_pair_unique
 ON public.member_connections(LEAST(sender_id,recipient_id),GREATEST(sender_id,recipient_id));
CREATE INDEX IF NOT EXISTS member_connections_received
 ON public.member_connections(recipient_id,created_at DESC);
ALTER TABLE public.member_connections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS member_connections_read ON public.member_connections;
CREATE POLICY member_connections_read ON public.member_connections
 FOR SELECT TO authenticated
 USING((sender_id=auth.uid() OR recipient_id=auth.uid())
  AND NOT public.blocked_pair(sender_id,recipient_id));
REVOKE ALL ON public.member_connections FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.member_connections TO authenticated;

-- Direct contacts use existing private chat, without fabricated public posts.
ALTER TABLE public.conversations ALTER COLUMN post_id DROP NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS reach_direct_conversation_pair
 ON public.conversations(LEAST(owner_id,peer_id),GREATEST(owner_id,peer_id))
 WHERE post_id IS NULL;

CREATE OR REPLACE FUNCTION public.reach_discover_people(
 p_area text DEFAULT 'city',p_query text DEFAULT '')
RETURNS TABLE(id uuid,username text,display_name text,city text,country text,
 profile_visibility text,bio text,skills text[],connection_status text,
 conversation_id uuid)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE me public.profiles%ROWTYPE; needle text;
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
  COALESCE(mc.status,'none'),
  CASE WHEN mc.status='accepted' THEN mc.conversation_id ELSE NULL::uuid END
 FROM public.profiles p
 LEFT JOIN public.member_connections mc
  ON ((mc.sender_id=auth.uid() AND mc.recipient_id=p.id)
   OR (mc.recipient_id=auth.uid() AND mc.sender_id=p.id))
 WHERE p.id<>auth.uid() AND p.people_discoverable
  AND p.adult_self_attested_at IS NOT NULL
  AND p.terms_accepted_at IS NOT NULL AND NOT p.suspended
  AND NOT public.blocked_pair(p.id,auth.uid())
  AND (needle='' OR strpos(lower(coalesce(p.username,'')),lower(needle))>0
   OR strpos(lower(p.display_name),lower(needle))>0)
  AND (CASE p_area WHEN 'city'
    THEN p.city<>'' AND lower(btrim(p.city))=lower(btrim(me.city))
     AND lower(btrim(p.country))=lower(btrim(me.country))
   WHEN 'country' THEN p.country<>'' AND lower(btrim(p.country))=lower(btrim(me.country))
   ELSE true END)
 ORDER BY p.display_name,p.username LIMIT 40;
END $fn$;
REVOKE ALL ON FUNCTION public.reach_discover_people(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_discover_people(text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.reach_request_member(p_recipient uuid,p_message text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE me uuid:=auth.uid(); request_id uuid; intro text:=btrim(coalesce(p_message,''));
BEGIN
 IF me IS NULL OR p_recipient IS NULL OR p_recipient=me THEN
   RAISE EXCEPTION 'Invalid connection request'; END IF;
 IF NOT public.reach_account_eligible(me,interval '10 minutes')
 OR NOT EXISTS(SELECT 1 FROM public.profiles p
  WHERE p.id=me AND p.adult_self_attested_at IS NOT NULL) THEN
   RAISE EXCEPTION 'Confirm email and adult eligibility before connecting';
 END IF;
 IF char_length(intro) NOT BETWEEN 2 AND 400 THEN
   RAISE EXCEPTION 'Please write a brief introduction of 2–400 characters'; END IF;
 IF public.blocked_pair(me,p_recipient)
 OR NOT EXISTS(SELECT 1 FROM public.profiles p
   WHERE p.id=p_recipient AND p.people_discoverable
    AND p.adult_self_attested_at IS NOT NULL
    AND p.terms_accepted_at IS NOT NULL AND NOT p.suspended) THEN
   RAISE EXCEPTION 'This member is not accepting discovery requests'; END IF;
 IF EXISTS(SELECT 1 FROM public.member_connections c
   WHERE (c.sender_id=me AND c.recipient_id=p_recipient)
      OR (c.sender_id=p_recipient AND c.recipient_id=me)) THEN
   RAISE EXCEPTION 'A connection request or decision already exists'; END IF;
 IF (SELECT count(*) FROM public.member_connections c
    WHERE c.sender_id=me AND c.created_at>now()-interval '1 hour')>=10
 OR EXISTS(SELECT 1 FROM public.member_connections c
    WHERE c.sender_id=me AND c.created_at>now()-interval '30 seconds') THEN
   RAISE EXCEPTION 'Please wait before contacting more people'; END IF;
 INSERT INTO public.member_connections(sender_id,recipient_id,message)
 VALUES(me,p_recipient,intro) RETURNING id INTO request_id;
 INSERT INTO public.alerts(user_id,title,body,related_id)
 VALUES(p_recipient,'New member request','A member has requested to connect',request_id);
 RETURN request_id;
END $fn$;
REVOKE ALL ON FUNCTION public.reach_request_member(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_request_member(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.reach_answer_member(p_request uuid,p_accept boolean)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE row_data public.member_connections%ROWTYPE; chat_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in first'; END IF;
 SELECT * INTO row_data FROM public.member_connections
  WHERE id=p_request FOR UPDATE;
 IF NOT FOUND OR row_data.recipient_id<>auth.uid() OR row_data.status<>'pending'
 OR public.blocked_pair(row_data.sender_id,row_data.recipient_id) THEN
   RAISE EXCEPTION 'Request unavailable'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles
     WHERE id=auth.uid() AND adult_self_attested_at IS NOT NULL
      AND NOT suspended) THEN
   RAISE EXCEPTION 'Confirm adult eligibility before accepting'; END IF;
 IF p_accept THEN
   INSERT INTO public.conversations(post_id,owner_id,peer_id)
   VALUES(NULL,row_data.recipient_id,row_data.sender_id)
   ON CONFLICT DO NOTHING;
   SELECT c.id INTO chat_id FROM public.conversations c
    WHERE c.post_id IS NULL AND
     LEAST(c.owner_id,c.peer_id)=LEAST(row_data.sender_id,row_data.recipient_id)
     AND GREATEST(c.owner_id,c.peer_id)=GREATEST(row_data.sender_id,row_data.recipient_id)
    LIMIT 1;
   IF chat_id IS NULL THEN RAISE EXCEPTION 'Unable to open private chat'; END IF;
 END IF;
 UPDATE public.member_connections
 SET status=(CASE WHEN p_accept THEN 'accepted' ELSE 'declined' END),
   answered_at=now(),conversation_id=chat_id
 WHERE id=p_request;
 INSERT INTO public.alerts(user_id,title,body,related_id)
 VALUES(row_data.sender_id,
   CASE WHEN p_accept THEN 'Member connection accepted' ELSE 'Member connection declined' END,
   CASE WHEN p_accept THEN 'You can now start a private chat' ELSE 'The member declined your request' END,
   p_request);
 RETURN chat_id;
END $fn$;
REVOKE ALL ON FUNCTION public.reach_answer_member(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_answer_member(uuid,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.reach_member_requests()
RETURNS TABLE(id uuid,peer_id uuid,peer_name text,peer_username text,
 message text,status text,incoming boolean,conversation_id uuid,created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $fn$
 SELECT c.id,peer.id,peer.display_name,peer.username,c.message,c.status,
   (c.recipient_id=auth.uid()),c.conversation_id,c.created_at
 FROM public.member_connections c
 JOIN public.profiles peer ON peer.id=
   CASE WHEN c.sender_id=auth.uid() THEN c.recipient_id ELSE c.sender_id END
 WHERE auth.uid() IN (c.sender_id,c.recipient_id)
  AND NOT public.blocked_pair(c.sender_id,c.recipient_id)
 ORDER BY c.created_at DESC LIMIT 80;
$fn$;
REVOKE ALL ON FUNCTION public.reach_member_requests() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_member_requests() TO authenticated;

-- Replace only the listing function. Existing post-backed conversations remain.
CREATE OR REPLACE FUNCTION public.my_conversations()
RETURNS TABLE(id uuid,post_title text,peer_id uuid,peer_name text,
 last_body text,last_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $fn$
 SELECT c.id,coalesce(r.title,'Direct connection'),
 CASE WHEN c.owner_id=auth.uid() THEN c.peer_id ELSE c.owner_id END,
 p.display_name,coalesce(m.body,''),coalesce(m.created_at,c.created_at)
 FROM public.conversations c
 LEFT JOIN public.reaches r ON r.id=c.post_id
 JOIN public.profiles p ON p.id=
   (CASE WHEN c.owner_id=auth.uid() THEN c.peer_id ELSE c.owner_id END)
 LEFT JOIN LATERAL (SELECT body,created_at FROM public.messages
  WHERE conversation_id=c.id ORDER BY created_at DESC LIMIT 1) m ON true
 WHERE (c.owner_id=auth.uid() OR c.peer_id=auth.uid())
  AND NOT public.blocked_pair(c.owner_id,c.peer_id)
 ORDER BY coalesce(m.created_at,c.created_at) DESC LIMIT 100;
$fn$;
REVOKE ALL ON FUNCTION public.my_conversations() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.my_conversations() TO authenticated;

-- Even if a client bypasses the UI, both parties must have enabled calls.
CREATE OR REPLACE FUNCTION reach_private.require_mutual_call_consent()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $fn$
BEGIN
 IF new.status IN ('ringing','accepted') AND
   (TG_OP='INSERT' OR new.status IS DISTINCT FROM old.status) THEN
   IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=new.caller_id
    AND p.allow_calls AND p.adult_self_attested_at IS NOT NULL AND NOT p.suspended)
   OR NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=new.callee_id
    AND p.allow_calls AND p.adult_self_attested_at IS NOT NULL AND NOT p.suspended) THEN
     RAISE EXCEPTION 'Both members must enable calling first';
   END IF;
 END IF;
 RETURN new;
END $fn$;
REVOKE ALL ON FUNCTION reach_private.require_mutual_call_consent()
 FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reach_mutual_call_consent ON public.reach_calls;
CREATE TRIGGER reach_mutual_call_consent BEFORE INSERT OR UPDATE OF status
 ON public.reach_calls FOR EACH ROW
 EXECUTE FUNCTION reach_private.require_mutual_call_consent();

CREATE OR REPLACE FUNCTION reach_private.end_calls_after_opt_out()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $fn$
BEGIN
 IF old.allow_calls AND NOT new.allow_calls THEN
   UPDATE public.reach_calls SET status='ended',ended_at=now()
    WHERE status IN ('ringing','accepted')
      AND (caller_id=new.id OR callee_id=new.id);
 END IF;
 RETURN new;
END $fn$;
REVOKE ALL ON FUNCTION reach_private.end_calls_after_opt_out()
 FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reach_end_calls_opt_out ON public.profiles;
CREATE TRIGGER reach_end_calls_opt_out AFTER UPDATE OF allow_calls
 ON public.profiles FOR EACH ROW
 EXECUTE FUNCTION reach_private.end_calls_after_opt_out();

CREATE OR REPLACE FUNCTION public.reach_can_call(p_peer uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $fn$
 SELECT auth.uid() IS NOT NULL AND p_peer IS NOT NULL AND
 EXISTS(SELECT 1 FROM public.conversations c
  WHERE (c.owner_id=auth.uid() AND c.peer_id=p_peer)
    OR (c.peer_id=auth.uid() AND c.owner_id=p_peer))
 AND NOT public.blocked_pair(auth.uid(),p_peer)
 AND EXISTS(SELECT 1 FROM public.profiles p
  WHERE p.id=auth.uid() AND p.allow_calls AND p.adult_self_attested_at IS NOT NULL
    AND NOT p.suspended)
 AND EXISTS(SELECT 1 FROM public.profiles p
  WHERE p.id=p_peer AND p.allow_calls AND p.adult_self_attested_at IS NOT NULL
   AND NOT p.suspended);
$fn$;
REVOKE ALL ON FUNCTION public.reach_can_call(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_can_call(uuid) TO authenticated;

COMMIT;
