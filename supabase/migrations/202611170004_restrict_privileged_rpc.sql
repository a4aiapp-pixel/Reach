-- Restrict privileged Reach RPC functions to signed-in users.
-- Trigger functions are never intended as callable API endpoints.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as signature, p.prorettype = 'pg_catalog.trigger'::regtype as is_trigger
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.signature);
    if not f.is_trigger then
      execute format('grant execute on function %s to authenticated', f.signature);
    end if;
  end loop;
end $$;