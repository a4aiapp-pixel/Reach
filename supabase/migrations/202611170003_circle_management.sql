-- Circle owner controls; delete removes posts and membership in that circle.
create or replace function public.delete_circle(p_circle uuid) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not exists(select 1 from public.circles where id=p_circle and owner_id=auth.uid()) then
    raise exception 'Only the circle owner can delete this circle';
  end if;
  delete from public.circles where id=p_circle and owner_id=auth.uid();
end $$;
revoke all on function public.delete_circle(uuid) from public;
grant execute on function public.delete_circle(uuid) to authenticated;
