// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type PushMessage = {
  id: string;
  title: string;
  body: string;
  target_audience: string | null;
  scheduled_at: string | null;
  data?: Record<string, unknown> | null;
};

type PushTokenRow = {
  id: string;
  fcm_token: string | null;
  user_id: string | null;
};

const chunk = <T>(items: T[], size: number) => {
  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
};

const stringifyData = (data: Record<string, unknown>) => {
  const output: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) continue;
    output[key] = String(value);
  }
  return output;
};

const base64Url = (input: ArrayBuffer | string) => {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

const pemToArrayBuffer = (pem: string) => {
  const base64 = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
};

const isInvalidFcmTokenError = (errorText: string) => {
  try {
    const parsed = JSON.parse(errorText);
    const details = parsed?.error?.details;
    if (Array.isArray(details)) {
      return details.some((detail) =>
        detail?.errorCode === 'UNREGISTERED' ||
        detail?.errorCode === 'INVALID_ARGUMENT'
      );
    }
  } catch (_) {
    // Fall through to text matching for unexpected FCM error formats.
  }

  return errorText.includes('"errorCode": "UNREGISTERED"') ||
    errorText.includes('"errorCode":"UNREGISTERED"') ||
    errorText.includes('"errorCode": "INVALID_ARGUMENT"') ||
    errorText.includes('"errorCode":"INVALID_ARGUMENT"');
};

const getFirebaseAccess = async () => {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('Missing FIREBASE_SERVICE_ACCOUNT_JSON Edge Function secret');

  const serviceAccount = JSON.parse(raw);
  if (!serviceAccount.client_email || !serviceAccount.private_key || !serviceAccount.project_id) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is missing client_email, private_key, or project_id');
  }

  const now = Math.floor(Date.now() / 1000);
  const unsigned = [
    base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
    base64Url(JSON.stringify({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    })),
  ].join('.');

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${base64Url(signature)}`,
    }),
  });

  if (!response.ok) {
    throw new Error(`Google OAuth returned ${response.status}: ${await response.text()}`);
  }

  const token = await response.json();
  return { accessToken: token.access_token, projectId: serviceAccount.project_id };
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? Deno.env.get('APP_SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('APP_SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return new Response('Missing Supabase Edge Function secrets', { status: 500 });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { accessToken, projectId } = await getFirebaseAccess();

  const { data: messages, error: messageError } = await supabase
    .from('push_notification_messages')
    .select('id,title,body,target_audience,scheduled_at,data')
    .eq('status', 'queued')
    .or(`scheduled_at.is.null,scheduled_at.lte.${new Date().toISOString()}`)
    .order('created_at', { ascending: true })
    .limit(10);

  if (messageError) {
    return Response.json({ error: messageError.message }, { status: 500 });
  }

  const sent: string[] = [];

  for (const message of (messages ?? []) as PushMessage[]) {
    let tokenQuery = supabase
      .from('push_tokens')
      .select('id,fcm_token,user_id')
      .not('fcm_token', 'is', null)
      .is('disabled_at', null);

    if (message.target_audience === 'pastoral_team') {
      const { data: roleRows, error: roleError } = await supabase
        .from('user_role_assignments')
        .select('user_id')
        .in('role', [
          'admin',
          'pastor',
          'staff',
          'interest_coordinator',
          'coordinator',
          'prayer_team',
          'security',
        ]);

      if (roleError) return Response.json({ error: roleError.message }, { status: 500 });

      const teamUserIds = [...new Set((roleRows ?? []).map((row) => row.user_id).filter(Boolean))];
      tokenQuery = teamUserIds.length
        ? tokenQuery.in('user_id', teamUserIds)
        : tokenQuery.eq('user_id', '00000000-0000-0000-0000-000000000000');
    }

    const { data: tokenRows, error: tokenError } = await tokenQuery;
    if (tokenError) return Response.json({ error: tokenError.message }, { status: 500 });

    const tokens = ((tokenRows ?? []) as PushTokenRow[]).filter((row) => Boolean(row.fcm_token));
    if (!tokens.length) {
      await supabase
        .from('push_notification_messages')
        .update({ status: 'failed', error_message: 'No registered FCM tokens' })
        .eq('id', message.id);
      continue;
    }

    let deliveredCount = 0;
    let failedCount = 0;
    const errors: string[] = [];
    const invalidTokenIds = new Set<string>();

    for (const tokenChunk of chunk(tokens, 100)) {
      await Promise.all(tokenChunk.map(async (tokenRow) => {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token: tokenRow.fcm_token,
                notification: { title: message.title, body: message.body },
                data: stringifyData({
                  ...(message.data ?? {}),
                  messageId: message.id,
                  title: message.title,
                  body: message.body,
                }),
                android: {
                  priority: 'HIGH',
                  notification: {
                    channel_id: 'church-push',
                    sound: 'default',
                  },
                },
              },
            }),
          },
        );

        if (response.ok) {
          deliveredCount++;
        } else {
          failedCount++;
          const errorText = await response.text();
          errors.push(errorText.slice(0, 300));
          if (isInvalidFcmTokenError(errorText)) {
            invalidTokenIds.add(tokenRow.id);
          }
        }
      }));
    }

    if (invalidTokenIds.size) {
      await supabase
        .from('push_tokens')
        .update({
          disabled_at: new Date().toISOString(),
        })
        .in('id', [...invalidTokenIds]);
    }

    await supabase
      .from('push_notification_messages')
      .update({
        status: failedCount ? 'sent_with_errors' : 'sent',
        sent_at: new Date().toISOString(),
        delivered_count: deliveredCount,
        failed_count: failedCount,
        error_message: failedCount ? [...new Set(errors)].join('; ').slice(0, 1000) : null,
      })
      .eq('id', message.id);

    sent.push(message.id);
  }

  return Response.json({ sent });
});
