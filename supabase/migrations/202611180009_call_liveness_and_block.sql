-- Prevent crash-orphaned active calls from blocking reconnect/new calls.
ALTER TABLE public.reach_calls
  ADD COLUMN IF NOT EXISTS last_heartbeat_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.start_reach_call(p_conversation uuid,p_kind text)
RETURNS public.reach_calls LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $$
DECLARE me uuid:=auth.uid(); convo public.conversations%ROWTYPE;
        recipient uuid; result public.reach_calls%ROWTYPE; hourly int; peer10 int;
BEGIN
 IF me IS NULL OR p_kind NOT IN ('audio','video') THEN
   RAISE EXCEPTION 'Invalid call request';
 END IF;
 -- Serializes concurrent calls from opposite participants in the same chat.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_conversation::text,9911));
 SELECT * INTO convo FROM public.conversations WHERE id=p_conversation;
 IF NOT FOUND OR (convo.owner_id<>me AND convo.peer_id<>me) THEN
   RAISE EXCEPTION 'Conversation not available';
 END IF;
 recipient:=CASE WHEN convo.owner_id=me THEN convo.peer_id ELSE convo.owner_id END;
 IF public.blocked_pair(me,recipient) OR
   EXISTS(SELECT 1 FROM public.profiles p WHERE p.id IN (me,recipient) AND p.suspended) THEN
   RAISE EXCEPTION 'Calling unavailable for this connection';
 END IF;
 -- Expire abandoned invites; do not leave unique index permanently locked.
 UPDATE public.reach_calls SET status='missed',ended_at=now()
  WHERE conversation_id=p_conversation AND status='ringing' AND expires_at<now();
 UPDATE public.reach_calls SET status='ended',ended_at=now()
  WHERE conversation_id=p_conversation AND status='accepted'
    AND (answered_at<now()-interval '2 hours' OR last_heartbeat_at<now()-interval '100 seconds');
 SELECT count(*) INTO hourly FROM public.reach_calls
   WHERE caller_id=me AND created_at>now()-interval '1 hour';
 SELECT count(*) INTO peer10 FROM public.reach_calls
   WHERE caller_id=me AND callee_id=recipient
     AND created_at>now()-interval '10 minutes';
 IF hourly>=12 OR peer10>=3 THEN
   RAISE EXCEPTION 'Call request limit reached. Try later';
 END IF;
 IF EXISTS(SELECT 1 FROM public.reach_calls
   WHERE conversation_id=p_conversation AND status IN ('ringing','accepted')) THEN
   RAISE EXCEPTION 'There is already a call in this conversation';
 END IF;
 INSERT INTO public.reach_calls(conversation_id,caller_id,callee_id,kind)
 VALUES(p_conversation,me,recipient,p_kind) RETURNING * INTO result;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.answer_reach_call(p_call uuid,p_action text)
RETURNS public.reach_calls LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $$
DECLARE me uuid:=auth.uid(); cur public.reach_calls%ROWTYPE;
BEGIN
 IF me IS NULL OR p_action NOT IN ('accept','decline','cancel','end') THEN
   RAISE EXCEPTION 'Invalid call action';
 END IF;
 SELECT * INTO cur FROM public.reach_calls WHERE id=p_call FOR UPDATE;
 IF NOT FOUND OR (cur.caller_id<>me AND cur.callee_id<>me) THEN
   RAISE EXCEPTION 'Call unavailable';
 END IF;
 IF public.blocked_pair(cur.caller_id,cur.callee_id) THEN
   RAISE EXCEPTION 'Call unavailable';
 END IF;
 IF cur.status='ringing' AND cur.expires_at<now() THEN
   UPDATE public.reach_calls SET status='missed',ended_at=now()
    WHERE id=p_call RETURNING * INTO cur;
   RETURN cur;
 END IF;
 IF p_action='accept' AND cur.callee_id=me AND cur.status='ringing' THEN
   UPDATE public.reach_calls SET status='accepted',answered_at=now(),last_heartbeat_at=now(),
     expires_at=now()+interval '2 hours'
    WHERE id=p_call RETURNING * INTO cur;
 ELSIF p_action='decline' AND cur.callee_id=me AND cur.status='ringing' THEN
   UPDATE public.reach_calls SET status='declined',ended_at=now()
    WHERE id=p_call RETURNING * INTO cur;
 ELSIF p_action='cancel' AND cur.caller_id=me AND cur.status='ringing' THEN
   UPDATE public.reach_calls SET status='cancelled',ended_at=now()
    WHERE id=p_call RETURNING * INTO cur;
 ELSIF p_action='end' AND cur.status='accepted' THEN
   UPDATE public.reach_calls SET status='ended',ended_at=now()
    WHERE id=p_call RETURNING * INTO cur;
 ELSE
   RAISE EXCEPTION 'Call state changed. Refresh the conversation';
 END IF;
 RETURN cur;
END $$;


-- The only client-permitted heartbeat mutation; do not expose other updates.
CREATE OR REPLACE FUNCTION public.heartbeat_reach_call(p_call uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $function$
DECLARE me uuid := auth.uid();
BEGIN
 IF me IS NULL THEN RETURN false; END IF;
 UPDATE public.reach_calls
  SET last_heartbeat_at=now()
  WHERE id=p_call AND status='accepted'
    AND (caller_id=me OR callee_id=me)
    AND answered_at > now()-interval '2 hours'
    AND NOT public.blocked_pair(caller_id,callee_id)
    AND NOT EXISTS(
      SELECT 1 FROM public.profiles p
       WHERE p.id IN (caller_id,callee_id) AND p.suspended
    );
 RETURN found;
END $function$;
REVOKE ALL ON FUNCTION public.heartbeat_reach_call(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.heartbeat_reach_call(uuid) TO authenticated;

-- Blocking must also end all currently active or ringing calls in storage,
-- not merely hide buttons for the person who blocked.
CREATE OR REPLACE FUNCTION reach_private.close_reach_calls_after_block()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $function$
BEGIN
 UPDATE public.reach_calls SET status='ended',ended_at=now()
  WHERE status IN ('ringing','accepted')
    AND (
      (caller_id=new.blocker_id AND callee_id=new.blocked_id)
      OR (caller_id=new.blocked_id AND callee_id=new.blocker_id)
    );
 RETURN new;
END $function$;
REVOKE ALL ON FUNCTION reach_private.close_reach_calls_after_block() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reach_close_calls_on_block ON public.blocks;
CREATE TRIGGER reach_close_calls_on_block
 AFTER INSERT ON public.blocks
 FOR EACH ROW EXECUTE FUNCTION reach_private.close_reach_calls_after_block();
