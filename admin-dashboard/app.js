let client = null;
let session = null;
let state = {
  users: [],
  roles: [],
  analytics: {},
  messages: [],
  recentFollowUps: [],
  auditLogs: [],
};

const $ = (id) => document.getElementById(id);

const showToast = (message) => {
  const toast = $('toast');
  toast.textContent = message;
  toast.classList.remove('hidden');
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => toast.classList.add('hidden'), 4200);
};

const setBusy = (busy) => {
  for (const button of document.querySelectorAll('button')) button.disabled = busy;
};

const formatDate = (value) => {
  if (!value) return 'Never';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 'Unknown' : date.toLocaleString();
};

const escapeHtml = (value) =>
  String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');

const roleLabel = (role) =>
  role
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');

const configureClient = () => {
  if (client) return client;

  const config = window.DOWNSVIEW_ADMIN_CONFIG || {};
  const url = String(config.supabaseUrl || '').trim();
  const anonKey = String(config.supabaseAnonKey || '').trim();
  if (!url || !anonKey) {
    throw new Error('Dashboard config is missing. Generate admin-dashboard/config.js from .env.');
  }

  client = window.supabase.createClient(url, anonKey, {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
      storageKey: 'downsview-admin-dashboard-session',
    },
  });
  client.auth.onAuthStateChange((_event, nextSession) => {
    session = nextSession;
  });
  return client;
};

const currentSession = async () => {
  configureClient();
  const { data, error } = await client.auth.getSession();
  if (error) throw error;
  session = data.session;
  if (!session?.access_token) throw new Error('Your admin session expired. Please sign in again.');
  return session;
};

const invokeAdmin = async (body) => {
  const activeSession = await currentSession();
  const { data, error } = await client.functions.invoke('admin-dashboard', {
    body,
    headers: {
      Authorization: `Bearer ${activeSession.access_token}`,
    },
  });
  if (error) throw error;
  if (data?.error) throw new Error(data.error);
  return data;
};

const renderMetrics = () => {
  const metrics = [
    ['Users', state.analytics.users],
    ['Confirmed', state.analytics.confirmedUsers],
    ['Push devices', state.analytics.activePushDevices],
    ['Open follow ups', state.analytics.openFollowUps],
    ['Attendance logs', state.analytics.attendanceLogs],
    ['Delivered pushes', state.analytics.deliveredTotal],
  ];
  $('analytics').innerHTML = metrics
    .map(([label, value]) => `
      <article class="metric">
        <strong>${Number(value ?? 0).toLocaleString()}</strong>
        <span>${escapeHtml(label)}</span>
      </article>
    `)
    .join('');
};

const filteredUsers = () => {
  const query = $('userSearch').value.trim().toLowerCase();
  if (!query) return state.users;
  return state.users.filter((user) =>
    [user.email, user.fullName, user.phone, user.ministryInterest, ...(user.roles || [])]
      .filter(Boolean)
      .join(' ')
      .toLowerCase()
      .includes(query),
  );
};

const renderUsers = () => {
  const rows = filteredUsers();
  $('usersBody').innerHTML = rows
    .map((user) => `
      <tr>
        <td>
          <div class="user-name">${escapeHtml(user.fullName || user.email || 'Unnamed user')}</div>
          <div class="meta">${escapeHtml(user.email || 'No email')}</div>
          <div class="meta">Created ${formatDate(user.createdAt)}</div>
        </td>
        <td>
          <div class="roles">
            ${state.roles.map((role) => `
              <label class="role">
                <input
                  type="checkbox"
                  data-user-id="${escapeHtml(user.id)}"
                  data-role="${escapeHtml(role)}"
                  ${user.roles?.includes(role) ? 'checked' : ''}
                />
                ${escapeHtml(roleLabel(role))}
              </label>
            `).join('')}
          </div>
        </td>
        <td>
          <div>${Number(user.activeDevices || 0)} active</div>
          <div class="meta">${formatDate(user.lastDeviceSeenAt)}</div>
        </td>
        <td>${formatDate(user.lastSignInAt)}</td>
        <td>
          <button class="danger" data-delete-user="${escapeHtml(user.id)}" type="button">Delete</button>
        </td>
      </tr>
    `)
    .join('');
};

const statusClass = (status) => {
  if (status === 'sent') return 'good';
  if (status === 'sent_with_errors' || status === 'queued') return 'warn';
  return 'bad';
};

const messageDetails = (message) => {
  const delivered = Number(message.delivered_count || 0);
  const failed = Number(message.failed_count || 0);
  const total = delivered + failed;
  return [
    `Status: ${message.status || 'unknown'}`,
    `Delivered: ${delivered}`,
    `Failed: ${failed}`,
    `Attempted devices: ${total}`,
    `Sender: ${message.sent_by_name || 'Church Team'}`,
    `Created: ${formatDate(message.created_at)}`,
    `Sent: ${formatDate(message.sent_at)}`,
    message.error_message ? `Error: ${message.error_message}` : null,
  ].filter(Boolean).join('\n');
};

const renderMessages = () => {
  $('messagesList').innerHTML = (state.messages || []).map((message) => `
    <article class="item">
      <div class="item-title">${escapeHtml(message.title)}</div>
      <div class="meta">${escapeHtml(message.sent_by_name || 'Church Team')} | ${formatDate(message.created_at)}</div>
      <div class="meta">Delivered ${Number(message.delivered_count || 0)} | Failed ${Number(message.failed_count || 0)}</div>
      <span
        class="status ${statusClass(message.status)} has-tooltip"
        tabindex="0"
        title="${escapeHtml(messageDetails(message))}"
        data-tooltip="${escapeHtml(messageDetails(message))}"
      >${escapeHtml(message.status)}</span>
      ${message.error_message ? `<div class="meta error-preview">${escapeHtml(message.error_message)}</div>` : ''}
    </article>
  `).join('') || '<p class="meta">No notifications yet.</p>';
};

const renderFollowUps = () => {
  $('followUpsList').innerHTML = (state.recentFollowUps || []).map((item) => `
    <article class="item">
      <div class="item-title">${escapeHtml(item.requester_name || item.requester_email || 'Follow up')}</div>
      <div class="meta">${escapeHtml(item.interest_type || 'general')} | ${formatDate(item.created_at)}</div>
      <span class="status ${item.follow_up_status === 'closed' ? 'good' : 'warn'}">${escapeHtml(item.follow_up_status || 'new')}</span>
    </article>
  `).join('') || '<p class="meta">No follow ups yet.</p>';
};

const renderAudit = () => {
  $('auditList').innerHTML = (state.auditLogs || []).map((item) => `
    <article class="item">
      <div class="item-title">${escapeHtml(item.action)}</div>
      <div class="meta">${escapeHtml(item.actor_name || 'Admin')} | ${escapeHtml(item.target_type || '')}</div>
      <div class="meta">${formatDate(item.created_at)}</div>
    </article>
  `).join('') || '<p class="meta">No audit events yet.</p>';
};

const render = () => {
  renderMetrics();
  renderUsers();
  renderMessages();
  renderFollowUps();
  renderAudit();
};

const loadDashboard = async () => {
  setBusy(true);
  try {
    const data = await invokeAdmin({ action: 'overview' });
    state = data;
    $('configPanel').classList.add('hidden');
    $('dashboardPanel').classList.remove('hidden');
    render();
  } catch (error) {
    showToast(error.message || String(error));
  } finally {
    setBusy(false);
  }
};

$('signInButton').addEventListener('click', async () => {
  setBusy(true);
  try {
    configureClient();
    const { data, error } = await client.auth.signInWithPassword({
      email: $('email').value.trim(),
      password: $('password').value,
    });
    if (error) throw error;
    session = data.session;
    await loadDashboard();
  } catch (error) {
    showToast(error.message || String(error));
  } finally {
    setBusy(false);
  }
});

$('signOutButton').addEventListener('click', async () => {
  await client?.auth.signOut();
  session = null;
  $('dashboardPanel').classList.add('hidden');
  $('configPanel').classList.remove('hidden');
});

$('refreshButton').addEventListener('click', loadDashboard);
$('userSearch').addEventListener('input', renderUsers);

$('usersBody').addEventListener('change', async (event) => {
  const input = event.target;
  if (!(input instanceof HTMLInputElement) || !input.dataset.userId) return;

  const user = state.users.find((item) => item.id === input.dataset.userId);
  if (!user) return;

  const roles = new Set(user.roles || []);
  input.checked ? roles.add(input.dataset.role) : roles.delete(input.dataset.role);

  setBusy(true);
  try {
    const data = await invokeAdmin({
      action: 'setRoles',
      userId: user.id,
      roles: [...roles],
    });
    state.users = data.users;
    renderUsers();
    showToast('Roles updated.');
  } catch (error) {
    input.checked = !input.checked;
    showToast(error.message || String(error));
  } finally {
    setBusy(false);
  }
});

$('usersBody').addEventListener('click', async (event) => {
  const button = event.target.closest('[data-delete-user]');
  if (!button) return;

  const user = state.users.find((item) => item.id === button.dataset.deleteUser);
  const label = user?.email || user?.fullName || 'this user';
  const confirmed = window.confirm(`Delete ${label}? This removes the login account and related dashboard records.`);
  if (!confirmed) return;

  setBusy(true);
  try {
    const data = await invokeAdmin({
      action: 'deleteUser',
      userId: button.dataset.deleteUser,
    });
    state.users = data.users;
    state.analytics.users = state.users.length;
    render();
    showToast('Account deleted.');
  } catch (error) {
    showToast(error.message || String(error));
  } finally {
    setBusy(false);
  }
});

const restoreSession = async () => {
  try {
    configureClient();
    const { data, error } = await client.auth.getSession();
    if (error) throw error;
    session = data.session;
    if (session?.access_token) await loadDashboard();
  } catch (error) {
    showToast(error.message || String(error));
  }
};

restoreSession();
