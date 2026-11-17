-- Administrator runbook; execute in Supabase SQL Editor only, not from client.
-- Never expose service_role keys in the mobile app.
-- Pending reports (reference post/user/message ID in target_id):
select r.id,r.created_at,r.reason,r.detail,r.target_type,r.target_id,r.reporter_id,
       r.status from public.reports r where r.status in ('open','reviewing')
order by r.created_at asc limit 100;
-- Example updates after documented review (replace UUID):
-- update public.reports set status='reviewing' where id='REPORT_UUID';
-- update public.reports set status='resolved' where id='REPORT_UUID';
-- update public.profiles set suspended=true where id='USER_UUID';
-- update public.reaches set status='closed' where id='POST_UUID';
-- Expose a monitored reports review process before launch.
