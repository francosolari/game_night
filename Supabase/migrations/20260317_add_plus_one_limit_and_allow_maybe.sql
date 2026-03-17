ALTER TABLE events
  ADD COLUMN plus_one_limit integer NOT NULL DEFAULT 0,
  ADD COLUMN allow_maybe_rsvp boolean NOT NULL DEFAULT true,
  ADD COLUMN require_plus_one_names boolean NOT NULL DEFAULT false;
