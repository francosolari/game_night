-- Function to mark past events as completed.
-- An event is "past" when its effective end date has passed:
--   - If a confirmed_time_option_id is set, use that time option's end_time (or end of start day)
--   - Otherwise, use the latest end_time across all time options (or end of latest start day)
-- Only transitions published/confirmed events. Drafts, cancelled, and already-completed are untouched.
CREATE OR REPLACE FUNCTION complete_past_events()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  affected integer;
BEGIN
  WITH past_events AS (
    SELECT e.id
    FROM events e
    WHERE e.status IN ('published', 'confirmed')
      AND e.deleted_at IS NULL
      AND EXISTS (
        SELECT 1 FROM time_options t WHERE t.event_id = e.id
      )
      AND (
        -- If event has a confirmed time option, check that one
        (e.confirmed_time_option_id IS NOT NULL AND (
          SELECT COALESCE(t.end_time, (t.start_time::date + interval '1 day' - interval '1 second'))
          FROM time_options t
          WHERE t.id = e.confirmed_time_option_id
        ) < now())
        OR
        -- Otherwise, check the latest time option
        (e.confirmed_time_option_id IS NULL AND (
          SELECT MAX(COALESCE(t.end_time, (t.start_time::date + interval '1 day' - interval '1 second')))
          FROM time_options t
          WHERE t.event_id = e.id
        ) < now())
      )
  )
  UPDATE events
  SET status = 'completed'
  WHERE id IN (SELECT id FROM past_events);

  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;
