-- Add timezone persistence to users so reminders can be evaluated at local noon.
alter table users
    add column if not exists time_zone_identifier text;

-- Extend notifications type check with play log reminder type.
alter table notifications
    drop constraint if exists notifications_type_check;

alter table notifications
    add constraint notifications_type_check
    check (type in (
        'invite_received', 'rsvp_update', 'group_invite',
        'time_confirmed', 'bench_promoted', 'dm_received',
        'text_blast', 'game_confirmed', 'event_cancelled',
        'play_log_reminder'
    ));

-- Inserts one reminder per user/event at noon local time on the day after the event ended,
-- only when nobody has logged any play for that event yet.
create or replace function notify_unlogged_play_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    inserted_count integer := 0;
begin
    with completed_events as (
        select
            e.id as event_id,
            e.title as event_title,
            e.host_id,
            case
                when e.confirmed_time_option_id is not null then (
                    select coalesce(t.end_time, (t.start_time::date + interval '1 day'))
                    from time_options t
                    where t.id = e.confirmed_time_option_id
                )
                else (
                    select max(coalesce(t.end_time, (t.start_time::date + interval '1 day')))
                    from time_options t
                    where t.event_id = e.id
                )
            end as effective_end_at
        from events e
        where e.status = 'completed'
          and e.deleted_at is null
    ),
    recipients as (
        select
            ce.event_id,
            ce.event_title,
            ce.effective_end_at,
            ce.host_id as user_id
        from completed_events ce
        where ce.host_id is not null

        union

        select
            ce.event_id,
            ce.event_title,
            ce.effective_end_at,
            i.user_id
        from completed_events ce
        join invites i on i.event_id = ce.event_id
        where i.user_id is not null
          and i.status in ('accepted', 'maybe', 'voted')
    ),
    localized as (
        select
            r.event_id,
            r.event_title,
            r.user_id,
            r.effective_end_at,
            coalesce(tz.name, 'UTC') as time_zone_identifier,
            (
                (
                    ((r.effective_end_at at time zone coalesce(tz.name, 'UTC'))::date + 1)
                    + time '12:00'
                ) at time zone coalesce(tz.name, 'UTC')
            ) as reminder_at_utc
        from recipients r
        join users u on u.id = r.user_id
        left join pg_timezone_names tz on tz.name = u.time_zone_identifier
        where r.effective_end_at is not null
    ),
    due as (
        select
            l.event_id,
            l.event_title,
            l.user_id,
            l.time_zone_identifier,
            l.reminder_at_utc
        from localized l
        where now() >= l.reminder_at_utc
          and not exists (
              select 1
              from plays p
              where p.event_id = l.event_id
          )
          and not exists (
              select 1
              from notifications n
              where n.user_id = l.user_id
                and n.event_id = l.event_id
                and n.type = 'play_log_reminder'
          )
    ),
    inserted as (
        insert into notifications (user_id, type, title, body, event_id, metadata)
        select
            d.user_id,
            'play_log_reminder',
            'Log plays for ' || d.event_title,
            'No one has logged this event yet. One person can log the group play.',
            d.event_id,
            jsonb_build_object(
                'time_zone_identifier', d.time_zone_identifier,
                'reminder_at_utc', d.reminder_at_utc
            )
        from due d
        returning 1
    )
    select count(*) into inserted_count from inserted;

    return inserted_count;
end;
$$;

revoke execute on function notify_unlogged_play_reminders() from public, anon;
grant execute on function notify_unlogged_play_reminders() to authenticated, service_role;

-- Best-effort scheduling: run every 10 minutes if pg_cron is available.
do $do$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        begin
            perform cron.unschedule(jobid)
            from cron.job
            where jobname = 'notify-unlogged-play-reminders';
        exception
            when undefined_table then
                null;
        end;

        perform cron.schedule(
            'notify-unlogged-play-reminders',
            '*/10 * * * *',
            $sql$select public.notify_unlogged_play_reminders();$sql$
        );
    end if;
exception
    when insufficient_privilege then
        raise notice 'Skipping pg_cron schedule for play-log reminders: insufficient privilege';
    when undefined_function then
        raise notice 'Skipping pg_cron schedule for play-log reminders: cron functions unavailable';
end;
$do$;
