drop index if exists public.push_tokens_fcm_token_key;

do $$
begin
  if not exists (
    select 1
    from information_schema.table_constraints
    where table_schema = 'public'
      and table_name = 'push_tokens'
      and constraint_name = 'push_tokens_fcm_token_key'
  ) then
    alter table public.push_tokens
    add constraint push_tokens_fcm_token_key unique (fcm_token);
  end if;
end $$;
