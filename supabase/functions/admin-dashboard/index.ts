// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const allowedRoles = [
  'admin',
  'pastor',
  'staff',
  'social_media',
  'security',
  'interest_coordinator',
  'coordinator',
  'prayer_team',
];

const adminRoles = ['admin'];

const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: corsHeaders });

const bearerToken = (request: Request) => {
  const header = request.headers.get('authorization') ?? '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
};

const metadataRoles = (user: any) => {
  const app = user?.app_metadata ?? {};
  const roles = new Set<string>();
  if (typeof app.role === 'string' && app.role) roles.add(app.role);
  if (Array.isArray(app.roles)) {
    for (const role of app.roles) if (typeof role === 'string' && role) roles.add(role);
  }
  return [...roles];
};

const selectRows = async (supabase: any, table: string, columns = '*', query?: (builder: any) => any) => {
  let builder = supabase.from(table).select(columns);
  if (query) builder = query(builder);
  const { data, error } = await builder;
  return error ? [] : data ?? [];
};

const countRows = async (supabase: any, table: string, query?: (builder: any) => any) => {
  let builder = supabase.from(table).select('id', { count: 'exact', head: true });
  if (query) builder = query(builder);
  const { count, error } = await builder;
  return error ? 0 : count ?? 0;
};

const audit = async (supabase: any, actor: any, action: string, targetType: string, targetId?: string, detail?: unknown) => {
  await supabase.from('app_audit_log').insert({
    actor_id: actor.id,
    actor_name: actor.user_metadata?.full_name ?? actor.email ?? 'Dashboard Admin',
    action,
    target_type: targetType,
    target_id: targetId,
    detail,
  });
};

const loadActor = async (supabase: any, token: string) => {
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) throw new Error('Invalid session');

  const actor = data.user;
  const roleRows = await selectRows(
    supabase,
    'user_role_assignments',
    'role',
    (query) => query.eq('user_id', actor.id),
  );
  const roles = [...new Set([...metadataRoles(actor), ...roleRows.map((row: any) => row.role).filter(Boolean)])];
  if (!roles.some((role) => adminRoles.includes(role))) {
    throw new Error('Admin role required');
  }

  return { actor, roles };
};

const listUsers = async (supabase: any) => {
  const { data, error } = await supabase.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });
  if (error) throw error;

  const authUsers = data?.users ?? [];
  const profiles = await selectRows(
    supabase,
    'profiles',
    'id,email,full_name,phone,ministry_interest,avatar_url',
  );
  const roleRows = await selectRows(supabase, 'user_role_assignments', 'user_id,role');
  const tokenRows = await selectRows(
    supabase,
    'push_tokens',
    'user_id,id,platform,disabled_at,last_seen_at',
  );

  const profilesById = new Map(profiles.map((profile: any) => [profile.id, profile]));
  const rolesByUser = new Map<string, string[]>();
  for (const row of roleRows) {
    if (!row.user_id || !row.role) continue;
    rolesByUser.set(row.user_id, [...(rolesByUser.get(row.user_id) ?? []), row.role]);
  }

  const tokensByUser = new Map<string, any[]>();
  for (const row of tokenRows) {
    if (!row.user_id) continue;
    tokensByUser.set(row.user_id, [...(tokensByUser.get(row.user_id) ?? []), row]);
  }

  return authUsers
    .map((user: any) => {
      const profile = profilesById.get(user.id) ?? {};
      const roles = [...new Set([...(rolesByUser.get(user.id) ?? []), ...metadataRoles(user)])];
      const tokens = tokensByUser.get(user.id) ?? [];
      return {
        id: user.id,
        email: user.email ?? profile.email ?? null,
        fullName: profile.full_name ?? user.user_metadata?.full_name ?? null,
        phone: profile.phone ?? null,
        ministryInterest: profile.ministry_interest ?? null,
        roles,
        createdAt: user.created_at,
        lastSignInAt: user.last_sign_in_at,
        emailConfirmedAt: user.email_confirmed_at,
        activeDevices: tokens.filter((token) => !token.disabled_at).length,
        lastDeviceSeenAt: tokens
          .map((token) => token.last_seen_at)
          .filter(Boolean)
          .sort()
          .at(-1) ?? null,
      };
    })
    .sort((a: any, b: any) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''));
};

const overview = async (supabase: any) => {
  const users = await listUsers(supabase);
  const messages = await selectRows(
    supabase,
    'push_notification_messages',
    'id,title,status,delivered_count,failed_count,sent_by_name,created_at,sent_at,error_message',
    (query) => query.order('created_at', { ascending: false }).limit(12),
  );
  const recentFollowUps = await selectRows(
    supabase,
    'appeal_responses',
    'id,requester_name,requester_email,follow_up_status,interest_type,created_at',
    (query) => query.order('created_at', { ascending: false }).limit(10),
  );
  const auditLogs = await selectRows(
    supabase,
    'app_audit_log',
    'id,actor_name,action,target_type,target_id,created_at',
    (query) => query.order('created_at', { ascending: false }).limit(10),
  );

  const sentMessages = messages.filter((message: any) => ['sent', 'sent_with_errors'].includes(message.status));
  const deliveredTotal = messages.reduce((sum: number, message: any) => sum + Number(message.delivered_count ?? 0), 0);
  const failedTotal = messages.reduce((sum: number, message: any) => sum + Number(message.failed_count ?? 0), 0);

  return {
    users,
    roles: allowedRoles,
    analytics: {
      users: users.length,
      confirmedUsers: users.filter((user: any) => user.emailConfirmedAt).length,
      activePushDevices: await countRows(supabase, 'push_tokens', (query) => query.is('disabled_at', null)),
      disabledPushDevices: await countRows(supabase, 'push_tokens', (query) => query.not('disabled_at', 'is', null)),
      openFollowUps: await countRows(supabase, 'appeal_responses', (query) => query.neq('follow_up_status', 'closed')),
      attendanceLogs: await countRows(supabase, 'attendance_logs'),
      notificationsSent: sentMessages.length,
      deliveredTotal,
      failedTotal,
    },
    messages,
    recentFollowUps,
    auditLogs,
  };
};

const setRoles = async (supabase: any, actor: any, body: any) => {
  const userId = String(body.userId ?? '');
  const roles = Array.isArray(body.roles)
    ? [...new Set(body.roles.filter((role: unknown) => typeof role === 'string' && allowedRoles.includes(role)))]
    : [];
  if (!userId) return json({ error: 'Missing userId' }, 400);
  if (userId === actor.id && !roles.includes('admin')) {
    return json({ error: 'You cannot remove your own admin role from this dashboard.' }, 400);
  }

  const { data: targetData, error: getError } = await supabase.auth.admin.getUserById(userId);
  if (getError) return json({ error: getError.message }, 400);

  const existingAppMetadata = targetData?.user?.app_metadata ?? {};
  const { error: updateError } = await supabase.auth.admin.updateUserById(userId, {
    app_metadata: {
      ...existingAppMetadata,
      role: roles[0] ?? null,
      roles,
    },
  });
  if (updateError) return json({ error: updateError.message }, 400);

  await supabase.from('user_role_assignments').delete().eq('user_id', userId);
  if (roles.length) {
    await supabase.from('user_role_assignments').insert(
      roles.map((role) => ({
        user_id: userId,
        role,
      })),
    );
  }
  await audit(supabase, actor, 'set_user_roles', 'auth.users', userId, { roles });

  return json({ ok: true, users: await listUsers(supabase) });
};

const deleteUser = async (supabase: any, actor: any, body: any) => {
  const userId = String(body.userId ?? '');
  if (!userId) return json({ error: 'Missing userId' }, 400);
  if (userId === actor.id) return json({ error: 'You cannot delete your own account from this dashboard.' }, 400);

  await audit(supabase, actor, 'delete_user', 'auth.users', userId);
  await supabase.from('push_tokens').delete().eq('user_id', userId);
  await supabase.from('user_role_assignments').delete().eq('user_id', userId);
  await supabase.from('content_bookmarks').delete().eq('user_id', userId);
  await supabase.from('attendance_logs').delete().eq('user_id', userId);
  await supabase.from('profiles').delete().eq('id', userId);

  const { error } = await supabase.auth.admin.deleteUser(userId);
  if (error) return json({ error: error.message }, 400);

  return json({ ok: true, users: await listUsers(supabase) });
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? Deno.env.get('APP_SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('APP_SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) return json({ error: 'Missing Supabase function secrets' }, 500);

  const token = bearerToken(request);
  if (!token) return json({ error: 'Missing Authorization bearer token' }, 401);

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const { actor } = await loadActor(supabase, token);
    const body = await request.json().catch(() => ({}));
    const action = body.action ?? 'overview';

    if (action === 'overview') return json(await overview(supabase));
    if (action === 'setRoles') return setRoles(supabase, actor, body);
    if (action === 'deleteUser') return deleteUser(supabase, actor, body);

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (error) {
    return json({ error: error?.message ?? String(error) }, 403);
  }
});
