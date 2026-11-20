-- Moderation extensions for member-only group communications. Never allow
-- reporting inaccessible content or self-authored messages/resources.
BEGIN;
CREATE OR REPLACE FUNCTION public.guard_report_abuse()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE me uuid:=auth.uid();
BEGIN
 IF me IS NULL OR new.reporter_id IS DISTINCT FROM me THEN
  RAISE EXCEPTION 'Authenticated reporter required'; END IF;
 IF new.target_id IS NULL THEN RAISE EXCEPTION 'A report target is required'; END IF;
 IF new.target_type NOT IN ('post','user','message','group','attachment','group_message','group_resource')
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
 ELSIF new.target_type='group_message' THEN
  IF NOT EXISTS(
    SELECT 1 FROM public.reach_group_messages m
    WHERE m.id=new.target_id AND m.sender_id<>me
      AND public.is_circle_member(m.circle_id)
  ) THEN RAISE EXCEPTION 'Group message unavailable or not reportable'; END IF;
 ELSIF new.target_type='group_resource' THEN
  IF NOT EXISTS(
    SELECT 1 FROM public.reach_group_resources r
    WHERE r.id=new.target_id AND r.creator_id<>me
      AND public.is_circle_member(r.circle_id)
  ) THEN RAISE EXCEPTION 'Group resource unavailable or not reportable'; END IF;
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
END $function$
;
COMMIT;