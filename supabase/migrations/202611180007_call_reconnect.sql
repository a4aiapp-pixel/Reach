-- Enable bounded, participant-authenticated WebRTC ICE renegotiation.
-- Both offerers and answerers are fixed by the original call roles.
ALTER TABLE public.reach_call_signals
  DROP CONSTRAINT reach_call_signals_signal_type_check;
ALTER TABLE public.reach_call_signals
  ADD CONSTRAINT reach_call_signals_signal_type_check
  CHECK(signal_type IN ('offer','answer','candidate','restart_offer','restart_answer','quality'));
CREATE OR REPLACE FUNCTION public.guard_reach_call_signal()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path=pg_catalog,pg_temp AS $$
DECLARE total int; same_type int; party public.reach_calls%ROWTYPE;
BEGIN
  IF new.sender_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Authenticated sender required';
  END IF;
  new.created_at := now();
  SELECT * INTO party FROM public.reach_calls WHERE id=new.call_id;
  IF NOT FOUND OR party.status<>'accepted'
      OR (party.answered_at IS NOT NULL
       AND party.answered_at<now()-interval '2 hours')
      OR NOT (
        (new.sender_id=party.caller_id AND new.receiver_id=party.callee_id)
        OR (new.sender_id=party.callee_id AND new.receiver_id=party.caller_id)
      ) THEN
    RAISE EXCEPTION 'Invalid call signal recipients';
  END IF;
  IF new.signal_type IN ('offer','restart_offer')
      AND new.sender_id<>party.caller_id THEN
    RAISE EXCEPTION 'Only caller may offer';
  END IF;
  IF new.signal_type IN ('answer','restart_answer')
      AND new.sender_id<>party.callee_id THEN
    RAISE EXCEPTION 'Only callee may answer';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(new.call_id::text,2213));
  SELECT count(*),count(*) FILTER (WHERE signal_type=new.signal_type)
    INTO total,same_type
    FROM public.reach_call_signals WHERE call_id=new.call_id;
  IF total>=200 THEN RAISE EXCEPTION 'Call signal limit reached'; END IF;
  IF new.signal_type IN ('offer','answer') AND same_type>=1 THEN
    RAISE EXCEPTION 'Initial call negotiation already submitted';
  END IF;
  IF new.signal_type IN ('restart_offer','restart_answer') AND same_type>=6 THEN
    RAISE EXCEPTION 'Too many call reconnect attempts';
  END IF;
  IF new.signal_type='quality' AND same_type>=20 THEN
    RAISE EXCEPTION 'Too many quality change messages';
  END IF;
  RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.guard_reach_call_signal() FROM PUBLIC,anon;
