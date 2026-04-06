-- Harden auth signup trigger function by pinning search_path.
-- Prevents accidental resolution against attacker-controlled schemas.

alter function public.handle_new_user()
  security definer
  set search_path = public;
