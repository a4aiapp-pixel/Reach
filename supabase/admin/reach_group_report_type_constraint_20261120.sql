-- The existing CHECK constraint must accept the same additional
-- report types as guard_report_abuse(). Without this, group reports fail.
BEGIN;
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_target_type_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_target_type_check
 CHECK (target_type IN (
 'post','user','message','group','attachment','group_message','group_resource'
 ));
COMMIT;