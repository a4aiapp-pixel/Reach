-- Reach zero-cost launch moderation. High-confidence illicit/sexual promotion,
-- dangerous instruction, and credential-theft patterns are blocked server-side.
-- Do NOT treat discussion of recovery, safety, education or medical care as prohibited.
-- Text heuristics are imperfect, and no visual-content scanner is deployed.
BEGIN;
CREATE SCHEMA IF NOT EXISTS reach_private;
CREATE OR REPLACE FUNCTION reach_private.reach_text_violation(p_text text)
RETURNS text LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER
SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE v text:=lower(regexp_replace(coalesce(p_text,''),'[[:space:]]+',' ','g'));
BEGIN
 IF char_length(v)>12000 THEN RETURN 'oversize'; END IF;
 IF v ~ '(child|minor|underage|teen)[[:space:]-]{0,12}(porn|nude(s)?|sex[[:space:]-]*(video|cam|image|photo))'
  OR v ~ '(^|[^a-z])(csam|child[[:space:]-]*pornography)([^a-z]|$)'
  THEN RETURN 'child_safety'; END IF;
 IF v ~ '(pornhub|xvideos|xhamster|live[[:space:]-]*sex[[:space:]-]*cam|sex[[:space:]-]*webcam|nude(s)?[[:space:]-]*(for[[:space:]-]*sale|video[[:space:]-]*group))'
  OR v ~ '(sell|buy|stream|share|join|watch|subscribe)[^.]{0,60}(porn(ography)?|explicit[[:space:]-]*sexual[[:space:]-]*(video|images|cams))'
  THEN RETURN 'sexual_content'; END IF;
 IF v ~ '(buy|sell|deliver|dealer|order|supply|ship)[^.]{0,55}(heroin|cocaine|meth(amphetamine)?|fentanyl|ecstasy|mdma|lsd)'
 OR v ~ '(heroin|cocaine|meth(amphetamine)?|fentanyl|ecstasy|mdma|lsd)[^.]{0,55}(for sale|buy now|delivery|supplier|dealer)'
 THEN RETURN 'illegal_trade'; END IF;
 IF v ~ '(how[[:space:]-]*to[[:space:]-]*(make|build)[^.]{0,25}(bomb|explosive)|sell[[:space:]-]*(explosives|bombs)|bomb[[:space:]-]*making[[:space:]-]*instructions)'
 THEN RETURN 'dangerous_acts'; END IF;
 IF v ~ '(send|share|give|forward)[^.]{0,35}(otp|one[[:space:]-]*time[[:space:]-]*password|bank[[:space:]-]*pin|verification[[:space:]-]*code|account[[:space:]-]*password)'
 THEN RETURN 'credential_theft'; END IF;
 IF v ~ '(how[[:space:]-]*to[[:space:]-]*kill[[:space:]-]*yourself|ways[[:space:]-]*to[[:space:]-]*commit[[:space:]-]*suicide)'
 THEN RETURN 'self_harm_instruction'; END IF;
 RETURN NULL;
END $fn$;
REVOKE ALL ON FUNCTION reach_private.reach_text_violation(text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION reach_private.guard_reach_text()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE supplied text; reason text;
BEGIN
 CASE TG_TABLE_NAME
  WHEN 'reaches' THEN supplied:=new.title || ' ' || new.detail;
  WHEN 'messages' THEN supplied:=new.body;
  WHEN 'circles' THEN supplied:=new.name || ' ' || new.category || ' ' || new.description;
  WHEN 'connection_requests' THEN supplied:=new.message;
  WHEN 'member_connections' THEN supplied:=new.message;
  WHEN 'profiles' THEN
    supplied:=new.display_name || ' ' || new.bio || ' ' || array_to_string(new.skills,' ');
  ELSE RETURN new;
 END CASE;
 reason:=reach_private.reach_text_violation(supplied);
 IF reason IS NOT NULL THEN
   RAISE EXCEPTION USING MESSAGE='Content blocked by Reach safety rules. Remove prohibited solicitation, media or instructions and try again.',
     ERRCODE='23514';
 END IF;
 IF TG_TABLE_NAME IN ('reaches','messages','circles',
                       'connection_requests','member_connections') THEN
   IF NOT EXISTS(SELECT 1 FROM public.profiles p
     WHERE p.id=auth.uid() AND p.adult_self_attested_at IS NOT NULL
       AND p.terms_accepted_at IS NOT NULL AND NOT p.suspended) THEN
     RAISE EXCEPTION 'Confirm adult eligibility before publishing or contacting others';
   END IF;
 END IF;
 RETURN new;
END $fn$;
REVOKE ALL ON FUNCTION reach_private.guard_reach_text() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reach_post_safety ON public.reaches;
CREATE TRIGGER reach_post_safety BEFORE INSERT OR UPDATE OF title,detail
 ON public.reaches FOR EACH ROW EXECUTE FUNCTION reach_private.guard_reach_text();
DROP TRIGGER IF EXISTS reach_chat_safety ON public.messages;
CREATE TRIGGER reach_chat_safety BEFORE INSERT OR UPDATE OF body
 ON public.messages FOR EACH ROW EXECUTE FUNCTION reach_private.guard_reach_text();
DROP TRIGGER IF EXISTS reach_group_safety ON public.circles;
CREATE TRIGGER reach_group_safety BEFORE INSERT OR UPDATE OF name,category,description
 ON public.circles FOR EACH ROW EXECUTE FUNCTION reach_private.guard_reach_text();
DROP TRIGGER IF EXISTS reach_request_safety ON public.connection_requests;
CREATE TRIGGER reach_request_safety BEFORE INSERT OR UPDATE OF message
 ON public.connection_requests FOR EACH ROW EXECUTE FUNCTION reach_private.guard_reach_text();
DROP TRIGGER IF EXISTS reach_member_request_safety ON public.member_connections;
CREATE TRIGGER reach_member_request_safety BEFORE INSERT OR UPDATE OF message
 ON public.member_connections FOR EACH ROW EXECUTE FUNCTION reach_private.guard_reach_text();
DROP TRIGGER IF EXISTS reach_profile_safety ON public.profiles;
CREATE TRIGGER reach_profile_safety BEFORE UPDATE OF display_name,bio,skills
 ON public.profiles FOR EACH ROW EXECUTE FUNCTION reach_private.guard_reach_text();

-- New launch attachments are documents only. Image/video/audio are temporarily
-- blocked until a proven media scanning/review provider is integrated. Neither
-- a MIME extension filter nor filename checks can inspect the file's contents.
CREATE OR REPLACE FUNCTION reach_private.guard_sensitive_attachments()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $fn$
BEGIN
 IF new.mime_type ~* '^(image|video|audio)/' OR
  lower(right(new.file_name,5)) ~ '(mp4|webm|jpeg|gif|png|webp|mov|mp3|wav)' THEN
   RAISE EXCEPTION 'Photos, audio and video sharing are unavailable until safety screening is enabled';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid()
   AND p.adult_self_attested_at IS NOT NULL AND NOT p.suspended) THEN
   RAISE EXCEPTION 'Confirm adult eligibility before sending attachments';
 END IF;
 IF reach_private.reach_text_violation(new.file_name) IS NOT NULL THEN
   RAISE EXCEPTION 'Unsafe attachment name';
 END IF;
 RETURN new;
END $fn$;
REVOKE ALL ON FUNCTION reach_private.guard_sensitive_attachments()
 FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reach_attachment_safety ON public.chat_attachments;
CREATE TRIGGER reach_attachment_safety BEFORE INSERT OR UPDATE OF status
 ON public.chat_attachments FOR EACH ROW
 EXECUTE FUNCTION reach_private.guard_sensitive_attachments();

-- MIME allowlist is enforced at Supabase Storage as a second layer.
UPDATE storage.buckets SET allowed_mime_types=ARRAY[
 'application/pdf','text/plain','text/csv',
 'application/msword',
 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
 'application/vnd.ms-excel',
 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
 'application/vnd.ms-powerpoint',
 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
] WHERE id='reach-chat';

-- Broaden reporting reasons and support reporting older unsafe attachments.
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_target_type_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_target_type_check
 CHECK (target_type IN ('post','user','message','group','attachment'));
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_reason_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_reason_check
 CHECK (reason IN ('spam','harassment','unsafe','fraud','other',
 'child_safety','sexual_exploitation','impersonation','illegal_content',
 'adult_content','dangerous_activities','self_harm'));

CREATE OR REPLACE FUNCTION public.guard_report_abuse()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $fn$
DECLARE me uuid:=auth.uid();
BEGIN
 IF me IS NULL OR new.reporter_id IS DISTINCT FROM me THEN
  RAISE EXCEPTION 'Authenticated reporter required'; END IF;
 IF new.target_id IS NULL THEN RAISE EXCEPTION 'A report target is required'; END IF;
 IF new.target_type NOT IN ('post','user','message','group','attachment')
 OR new.reason NOT IN ('spam','harassment','unsafe','fraud','other',
  'child_safety','sexual_exploitation','impersonation','illegal_content',
  'adult_content','dangerous_activities','self_harm') THEN
   RAISE EXCEPTION 'Unsupported report category'; END IF;
 new.created_at:=now();
 new.status:='open';
 IF new.target_type='user' THEN
  IF new.target_id=me OR NOT EXISTS(
   SELECT 1 FROM public.profiles WHERE id=new.target_id
  ) THEN RAISE EXCEPTION 'Member not reportable'; END IF;
 ELSIF new.target_type='post' THEN
  IF NOT EXISTS(SELECT 1 FROM public.reaches
    WHERE id=new.target_id) THEN RAISE EXCEPTION 'Post unavailable'; END IF;
 ELSIF new.target_type='group' THEN
  IF NOT EXISTS(SELECT 1 FROM public.circles WHERE id=new.target_id
    AND visibility='public' AND owner_id<>me) THEN
   RAISE EXCEPTION 'Group not reportable'; END IF;
 ELSIF new.target_type='message' THEN
  IF NOT EXISTS(SELECT 1 FROM public.messages m
   JOIN public.conversations c ON c.id=m.conversation_id
   WHERE m.id=new.target_id AND (c.owner_id=me OR c.peer_id=me)) THEN
   RAISE EXCEPTION 'Message unavailable'; END IF;
 ELSIF new.target_type='attachment' THEN
  IF NOT EXISTS(SELECT 1 FROM public.chat_attachments a
   JOIN public.conversations c ON c.id=a.conversation_id
   WHERE a.id=new.target_id AND a.sender_id<>me
    AND (c.owner_id=me OR c.peer_id=me)
    AND NOT public.blocked_pair(c.owner_id,c.peer_id)) THEN
   RAISE EXCEPTION 'Attachment unavailable'; END IF;
 END IF;
 IF (SELECT count(*) FROM public.reports
    WHERE reporter_id=me AND created_at>now()-interval '1 hour')>=10
 OR EXISTS(SELECT 1 FROM public.reports WHERE reporter_id=me
  AND target_type=new.target_type AND target_id=new.target_id
  AND created_at>now()-interval '24 hours') THEN
   RAISE EXCEPTION 'Report limit or duplicate report reached'; END IF;
 RETURN new;
END $fn$;
REVOKE ALL ON FUNCTION public.guard_report_abuse() FROM PUBLIC,anon,authenticated;

COMMIT;
