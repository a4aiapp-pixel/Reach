-- Reach 2026-11-18 public-policy contact intake and report integrity.
-- Live Supabase migrations applied before this source mirror was committed.
-- Idempotent form allows later test/staging environment replay.
CREATE SCHEMA IF NOT EXISTS reach_private;

ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_reason_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_reason_check
  CHECK (reason IN ('spam','harassment','unsafe','fraud','other',
                   'child_safety','sexual_exploitation','impersonation'));

CREATE OR REPLACE FUNCTION public.guard_report_abuse()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE me uuid := auth.uid();
BEGIN
 IF me IS NULL OR new.reporter_id IS DISTINCT FROM me THEN
   RAISE EXCEPTION 'Authenticated reporter required';
 END IF;
 IF new.target_id IS NULL THEN RAISE EXCEPTION 'A report target is required'; END IF;
 IF new.target_type NOT IN ('post','user','message') THEN
   RAISE EXCEPTION 'Unsupported report target';
 END IF;
 IF new.reason NOT IN ('spam','harassment','unsafe','fraud','other',
                       'child_safety','sexual_exploitation','impersonation') THEN
   RAISE EXCEPTION 'Unsupported report category';
 END IF;
 new.created_at := now();
 new.status := 'open';
 IF new.target_type='user' THEN
   IF new.target_id=me OR NOT EXISTS (
     SELECT 1 FROM public.profiles WHERE id=new.target_id
   ) THEN RAISE EXCEPTION 'Member not reportable'; END IF;
 ELSIF new.target_type='post' THEN
   IF NOT EXISTS (SELECT 1 FROM public.reaches WHERE id=new.target_id)
   THEN RAISE EXCEPTION 'Post no longer available'; END IF;
 ELSIF new.target_type='message' THEN
   IF NOT EXISTS (
     SELECT 1 FROM public.messages m
     JOIN public.conversations c ON c.id=m.conversation_id
     WHERE m.id=new.target_id AND (c.owner_id=me OR c.peer_id=me)
   ) THEN RAISE EXCEPTION 'Message not available'; END IF;
 END IF;
 IF (SELECT count(*) FROM public.reports
     WHERE reporter_id=me AND created_at>now()-interval '1 hour')>=10 THEN
   RAISE EXCEPTION 'Report limit reached. Try again later';
 END IF;
 IF EXISTS(SELECT 1 FROM public.reports
    WHERE reporter_id=me AND target_type=new.target_type
      AND target_id=new.target_id AND created_at>now()-interval '24 hours') THEN
   RAISE EXCEPTION 'You have already reported this item';
 END IF;
 RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.guard_report_abuse() FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS reach_private.moderation_event_log(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 report_id uuid NOT NULL,
 previous_status text,
 new_status text NOT NULL,
 actor_id uuid,
 actor_role text NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE reach_private.moderation_event_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON reach_private.moderation_event_log FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE reach_private.moderation_event_log_id_seq FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION reach_private.audit_report_status_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog,pg_temp AS $$
BEGIN
 IF old.status IS DISTINCT FROM new.status THEN
   INSERT INTO reach_private.moderation_event_log
    (report_id,previous_status,new_status,actor_id,actor_role)
   VALUES (new.id,old.status,new.status,auth.uid(),session_user);
 END IF;
 RETURN new;
END $$;
REVOKE ALL ON FUNCTION reach_private.audit_report_status_change() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reach_report_status_audit ON public.reports;
CREATE TRIGGER reach_report_status_audit AFTER UPDATE OF status ON public.reports
FOR EACH ROW EXECUTE FUNCTION reach_private.audit_report_status_change();

CREATE TABLE IF NOT EXISTS public.reach_support_inbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 category text NOT NULL CHECK (category IN ('account','privacy','child_safety','abuse','technical','other')),
 email text NOT NULL CHECK (char_length(email) BETWEEN 6 AND 254),
 message text NOT NULL CHECK (char_length(message) BETWEEN 20 AND 1200),
 source_hash text NOT NULL CHECK (source_hash ~ '^[0-9a-f]{64}$'),
 received_at timestamptz NOT NULL DEFAULT now(),
 status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','reviewing','closed'))
);
ALTER TABLE public.reach_support_inbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.reach_support_inbox FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS reach_support_inbox_received ON public.reach_support_inbox(received_at DESC);
CREATE INDEX IF NOT EXISTS reach_support_inbox_rate ON public.reach_support_inbox(source_hash,received_at DESC);

CREATE OR REPLACE FUNCTION public.guard_reach_support_inbox()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $$
BEGIN
 NEW.received_at := now();
 NEW.status := 'new';
 IF (SELECT count(*) FROM public.reach_support_inbox
    WHERE received_at>now()-interval '24 hours') >=120 THEN
   RAISE EXCEPTION 'Contact form temporarily unavailable; retry later';
 END IF;
 IF (SELECT count(*) FROM public.reach_support_inbox
    WHERE source_hash=NEW.source_hash AND received_at>now()-interval '1 hour') >=3 THEN
   RAISE EXCEPTION 'Too many requests; retry later';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_reach_support_inbox() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reach_support_form_throttle ON public.reach_support_inbox;
CREATE TRIGGER reach_support_form_throttle BEFORE INSERT ON public.reach_support_inbox
FOR EACH ROW EXECUTE FUNCTION public.guard_reach_support_inbox();

COMMENT ON TABLE public.reach_support_inbox IS
  'Private operator-only public contact form inbox. Human moderation and retention required.';
