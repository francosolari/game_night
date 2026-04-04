-- Fix RLS violation when host confirms time and function inserts notifications for invitees.
-- confirm_time_option must run with definer privileges for cross-user notification inserts.

alter function public.confirm_time_option(uuid, uuid) security definer;

revoke all on function public.confirm_time_option(uuid, uuid) from public, anon;
grant execute on function public.confirm_time_option(uuid, uuid) to authenticated;
