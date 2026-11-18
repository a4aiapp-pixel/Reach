-- Reach Assist: authenticated AI usage caps. No prompts or model replies stored.
-- The model provider must be explicitly enabled separately; this migration
-- does not authorize spending money or expose client-side API credentials.
CREATE TABLE IF NOT EXISTS reach_private.ai_request_quota(
 quota_key text NOT NULL,
 day date NOT NULL,
 requests integer NOT NULL DEFAULT 0,
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(quota_key,day),
 CONSTRAINT ai_requests_positive CHECK(requests>=0)
);
ALTER TABLE reach_private.ai_request_quota ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON reach_private.ai_request_quota FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.consume_reach_ai_slot(
 p_user uuid,p_network text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,pg_temp AS $$
DECLARE token text; recordcount integer; entry record;
BEGIN
 IF p_user IS NULL OR p_network IS NULL OR length(p_network)>128 THEN
  RETURN false;
 END IF;
 IF NOT EXISTS(
  SELECT 1 FROM auth.users u
  JOIN public.profiles p ON p.id=u.id
  WHERE u.id=p_user AND u.email_confirmed_at IS NOT NULL AND NOT p.suspended
 ) THEN
  RETURN false;
 END IF;
 -- Serialize quota increments across all three buckets.
 PERFORM pg_advisory_xact_lock(845116241);
 FOR entry IN
  SELECT k.key, k.maximum FROM (VALUES
    ('user:'||p_user::text,8),
    ('network:'||encode(extensions.digest(p_network,'sha256'),'hex'),35),
    ('global',160)
  ) AS k(key,maximum)
 LOOP
  INSERT INTO reach_private.ai_request_quota AS q(quota_key,day,requests)
  VALUES(entry.key,current_date,1)
  ON CONFLICT(quota_key,day) DO UPDATE
    SET requests=q.requests+1,updated_at=now()
  RETURNING requests INTO recordcount;
  IF recordcount>entry.maximum THEN
   RETURN false;
  END IF;
 END LOOP;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.consume_reach_ai_slot(uuid,text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.consume_reach_ai_slot(uuid,text)
 TO service_role;

-- Prevent daily quota rows from growing indefinitely.
CREATE INDEX IF NOT EXISTS ai_request_quota_by_day
 ON reach_private.ai_request_quota(day);
