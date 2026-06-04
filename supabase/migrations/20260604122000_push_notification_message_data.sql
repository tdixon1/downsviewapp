alter table public.push_notification_messages
add column if not exists data jsonb;
