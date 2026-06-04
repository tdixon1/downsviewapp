alter table public.push_tokens
add column if not exists fcm_token text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'push_tokens'
      and column_name = 'expo_push_token'
      and is_nullable = 'NO'
  ) then
    alter table public.push_tokens
    alter column expo_push_token drop not null;
  end if;
end $$;

create unique index if not exists push_tokens_fcm_token_key
on public.push_tokens (fcm_token)
where fcm_token is not null;

create index if not exists push_tokens_user_id_idx
on public.push_tokens (user_id);

create index if not exists push_tokens_last_seen_at_idx
on public.push_tokens (last_seen_at desc);
