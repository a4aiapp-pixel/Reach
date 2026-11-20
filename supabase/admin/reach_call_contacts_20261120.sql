-- Lightweight one-request calling directory: no N serial can-call HTTP requests.
CREATE OR REPLACE FUNCTION public.reach_my_call_contacts()
RETURNS TABLE(id uuid,post_title text,peer_id uuid,peer_name text,
  can_call boolean)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $function$
 SELECT c.id,c.post_title,c.peer_id,c.peer_name,
   public.reach_can_call(c.peer_id)
 FROM public.my_conversations() c
 WHERE c.peer_id IS NOT NULL
 LIMIT 50;
$function$;
REVOKE ALL ON FUNCTION public.reach_my_call_contacts() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reach_my_call_contacts() TO authenticated;