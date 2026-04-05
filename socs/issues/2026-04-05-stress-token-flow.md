# Stress test token flow (exact)

This file documents exactly how the stress test is authenticated.

## Which token is used
- The stress script uses a **Supabase Auth user access token (JWT)**.
- It is passed as:
  - `SUPABASE_ACCESS_TOKEN=<jwt>`
- It is sent on every request as:
  - `Authorization: Bearer <jwt>`

## How the token is obtained
For each stress run, a fresh disposable user is created and logged in.

1. Create user via Auth Admin API (service role):
- Endpoint: `POST /auth/v1/admin/users`
- Auth: `SUPABASE_SECRET_KEY`
- Payload includes `email`, `password`, `email_confirm=true`

2. Exchange email/password for access token:
- Endpoint: `POST /auth/v1/token?grant_type=password`
- Auth header `apikey`: `SUPABASE_PUBLISHABLE_KEY`
- Response field used: `access_token`

3. Use that `access_token` as `SUPABASE_ACCESS_TOKEN` for stress requests.

## Group membership requirement (critical)
The RPC endpoints `get_group_events` and `get_group_plays` enforce membership.

Before stressing, the disposable user must be inserted into `group_members` for the target group with required fields:
- `group_id`
- `user_id`
- `phone_number` (required in this schema)
- `status='accepted'`
- `role='member'`

If this insert is missing/invalid, stress results show `400` with `Not a member of this group`.

## Why this is the correct token path
- This reproduces real iOS/Auth behavior: PostgREST/RPC calls made as an authenticated user.
- It avoids stale token artifacts by minting a fresh JWT per run.
- It tests RLS/RPC access exactly as production clients do.

## What is NOT used
- Not using service-role JWT for stress endpoint calls.
- Not using a static long-lived test token.
- Not using web-session cookies.

## Minimal command shape
```bash
source .env

# 1) create disposable user (service role)
curl -X POST "$SUPABASE_URL/auth/v1/admin/users" \
  -H "apikey: $SUPABASE_SECRET_KEY" \
  -H "Authorization: Bearer $SUPABASE_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"<generated>","password":"<pwd>","email_confirm":true}'

# 2) password grant -> access token JWT
curl -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_PUBLISHABLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"<generated>","password":"<pwd>"}'

# 3) run stress with that JWT
SUPABASE_URL="$SUPABASE_URL" \
SUPABASE_ANON_KEY="$SUPABASE_PUBLISHABLE_KEY" \
SUPABASE_ACCESS_TOKEN="<access_token>" \
STRESS_USER_ID="<user_id>" \
STRESS_GROUP_ID="<group_id>" \
./socs/issues/stress_supabase_ios.sh -m mixed -n 120 -p 16
```

## Notes
- Do not commit real keys or real JWTs to git.
- Use a fresh disposable user per run for clean diagnostics.
