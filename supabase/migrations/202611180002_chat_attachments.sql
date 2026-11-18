-- Reach 1:1 chat attachments: private, participant-only, bounded free-tier usage.
-- Untrusted files are never executed, rendered as HTML, or exposed via public URLs.
INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
VALUES ('reach-chat','reach-chat',false,6291456,ARRAY[
  'application/pdf','text/plain','text/csv',
  'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'image/jpeg','image/png','image/webp','image/gif',
  'audio/mpeg','audio/mp4','audio/aac','audio/ogg','audio/wav','audio/x-wav',
  'video/mp4','video/quicktime','video/webm'
])
ON CONFLICT (id) DO UPDATE
SET public=false,file_size_limit=EXCLUDED.file_size_limit,
    allowed_mime_types=EXCLUDED.allowed_mime_types;

CREATE TABLE public.chat_attachments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
 sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 object_path text NOT NULL UNIQUE,
 file_name text NOT NULL,
 mime_type text NOT NULL,
 byte_size int NOT NULL CHECK(byte_size BETWEEN 1 AND 6291456),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','ready')),
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT reach_chat_name_safe CHECK (
  length(file_name) BETWEEN 1 AND 180
  AND strpos(file_name,'/') = 0
  AND strpos(file_name,chr(92)) = 0
  AND lower(file_name) ~ '[.](pdf|txt|csv|doc|docx|xls|xlsx|ppt|pptx|jpg|jpeg|png|webp|gif|mp3|m4a|aac|ogg|wav|mp4|mov|webm)$'
 ),
 CONSTRAINT reach_chat_object_path CHECK (
  length(object_path) <= 410 AND
  split_part(object_path,'/',1)=conversation_id::text
  AND split_part(object_path,'/',2)=sender_id::text
  AND split_part(object_path,'/',3) ~ '^[a-f0-9]{32}$'
  AND split_part(object_path,'/',4) ~ '^[a-zA-Z0-9_.-]{1,120}$'
  AND split_part(object_path,'/',5)=''
 )
);
CREATE INDEX chat_attachments_conversation_timeline
 ON public.chat_attachments(conversation_id,created_at DESC);
CREATE INDEX chat_attachments_sender_quota
 ON public.chat_attachments(sender_id,created_at);

-- Require a bounded number of files and bytes per verified member.
-- Advisory lock ensures concurrent uploads don't bypass the quota check.
CREATE OR REPLACE FUNCTION public.guard_chat_attachment()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, pg_temp AS $$
DECLARE n int; bytes_total bigint;
BEGIN
 IF new.sender_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Authenticated member required';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(new.sender_id::text, 2917));
 SELECT count(*) INTO n FROM public.chat_attachments
 WHERE sender_id=new.sender_id AND created_at>now()-interval '24 hours';
 SELECT coalesce(sum(byte_size),0) INTO bytes_total FROM public.chat_attachments
 WHERE sender_id=new.sender_id;
 IF n >= 15 OR bytes_total + new.byte_size > 52428800 THEN
   RAISE EXCEPTION 'Attachment quota reached. Remove old files or try later.';
 END IF;
 RETURN new;
END $$;
CREATE TRIGGER guard_chat_attachment BEFORE INSERT ON public.chat_attachments
FOR EACH ROW EXECUTE FUNCTION public.guard_chat_attachment();

ALTER TABLE public.chat_attachments ENABLE ROW LEVEL SECURITY;
CREATE POLICY chat_attachment_read ON public.chat_attachments FOR SELECT TO authenticated
USING (
 sender_id=auth.uid()
 OR (status='ready' AND EXISTS (
  SELECT 1 FROM public.conversations c
  WHERE c.id=conversation_id
  AND (c.owner_id=auth.uid() OR c.peer_id=auth.uid())
  AND NOT public.blocked_pair(c.owner_id,c.peer_id)))
);
CREATE POLICY chat_attachment_insert ON public.chat_attachments FOR INSERT TO authenticated
WITH CHECK (
 sender_id=auth.uid() AND
 EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND NOT p.suspended)
 AND EXISTS(
  SELECT 1 FROM public.conversations c WHERE c.id=conversation_id
  AND (c.owner_id=auth.uid() OR c.peer_id=auth.uid())
  AND NOT public.blocked_pair(c.owner_id,c.peer_id)
 )
);
CREATE POLICY chat_attachment_update ON public.chat_attachments FOR UPDATE TO authenticated
USING (sender_id=auth.uid() AND status='pending')
WITH CHECK (sender_id=auth.uid() AND status='ready');
CREATE POLICY chat_attachment_delete ON public.chat_attachments FOR DELETE TO authenticated
USING (sender_id=auth.uid());
REVOKE ALL ON public.chat_attachments FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,DELETE ON public.chat_attachments TO authenticated;
GRANT UPDATE(status) ON public.chat_attachments TO authenticated;

CREATE POLICY reach_chat_object_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
 bucket_id='reach-chat' AND EXISTS(
  SELECT 1 FROM public.chat_attachments a WHERE a.object_path=name
   AND a.status='pending' AND a.sender_id=auth.uid()
 ));
CREATE POLICY reach_chat_object_read ON storage.objects FOR SELECT TO authenticated
USING (
 bucket_id='reach-chat' AND EXISTS(
  SELECT 1 FROM public.chat_attachments a WHERE a.object_path=name
   AND (a.sender_id=auth.uid() OR a.status='ready')
 ));
CREATE POLICY reach_chat_object_delete ON storage.objects FOR DELETE TO authenticated
USING (
 bucket_id='reach-chat' AND EXISTS(
  SELECT 1 FROM public.chat_attachments a WHERE a.object_path=name
   AND a.sender_id=auth.uid()
 ));

-- Realtime feeds only the RLS-authorized users.
DO $$
BEGIN
 IF NOT EXISTS (
  SELECT 1 FROM pg_publication_tables
  WHERE pubname='supabase_realtime' AND schemaname='public'
    AND tablename='chat_attachments'
 ) THEN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_attachments;
 END IF;
END $$;
