# StreamVibe - OAuth Architecture Diagram

## 🎨 Two OAuth Flows Side-by-Side

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          STREAMVIBE AUTHENTICATION                              │
└─────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────┐  ┌────────────────────────────────────────┐
│   FLOW 1: USER LOGIN               │  │   FLOW 2: PLATFORM CONNECTION          │
│   (Supabase Auth)                  │  │   (Custom Platform OAuth)              │
└────────────────────────────────────┘  └────────────────────────────────────────┘

[User]                                  [Authenticated User]
   │                                           │
   │ 1. Click "Sign in with Google"           │ 1. Click "Connect YouTube"
   ↓                                           ↓
┌──────────────────┐                    ┌──────────────────────┐
│ Supabase Auth    │                    │ Edge Function        │
│ (Managed)        │                    │ (You Build)          │
└──────────────────┘                    └──────────────────────┘
   │                                           │
   │ 2. Redirect to Google                    │ 2. Generate YouTube OAuth URL
   ↓                                           ↓
┌──────────────────┐                    ┌──────────────────────┐
│ Google OAuth     │                    │ YouTube OAuth        │
│ Consent Screen   │                    │ Consent Screen       │
└──────────────────┘                    └──────────────────────┘
   │                                           │
   │ 3. User approves                         │ 3. User approves
   │    "Login to StreamVibe"                 │    "StreamVibe can access your YouTube"
   ↓                                           ↓
┌──────────────────┐                    ┌──────────────────────┐
│ Google returns   │                    │ YouTube returns      │
│ code to Supabase │                    │ code to Edge Function│
└──────────────────┘                    └──────────────────────┘
   │                                           │
   │ 4. Supabase exchanges code               │ 4. Exchange code for tokens
   │    Creates auth.users record             │    { access_token, refresh_token }
   ↓                                           ↓
┌──────────────────┐                    ┌──────────────────────┐
│ auth.users       │                    │ Supabase Vault       │
│ (Built-in)       │                    │ (Encrypted Storage)  │
└──────────────────┘                    └──────────────────────┘
   │                                           │
   │ 5. Trigger fires                         │ 5. Store vault reference
   ↓                                           ↓
┌──────────────────┐                    ┌──────────────────────┐
│ profiles table   │                    │ platform_credentials │
│ user_roles       │                    │ table                │
│ subscription     │                    │                      │
└──────────────────┘                    └──────────────────────┘
   │                                           │
   │ 6. User logged in                        │ 6. YouTube connected
   ↓                                           ↓
[Dashboard]                             [Can sync YouTube videos]


┌─────────────────────────────────────────────────────────────────────────────────┐
│                             TOKEN STORAGE                                       │
└─────────────────────────────────────────────────────────────────────────────────┘

SUPABASE AUTH TOKENS                    PLATFORM OAUTH TOKENS
(You DON'T manage)                      (You manage in Vault)

✅ Stored in: httpOnly cookie           ✅ Stored in: Supabase Vault
✅ Managed by: Supabase Auth            ✅ Managed by: Your Edge Functions
✅ Purpose: Authenticate user           ✅ Purpose: Access user's content
✅ Access: Automatic via SDK            ✅ Access: Via service_role key only
✅ Refresh: Automatic                   ✅ Refresh: You implement

JWT Token Structure:                    Vault Secret Structure:
{                                       {
  sub: "user-uuid",                       name: "platform_token_user_youtube",
  email: "user@example.com",              secret: {
  aud: "authenticated",                     access_token: "ya29.xxx",
  exp: 1234567890                           refresh_token: "1//xxx",
}                                           expires_in: 3600
                                          }
                                        }


┌─────────────────────────────────────────────────────────────────────────────────┐
│                          USING THE TOKENS                                       │
└─────────────────────────────────────────────────────────────────────────────────┘

CLIENT-SIDE                             SERVER-SIDE (Edge Functions)
(Browser/Mobile App)                    (Service Role Key)

// Get authenticated user                // Get user from JWT
const { data: { user } } = await        const authHeader = req.headers.get('Authorization')
  supabase.auth.getUser()                const jwt = authHeader.replace('Bearer ', '')
                                         const { sub: userId } = parseJWT(jwt)
// user.id = UUID from auth.users        
// user.email = user's email              // Get platform credentials
                                         const { data: cred } = await supabase
// ❌ You DON'T have access to             .from('platform_credentials')
// Google OAuth tokens!                    .select('vault_secret_name')
// Supabase manages those                  .eq('user_id', userId)
                                           .single()
// Check if platform connected            
const { data } = await supabase          // Retrieve tokens from Vault
  .from('platform_credentials')          const { data: secret } = await supabase
  .select('platform_username')             .from('vault.decrypted_secrets')
  .eq('user_id', user.id)                  .select('decrypted_secret')
                                           .eq('name', cred.vault_secret_name)
// Returns: { platform_username: '@me' }   .single()
                                         
// ❌ You DON'T see tokens!               // ✅ You can use tokens!
                                         const tokens = JSON.parse(secret.decrypted_secret)
                                         
                                         // Call YouTube API
                                         const videos = await fetch(
                                           'https://www.googleapis.com/youtube/v3/videos',
                                           { headers: { 
                                             'Authorization': `Bearer ${tokens.access_token}` 
                                           }}
                                         )


┌─────────────────────────────────────────────────────────────────────────────────┐
│                          SECURITY BOUNDARIES                                    │
└─────────────────────────────────────────────────────────────────────────────────┘

CLIENT (Anon Key)                       SERVER (Service Role Key)
════════════════                        ═════════════════════════

✅ Can authenticate users               ✅ Can access Vault
✅ Can read own profile                 ✅ Can decrypt secrets
✅ Can see platform_credentials         ✅ Can call platform APIs
   (without vault_secret_name)          ✅ Can refresh tokens
✅ Can trigger Edge Functions           ✅ Can bypass RLS policies

❌ CANNOT access Vault                  🔒 Must validate JWT
❌ CANNOT see tokens                    🔒 Must verify user_id
❌ CANNOT call YouTube API directly     🔒 Must check quotas
❌ CANNOT bypass RLS                    🔒 Must audit actions


┌─────────────────────────────────────────────────────────────────────────────────┐
│                          DATA FLOW EXAMPLE                                      │
└─────────────────────────────────────────────────────────────────────────────────┘

USER ACTION: "Sync my YouTube videos"

1. [CLIENT] User clicks "Sync" button
   ↓
2. [CLIENT] Call Edge Function with auth token
   ```typescript
   const { data } = await supabase.functions.invoke('sync-youtube', {
     body: { handleId: 'uuid' }
   })
   ```
   ↓
3. [EDGE FUNCTION] Verify user from JWT
   ↓
4. [EDGE FUNCTION] Check quota
   ```typescript
   const hasQuota = await supabase.rpc('check_quota', {
     _user_id: userId,
     _quota_type: 'syncs',
     _amount: 1
   })
   ```
   ↓
5. [EDGE FUNCTION] Get platform credentials
   ```typescript
   const { data: cred } = await supabase
     .from('platform_credentials')
     .select('vault_secret_name, platform_account_id')
     .eq('user_id', userId)
     .eq('platform_id', youtubeId)
     .single()
   ```
   ↓
6. [EDGE FUNCTION] Retrieve tokens from Vault
   ```typescript
   const { data: secret } = await supabase
     .from('vault.decrypted_secrets')
     .select('decrypted_secret')
     .eq('name', cred.vault_secret_name)
     .single()
   ```
   ↓
7. [EDGE FUNCTION] Call YouTube API
   ```typescript
   const videos = await fetch(
     `https://www.googleapis.com/youtube/v3/search?` +
     `channelId=${cred.platform_account_id}&part=snippet`,
     { headers: { 'Authorization': `Bearer ${tokens.access_token}` } }
   )
   ```
   ↓
8. [EDGE FUNCTION] Store videos in database
   ```typescript
   await supabase.from('handle_content').insert(videos.items.map(...))
   ```
   ↓
9. [EDGE FUNCTION] Increment quota
   ```typescript
   await supabase.rpc('increment_quota', {
     _user_id: userId,
     _quota_type: 'syncs',
     _amount: 1
   })
   ```
   ↓
10. [EDGE FUNCTION] Log to audit_log
   ```typescript
   await supabase.from('audit_log').insert({
     user_id: userId,
     job_type: 'platform_sync',
     job_status: 'completed',
     job_result: { synced: videos.length }
   })
   ```
   ↓
11. [CLIENT] Receive response
    ```typescript
    // { success: true, synced: 25 }
    ```
    ↓
12. [CLIENT] Refresh UI to show new videos


┌─────────────────────────────────────────────────────────────────────────────────┐
│                          SUMMARY TABLE                                          │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┬────────────────────────┬─────────────────────────────┐
│ Aspect           │ Supabase Auth          │ Platform OAuth              │
├──────────────────┼────────────────────────┼─────────────────────────────┤
│ Purpose          │ Login to StreamVibe    │ Access user's social media  │
│ Provider         │ Google, Facebook, etc. │ YouTube, Instagram, TikTok  │
│ Managed By       │ Supabase (automatic)   │ You (Edge Functions)        │
│ Token Storage    │ httpOnly cookie (JWT)  │ Supabase Vault              │
│ Token Access     │ Client SDK (automatic) │ Service role only           │
│ Token Refresh    │ Automatic              │ Manual (you implement)      │
│ Setup Required   │ Enable in dashboard    │ Register OAuth apps         │
│ Code Complexity  │ Very low (~5 lines)    │ Medium (Edge Functions)     │
│ Security Risk    │ None (managed)         │ Low (Vault encryption)      │
│ User Consent     │ "Login to StreamVibe"  │ "Access your YouTube"       │
│ Revocation       │ Sign out               │ Disconnect platform         │
└──────────────────┴────────────────────────┴─────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────────┐
│                          QUICK REFERENCE                                        │
└─────────────────────────────────────────────────────────────────────────────────┘

WHEN TO USE SUPABASE AUTH:
✅ User sign-up / sign-in
✅ Social login (Google, Facebook, Apple)
✅ Email/password authentication
✅ Session management
✅ Password reset
✅ Email verification

WHEN TO USE PLATFORM OAUTH (VAULT):
✅ Connect YouTube account
✅ Connect Instagram account
✅ Connect TikTok account
✅ Fetch user's videos/posts
✅ Post on user's behalf
✅ Access platform APIs

NEVER DO:
❌ Store Google/Facebook login tokens in database
❌ Try to refresh Supabase Auth tokens manually
❌ Store YouTube/Instagram tokens in database tables
❌ Use anon key to access Vault
❌ Expose service_role key to client
❌ Log platform tokens in console
```

---

## 🎯 Key Insight

**Think of it this way:**

- **Supabase Auth** = Your house key 🔑
  - Gets you INTO StreamVibe
  - Managed by the building (Supabase)
  - You don't handle the key-cutting

- **Platform OAuth** = Keys to your car 🚗
  - Lets StreamVibe drive your YouTube/Instagram
  - You give StreamVibe the keys
  - StreamVibe keeps them safe in a vault
  - You can revoke them anytime

**Both are OAuth, but completely different purposes!**
