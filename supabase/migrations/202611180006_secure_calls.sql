-- Reach opt-in 1:1 WebRTC signaling, enabled in client only by release flag.
-- Every invitation, acceptance and signaling write is validated in PostgreSQL.
CREATE TABLE public.reach_calls(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  caller_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  callee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK(kind IN ('audio','video')),
  status text NOT NULL DEFAULT 'ringing'
    CHECK(status IN ('ringing','accepted','declined','cancelled','ended','missed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT(now()+interval '45 seconds'),
  answered_at timestamptz,
  ended_at timestamptz,
  CHECK(caller_id<>callee_id)
);
CREATE INDEX reach_calls_caller_recent ON public.reach_calls(caller_id,created_at DESC);
CREATE INDEX reach_calls_receiver_recent ON public.reach_calls(callee_id,created_at DESC);
CREATE INDEX reach_calls_conversation_recent ON public.reach_calls(conversation_id,created_at DESC);
CREATE UNIQUE INDEX reach_calls_one_live_conversation
  ON public.reach_calls(conversation_id) WHERE status IN ('ringing','accepted');
ALTER TABLE public.reach_calls ENABLE ROW LEVEL SECURITY;
CREATE POLICY reach_call_visible ON public.reach_calls
 FOR SELECT TO authenticated
 USING((caller_id=auth.uid() OR callee_id=auth.uid())
   AND NOT public.blocked_pair(caller_id,callee_id));
REVOKE ALL ON public.reach_calls FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.reach_calls TO authenticated;

CREATE TABLE public.reach_call_signals (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 call_id uuid NOT NULL REFERENCES public.reach_calls(id) ON DELETE CASCADE,
 sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 signal_type text NOT NULL CHECK(signal_type IN ('offer','answer','candidate')),
 payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object'
   AND length(payload::text) BETWEEN 2 AND 32768),
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(sender_id<>receiver_id)
);
CREATE INDEX reach_call_signals_by_call ON public.reach_call_signals(call_id,id);
CREATE INDEX reach_call_signals_expire ON public.reach_call_signals(created_at);
ALTER TABLE public.reach_call_signals ENABLE ROW LEVEL SECURITY;
CREATE POLICY reach_call_signal_read ON public.reach_call_signals
 FOR SELECT TO authenticated
 USING((sender_id=auth.uid() OR receiver_id=auth.uid())
   AND EXISTS (SELECT 1 FROM public.reach_calls c WHERE c.id=call_id
     AND NOT public.blocked_pair(c.caller_id,c.callee_id)));
CREATE POLICY reach_call_signal_insert ON public.reach_call_signals
 FOR INSERT TO authenticated
 WITH CHECK(sender_id=auth.uid() AND EXISTS(
  SELECT 1 FROM public.reach_calls c
  WHERE c.id=call_id AND c.status='accepted'
    AND c.answered_at>now()-interval '2 hours'
    AND ((c.caller_id=sender_id AND c.callee_id=receiver_id)
      OR (c.callee_id=sender_id AND c.caller_id=receiver_id))
    AND NOT public.blocked_pair(c.caller_id,c.callee_id)));
REVOKE ALL ON public.reach_call_signals FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT ON public.reach_call_signals TO authenticated;
GRANT USAGE,SELECT ON SEQUENCE public.reach_call_signals_id_seq TO authenticated;

CREATE OR REPLACE FUNCTION public.guard_reach_call_signal()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path=pg_catalog,pg_temp AS $$
DECLARE total int;
BEGIN
 IF new.sender_id IS DISTINCT FROM auth.uid()
   OR new.created_at < now() - interval '1 minute'
   OR new.created_at > now()+interval '1 minute' THEN
   RAISE EXCEPTION 'Invalid signaling sender';
 END IF;
 -- Prevent unlimited ICE floods or malicious oversized SDP records.
 PERFORM pg_advisory_xact_lock(hashtextextended(new.call_id::text,2213));
 SELECT count(*) INTO total FROM public.reach_call_signals
  WHERE call_id=new.call_id;
 IF total >= 160 THEN RAISE EXCEPTION 'Call signaling limit reached'; END IF;
 IF new.signal_type IN ('offer','answer') AND
    EXISTS(SELECT 1 FROM public.reach_call_signals
      WHERE call_id=new.call_id AND signal_type=new.signal_type) THEN
   RAISE EXCEPTION 'Call negotiation already submitted';
 END IF;
 RETURN new;
END $$;
CREATE TRIGGER reach_call_signal_guard BEFORE INSERT ON public.reach_call_signals
 FOR EACH ROW EXECUTE FUNCTION public.guard_reach_call_signal();

-- Only these RPCs mutate call state; callers cannot self-accept or replay
-- a declined invitation. Privileged functions validate the authenticated id.
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
    AND answered_at<now()-interval '2 hours';
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
REVOKE ALL ON FUNCTION public.start_reach_call(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.start_reach_call(uuid,text) TO authenticated;

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
   UPDATE public.reach_calls SET status='accepted',answered_at=now(),
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
REVOKE ALL ON FUNCTION public.answer_reach_call(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.answer_reach_call(uuid,text) TO authenticated;

DO $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime'
  AND schemaname='public' AND tablename='reach_calls') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reach_calls;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime'
  AND schemaname='public' AND tablename='reach_call_signals') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reach_call_signals;
 END IF;
END $$;
