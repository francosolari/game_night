create or replace function public.add_game_to_collection(
    p_game_id uuid,
    p_category_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
    v_entry_id uuid;
begin
    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    insert into public.game_library (user_id, game_id, category_id, play_count)
    values (v_user_id, p_game_id, p_category_id, 0)
    on conflict (user_id, game_id) do update
    set category_id = coalesce(excluded.category_id, game_library.category_id)
    returning id into v_entry_id;

    delete from public.game_wishlist
    where user_id = v_user_id and game_id = p_game_id;

    return v_entry_id;
end;
$$;

grant execute on function public.add_game_to_collection(uuid, uuid) to authenticated;
