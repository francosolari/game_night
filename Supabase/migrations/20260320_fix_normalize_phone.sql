-- Fix normalize_phone to canonicalize 10-digit US numbers to 11 digits
-- so that "+1XXXXXXXXXX" (E.164) and "XXXXXXXXXX" (raw 10-digit) resolve to the same value.
--
-- Before: normalize_phone('9546080345')  = '9546080345'  (10 digits)
--          normalize_phone('+19546080345') = '19546080345' (11 digits) → MISMATCH
-- After:  both return '19546080345'

CREATE OR REPLACE FUNCTION normalize_phone(input text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN length(regexp_replace(coalesce(input, ''), '\D', '', 'g')) = 10
    THEN '1' || regexp_replace(coalesce(input, ''), '\D', '', 'g')
    ELSE regexp_replace(coalesce(input, ''), '\D', '', 'g')
  END
$$;

-- Normalize any existing invites stored as raw 10-digit numbers to E.164 (+1XXXXXXXXXX)
-- so they match how Supabase Auth stores phone numbers.
UPDATE invites
SET phone_number = '+1' || regexp_replace(phone_number, '\D', '', 'g')
WHERE length(regexp_replace(phone_number, '\D', '', 'g')) = 10;

-- Re-run auto-link: assign user_id on invites whose phone now matches a user account
UPDATE invites i
SET user_id = u.id
FROM users u
WHERE i.user_id IS NULL
  AND normalize_phone(i.phone_number) = normalize_phone(u.phone_number);
