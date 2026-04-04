-- Support dual APNs environments (sandbox for debug, production for TestFlight/App Store)
-- and route pushes per token.

alter table push_tokens
    add column if not exists apns_environment text;

-- Bias existing rows to production so current TestFlight users work immediately.
update push_tokens
set apns_environment = 'production'
where apns_environment is null;

alter table push_tokens
    alter column apns_environment set default 'production';

alter table push_tokens
    alter column apns_environment set not null;

alter table push_tokens
    drop constraint if exists push_tokens_apns_environment_check;

alter table push_tokens
    add constraint push_tokens_apns_environment_check
    check (apns_environment in ('sandbox', 'production'));

alter table push_tokens
    drop constraint if exists push_tokens_user_id_device_token_key;

alter table push_tokens
    add constraint push_tokens_user_id_device_token_apns_environment_key
    unique (user_id, device_token, apns_environment);
