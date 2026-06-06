# Downsview SDA Admin Dashboard

This is a static admin webpage backed by the `admin-dashboard` Supabase Edge Function.

## Access

Open `index.html` through a local or hosted web server, enter:

- Supabase URL
- Supabase anon key
- An admin user's email and password

The browser only uses the anon key and the signed-in admin session. Account deletion and role updates happen inside the Edge Function using the server-side Supabase service role key.

## Features

- View app users and profile details
- Add or remove security/pastoral/push roles
- Delete user accounts
- See active push device counts
- See notification delivery totals
- Review recent push messages, follow-ups, and audit activity

## Deploy Notes

Production path:

```text
https://downsviewsda.org/admin-dashboard/
```

Do not link to this folder from public navigation. Host it behind server access control when possible.

This folder includes:

- `<meta name="robots" content="noindex,nofollow,...">`
- `.htaccess` for Apache/cPanel hosting with `X-Robots-Tag` and directory listing disabled
- `robots.txt` with `Disallow: /` for direct folder checks
- `robots-root-snippet.txt` to merge into the website root `https://downsviewsda.org/robots.txt`
- `serve_noindex.py` for local serving with `X-Robots-Tag`

If deploying behind a web server, also add this response header for every dashboard file:

```text
X-Robots-Tag: noindex, nofollow, noarchive, nosnippet, noimageindex
```

Also add this to the root website robots file:

```text
User-agent: *
Disallow: /admin-dashboard/
```

Robots and noindex are not security controls. The dashboard still requires an admin Supabase login, and the privileged operations run through the protected Edge Function.

The required function is deployed with:

```powershell
supabase functions deploy admin-dashboard --project-ref <project-ref>
```
