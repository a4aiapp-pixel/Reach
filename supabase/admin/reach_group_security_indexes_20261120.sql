-- Reach v1.2 integrated security/performance hardening.
-- Keep member-only resources inaccessible to blocked peers even in shared groups.
BEGIN;
DROP POLICY IF EXISTS rgm_read_members ON public.reach_group_messages;
CREATE POLICY rgm_read_members
 ON public.reach_group_messages FOR SELECT TO authenticated
 USING(
  public.is_circle_member(circle_id)
  AND (sender_id=(select auth.uid())
    OR NOT public.blocked_pair(sender_id,(select auth.uid())))
 );
DROP POLICY IF EXISTS rgr_read_members ON public.reach_group_resources;
CREATE POLICY rgr_read_members
 ON public.reach_group_resources FOR SELECT TO authenticated
 USING(
  public.is_circle_member(circle_id)
  AND (creator_id=(select auth.uid())
    OR NOT public.blocked_pair(creator_id,(select auth.uid())))
 );
-- Low-overhead, targeted indexes supporting group roster, join and call directories.
CREATE INDEX IF NOT EXISTS reach_circle_members_by_user
 ON public.circle_members(user_id,joined_at DESC);
CREATE INDEX IF NOT EXISTS reach_circle_created_by_owner
 ON public.circles(owner_id,created_at DESC);
CREATE INDEX IF NOT EXISTS reach_conversation_owner_recent
 ON public.conversations(owner_id,created_at DESC);
CREATE INDEX IF NOT EXISTS reach_conversation_peer_recent
 ON public.conversations(peer_id,created_at DESC);
COMMIT;