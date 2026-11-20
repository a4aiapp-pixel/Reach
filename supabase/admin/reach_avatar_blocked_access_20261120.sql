BEGIN;
DROP POLICY IF EXISTS reach_avatars_read ON storage.objects;
CREATE POLICY reach_avatars_read ON storage.objects
 FOR SELECT TO authenticated
 USING (
   bucket_id='reach-avatars'
   AND EXISTS (
     SELECT 1 FROM public.profiles p
       WHERE p.id=split_part(name,'/',1)::uuid
       AND (
         p.id=auth.uid()
         OR (
           NOT public.blocked_pair(p.id,auth.uid())
           AND (
             (p.profile_visibility='public' AND p.people_discoverable)
             OR EXISTS(
               SELECT 1 FROM public.member_connections mc
               WHERE mc.status='accepted'
                 AND ((mc.sender_id=auth.uid() AND mc.recipient_id=p.id)
                    OR(mc.recipient_id=auth.uid() AND mc.sender_id=p.id)))
             OR EXISTS (
               SELECT 1 FROM public.circle_members a
               JOIN public.circle_members b ON b.circle_id=a.circle_id
               WHERE a.user_id=auth.uid() AND b.user_id=p.id)
           )
         )
       )
   )
 );
COMMIT;