-- Reach private attachments: supervised QA capability with explicit two-sided
-- media opt-in, strict MIME/type/quotas, report quarantine & no public URLs.
-- This is not an automated media-content scanner.
BEGIN;
ALTER TABLE public.chat_attachments
 DROP CONSTRAINT IF EXISTS chat_attachments_byte_size_check;
ALTER TABLE public.chat_attachments
 ADD CONSTRAINT chat_attachments_byte_size_check
  CHECK(byte_size BETWEEN 1 AND 25165824);
ALTER TABLE public.chat_attachments
 DROP CONSTRAINT IF EXISTS chat_attachments_status_check;
ALTER TABLE public.chat_attachments
 ADD CONSTRAINT chat_attachments_status_check
  CHECK(status IN ('pending','ready','quarantined'));

UPDATE storage.buckets SET file_size_limit=25165824,
 allowed_mime_types=ARRAY[
 'application/pdf','text/plain','text/csv','application/msword',
 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
 'application/vnd.ms-excel',
 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
 'application/vnd.ms-powerpoint',
 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
 'image/jpeg','image/png','image/webp','image/gif',
 'audio/mpeg','audio/mp4','audio/aac','audio/ogg','audio/wav',
 'video/mp4','video/quicktime','video/webm'
 ]::text[]
 WHERE id='reach-chat';

CREATE OR REPLACE FUNCTION reach_private.guard_sensitive_attachments()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE v_kind text; allowed int; peer uuid;
BEGIN
 IF auth.uid() IS NULL OR NEW.sender_id<>auth.uid() THEN
  RAISE EXCEPTION 'Only the signed-in sender may upload'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid()
   AND p.adult_self_attested_at IS NOT NULL AND p.terms_accepted_at IS NOT NULL
   AND NOT p.suspended) THEN
   RAISE EXCEPTION 'Complete account eligibility before sharing files'; END IF;
 IF reach_private.reach_text_violation(NEW.file_name) IS NOT NULL THEN
  RAISE EXCEPTION 'File name violates Reach safety rules'; END IF;
 IF NEW.mime_type LIKE 'image/%' THEN
  v_kind:='image';allowed:=8388608;
 ELSIF NEW.mime_type LIKE 'audio/%' THEN
  v_kind:='audio';allowed:=12582912;
 ELSIF NEW.mime_type LIKE 'video/%' THEN
  v_kind:='video';allowed:=25165824;
 ELSE v_kind:='document';allowed:=16777216;
 END IF;
 IF NEW.byte_size>allowed THEN
  RAISE EXCEPTION 'File exceeds the % MB limit for this category',
   (allowed/1048576); END IF;
 IF NOT EXISTS(
   SELECT 1 FROM public.conversations c
   WHERE c.id=NEW.conversation_id
     AND (c.owner_id=auth.uid() OR c.peer_id=auth.uid())
     AND NOT public.blocked_pair(c.owner_id,c.peer_id)
     AND EXISTS(SELECT 1 FROM public.profiles p
       WHERE p.id=CASE WHEN c.owner_id=auth.uid()
         THEN c.peer_id ELSE c.owner_id END
         AND NOT p.suspended AND p.adult_self_attested_at IS NOT NULL)
 ) THEN RAISE EXCEPTION 'This conversation cannot receive attachments'; END IF;
 IF v_kind<>'document' THEN
   IF NOT EXISTS(SELECT 1 FROM public.conversations c
      JOIN public.profiles first_person ON first_person.id=c.owner_id
      JOIN public.profiles second_person ON second_person.id=c.peer_id
      WHERE c.id=NEW.conversation_id
        AND first_person.allow_media_messages
        AND second_person.allow_media_messages
        AND NOT first_person.suspended AND NOT second_person.suspended) THEN
     RAISE EXCEPTION 'Both members must enable private media in Settings'; END IF;
 END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION reach_private.guard_sensitive_attachments()
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.guard_chat_attachment()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
 SET search_path=pg_catalog,pg_temp AS $fn$
DECLARE n int; bytes_total bigint;
BEGIN
 IF new.sender_id IS DISTINCT FROM auth.uid() THEN
  RAISE EXCEPTION 'Authenticated sender required'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(new.sender_id::text,2917));
 SELECT count(*) INTO n FROM public.chat_attachments a
  WHERE a.sender_id=new.sender_id
   AND a.created_at>now()-interval '24 hours';
 SELECT coalesce(sum(a.byte_size),0) INTO bytes_total
  FROM public.chat_attachments a WHERE a.sender_id=new.sender_id;
 IF n>=20 OR bytes_total+new.byte_size>83886080 THEN
  RAISE EXCEPTION 'Private file storage limit reached. Remove old files.'; END IF;
 RETURN new;
END $fn$;

-- Storage access is restricted to sender and actual conversation peer.
-- Never leak content simply because an attachment object path was guessed.
DROP POLICY IF EXISTS reach_chat_object_read ON storage.objects;
CREATE POLICY reach_chat_object_read ON storage.objects FOR SELECT
 TO authenticated
 USING(bucket_id='reach-chat' AND EXISTS(
  SELECT 1 FROM public.chat_attachments a
  JOIN public.conversations c ON c.id=a.conversation_id
  WHERE a.object_path=objects.name
    AND (c.owner_id=auth.uid() OR c.peer_id=auth.uid())
    AND NOT public.blocked_pair(c.owner_id,c.peer_id)
    AND (a.sender_id=auth.uid() OR a.status='ready')
 ));

CREATE OR REPLACE FUNCTION reach_private.quarantine_reported_chat_media()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,pg_temp AS $fn$
BEGIN
 IF NEW.target_type='attachment' THEN
  UPDATE public.chat_attachments a
    SET status='quarantined'
   WHERE a.id=NEW.target_id AND a.sender_id<>NEW.reporter_id;
 END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION reach_private.quarantine_reported_chat_media()
 FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reach_quarantine_reported_media ON public.reports;
CREATE TRIGGER reach_quarantine_reported_media
 AFTER INSERT ON public.reports FOR EACH ROW
 EXECUTE FUNCTION reach_private.quarantine_reported_chat_media();
COMMIT;