-- Ensure older clients cannot leave orphaned Storage objects by
-- deleting Auth users without first removing chat attachment bytes.
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp AS $$
BEGIN
 IF auth.uid() IS NULL THEN
   RAISE EXCEPTION 'Not signed in';
 END IF;
 IF EXISTS (SELECT 1 FROM public.chat_attachments
            WHERE sender_id=auth.uid()) THEN
   RAISE EXCEPTION 'Delete your private chat attachments using the current Reach app or web deletion portal before deleting your account';
 END IF;
 DELETE FROM auth.users WHERE id=auth.uid();
END $$;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
