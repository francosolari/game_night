-- Ensure confirm_time_option keeps definer privileges and stable search_path.
-- This restores security semantics after function body replacements.

alter function public.confirm_time_option(uuid, uuid)
  security definer;

alter function public.confirm_time_option(uuid, uuid)
  set search_path = public;

revoke all on function public.confirm_time_option(uuid, uuid) from public, anon;
grant execute on function public.confirm_time_option(uuid, uuid) to authenticated;
