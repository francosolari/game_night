begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

set search_path = public, extensions;

select plan(6);

insert into users (id, phone_number, display_name)
values
    ('00000000-0000-0000-0000-000000000001', '+15550000001', 'Host User'),
    ('00000000-0000-0000-0000-000000000002', '+15550000002', 'Guest User');

insert into events (
    id,
    host_id,
    title,
    description,
    location,
    status,
    allow_time_suggestions,
    min_players
) values (
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'Policy Test Event',
    'Event used to verify invite access policies.',
    'Brooklyn',
    'published',
    true,
    2
);

insert into time_options (
    id,
    event_id,
    date,
    start_time,
    end_time,
    label
) values (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    date '2026-03-20',
    timestamptz '2026-03-20 19:00:00+00',
    timestamptz '2026-03-20 22:00:00+00',
    'Friday night'
);

insert into invites (
    id,
    event_id,
    user_id,
    phone_number,
    display_name,
    status,
    tier,
    tier_position,
    is_active
) values (
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    '+15550000002',
    'Guest User',
    'pending',
    1,
    0,
    true
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select is(
    (select count(*)::int from events where id = '10000000-0000-0000-0000-000000000001'),
    1,
    'host can read an event before any access rows are needed'
);

select lives_ok(
    $$
        select 1
        from invites
        where event_id = '10000000-0000-0000-0000-000000000001'
    $$,
    'host can read invites without recursive policy evaluation'
);

select lives_ok(
    $$
        insert into event_participants (
            id,
            event_id,
            user_id,
            source_invite_id,
            role,
            rsvp_status,
            phone_number_snapshot
        ) values (
            '40000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000001',
            '00000000-0000-0000-0000-000000000002',
            '30000000-0000-0000-0000-000000000001',
            'guest',
            'pending',
            '+15550000002'
        )
    $$,
    'host can materialize authenticated participant access without using invites as the access boundary'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select is(
    (select count(*)::int from events where id = '10000000-0000-0000-0000-000000000001'),
    1,
    'invited authenticated guest can read the event through participant access'
);

select is(
    (select count(*)::int from time_options where event_id = '10000000-0000-0000-0000-000000000001'),
    1,
    'invited authenticated guest can read event time options through participant access'
);

select lives_ok(
    $$
        insert into time_option_votes (
            id,
            time_option_id,
            event_participant_id
        ) values (
            '50000000-0000-0000-0000-000000000001',
            '20000000-0000-0000-0000-000000000001',
            '40000000-0000-0000-0000-000000000001'
        )
    $$,
    'participants can cast time-option votes without invite-based ownership'
);

select * from finish();
rollback;
