-- Bench promotion tracking: add promoted_at and promoted_from_tier to invites

alter table invites
    add column if not exists promoted_at timestamptz,
    add column if not exists promoted_from_tier integer;
