-- Live foreground alerts for Reach. Database-side changes require no Firebase credentials.
-- Safe to rerun. The alerts_read RLS policy limits rows to auth.uid().
-- Do NOT grant anon SELECT or bypass existing RLS on public.alerts.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime'
      AND schemaname='public' AND tablename='alerts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.alerts;
  END IF;
END $$;

-- Verification:
-- SELECT EXISTS (SELECT 1 FROM pg_publication_tables
--   WHERE pubname='supabase_realtime' AND schemaname='public'
--     AND tablename='alerts') AS enabled;
