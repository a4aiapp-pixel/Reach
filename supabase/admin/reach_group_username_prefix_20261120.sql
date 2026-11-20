BEGIN;
CREATE OR REPLACE FUNCTION public.reach_add_group_member(p_circle uuid, p_identity text, p_invite_only boolean DEFAULT false)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'pg_temp'
AS $function$
DECLARE me uuid:=auth.uid(); target public.profiles; identity_text text;
  is_email boolean; limit_count int; new_invite uuid; circle_row public.circles;
BEGIN
 IF me IS NULL THEN RAISE EXCEPTION 'Sign in to invite people'; END IF;
 SELECT * INTO circle_row FROM public.circles
  WHERE id=p_circle AND owner_id=me FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Only the group owner can add or invite people'; END IF;
 IF (SELECT count(*) FROM public.reach_group_invitations
    WHERE inviter_id=me AND created_at>now()-interval '24 hours')>=15 THEN
  RAISE EXCEPTION 'Invitation limit reached for today'; END IF;
 identity_text:=left(btrim(coalesce(p_identity,'')),254);
 -- Accept friendly @username without misclassifying it as an email.
 IF left(identity_text,1)='@' AND strpos(substring(identity_text from 2),'@')=0 THEN
   identity_text:=substring(identity_text from 2);
 END IF;
 IF char_length(identity_text)<3 THEN RAISE EXCEPTION 'Enter a member ID, username or email'; END IF;
 is_email:=strpos(identity_text,'@')>0;
 IF is_email THEN
   SELECT p.* INTO target FROM public.profiles p
     JOIN auth.users u ON u.id=p.id
     WHERE lower(u.email)=lower(identity_text) LIMIT 1;
 ELSIF identity_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
   SELECT * INTO target FROM public.profiles p WHERE p.id=identity_text::uuid;
 ELSE
   SELECT * INTO target FROM public.profiles p
     WHERE lower(p.username)=lower(identity_text) LIMIT 1;
 END IF;
 IF NOT FOUND OR target.id=me OR target.suspended
    OR target.adult_self_attested_at IS NULL
    OR target.terms_accepted_at IS NULL
    OR NOT target.allow_group_invites
    OR public.blocked_pair(me,target.id) THEN
   RETURN 'submitted';
 END IF;
 IF EXISTS(SELECT 1 FROM public.circle_members
    WHERE circle_id=p_circle AND user_id=target.id) THEN
   RETURN CASE WHEN is_email THEN 'submitted' ELSE 'already_member' END;
 END IF;
 IF (SELECT count(*) FROM public.circle_members WHERE circle_id=p_circle)>=250 THEN
   RAISE EXCEPTION 'Group is full'; END IF;
 IF NOT p_invite_only AND target.allow_group_direct_add THEN
   IF (SELECT count(*) FROM public.circle_members WHERE user_id=target.id)>=50 THEN
     RETURN 'submitted'; END IF;
   INSERT INTO public.circle_members(circle_id,user_id) VALUES(p_circle,target.id)
     ON CONFLICT DO NOTHING;
   INSERT INTO public.alerts(user_id,title,body,related_id)
     VALUES(target.id,'You joined a group',
       'You were added to "'||left(circle_row.name,65)||'".',p_circle);
   RETURN CASE WHEN is_email THEN 'submitted' ELSE 'added' END;
 END IF;
 INSERT INTO public.reach_group_invitations(circle_id,target_id,inviter_id)
   VALUES(p_circle,target.id,me)
   ON CONFLICT(circle_id,target_id) DO UPDATE
     SET status='pending',inviter_id=excluded.inviter_id,
       created_at=now(),expires_at=now()+interval '14 days',decided_at=NULL
     WHERE public.reach_group_invitations.status<>'pending'
       OR public.reach_group_invitations.expires_at<now()
   RETURNING id INTO new_invite;
 IF new_invite IS NOT NULL THEN
   INSERT INTO public.alerts(user_id,title,body,related_id)
     VALUES(target.id,'New group invitation',
      'You have been invited to "'||left(circle_row.name,65)||'".',p_circle);
 END IF;
 RETURN CASE WHEN is_email THEN 'submitted' ELSE 'invited' END;
END $function$
;
COMMIT;