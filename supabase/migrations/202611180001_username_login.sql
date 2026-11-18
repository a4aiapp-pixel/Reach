-- Reach: unique usernames and server-side throttling for username/password sign-in.
-- Email/password authentication continues through Supabase Auth unchanged.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username text;
ALTER TABLE public.profiles ADD CONSTRAINT reach_username_format
  CHECK (username IS NULL OR username ~ '^[a-z][a-z0-9_]{2,23}$');
CREATE UNIQUE INDEX IF NOT EXISTS reach_username_unique ON public.profiles (username);
GRANT UPDATE (username) ON public.profiles TO authenticated;

-- A signup username is validated and reserved atomically with user creation.
-- An invalid/duplicate username rejects registration instead of creating a
-- partial profile. Existing accounts remain valid with NULL usernames.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE requested_username text;
BEGIN
  requested_username := lower(btrim(coalesce(new.raw_user_meta_data->>'username','')));
  IF requested_username = '' THEN requested_username := NULL; END IF;
  IF requested_username IS NOT NULL AND
     requested_username !~ '^[a-z][a-z0-9_]{2,23}$' THEN
    RAISE EXCEPTION 'Invalid username';
  END IF;
  INSERT INTO public.profiles(id,display_name,username)
  VALUES (new.id,left(coalesce(new.raw_user_meta_data->>'display_name',''),80),requested_username)
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END $$;

-- These counters are not exposed via the Data API. Passwords and emails
-- are never stored in this table; identifier/IP values are one-way hashes.
CREATE SCHEMA IF NOT EXISTS reach_private;
REVOKE ALL ON SCHEMA reach_private FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS reach_private.username_login_throttle (
  key text PRIMARY KEY,
  window_start timestamptz NOT NULL DEFAULT now(),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0)
);
ALTER TABLE reach_private.username_login_throttle ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS username_throttle_window_idx
  ON reach_private.username_login_throttle(window_start);

-- Only the backend service role can consume a login slot.
CREATE OR REPLACE FUNCTION public.consume_username_login_slot(
  p_username text, p_remote_addr text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
DECLARE handle_attempts int; remote_attempts int;
BEGIN
  IF p_username IS NULL OR length(p_username) NOT BETWEEN 3 AND 24
     OR p_remote_addr IS NULL OR length(p_remote_addr) > 128 THEN
    RETURN false;
  END IF;

  INSERT INTO reach_private.username_login_throttle AS t (key,window_start,attempts)
  VALUES (encode(extensions.digest('handle:' || lower(p_username),'sha256'),'hex'), now(), 1)
  ON CONFLICT (key) DO UPDATE SET
    attempts = CASE WHEN t.window_start < now() - interval '15 minutes'
      THEN 1 ELSE t.attempts + 1 END,
    window_start = CASE WHEN t.window_start < now() - interval '15 minutes'
      THEN now() ELSE t.window_start END
  RETURNING attempts INTO handle_attempts;

  INSERT INTO reach_private.username_login_throttle AS t (key,window_start,attempts)
  VALUES (encode(extensions.digest('remote:' || p_remote_addr,'sha256'),'hex'), now(), 1)
  ON CONFLICT (key) DO UPDATE SET
    attempts = CASE WHEN t.window_start < now() - interval '15 minutes'
      THEN 1 ELSE t.attempts + 1 END,
    window_start = CASE WHEN t.window_start < now() - interval '15 minutes'
      THEN now() ELSE t.window_start END
  RETURNING attempts INTO remote_attempts;

  RETURN handle_attempts <= 7 AND remote_attempts <= 60;
END $$;
REVOKE ALL ON FUNCTION public.consume_username_login_slot(text,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_username_login_slot(text,text)
  TO service_role;
