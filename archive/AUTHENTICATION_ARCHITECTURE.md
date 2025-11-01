# StreamVibe Authentication Architecture

## 🎯 Overview

StreamVibe uses **TWO separate OAuth systems**:

1. **Supabase Auth** - For user login (Google, Facebook, Email, etc.)
2. **Platform OAuth** - For accessing user's social media content (YouTube, Instagram, TikTok)

---

## 🔐 Flow 1: User Authentication (Supabase Auth)

### **What This Handles**
- User sign-up / sign-in
- Social login (Google, Facebook, Apple, GitHub, etc.)
- Email/password authentication
- Magic link authentication
- Session management
- Password reset

### **Flow Diagram**
```
┌─────────────────────────────────────────────────────────────┐
│                   SUPABASE AUTH (Built-in)                  │
└─────────────────────────────────────────────────────────────┘

User visits StreamVibe
    ↓
Clicks "Sign in with Google"
    ↓
Supabase Auth redirects to Google OAuth
    ↓
User approves (login to StreamVibe)
    ↓
Google redirects back to Supabase
    ↓
Supabase Auth creates session
    ↓
User record in auth.users table
    ↓
Trigger creates profile in public.profiles
    ↓
User is now authenticated in StreamVibe ✅
```

### **Implementation (Frontend)**

```typescript
// src/auth/AuthProvider.tsx
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// Sign in with Google (Supabase Auth handles everything)
async function signInWithGoogle() {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: 'https://streamvibe.app/auth/callback'
    }
  })
}

// Sign in with Facebook
async function signInWithFacebook() {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'facebook',
    options: {
      redirectTo: 'https://streamvibe.app/auth/callback'
    }
  })
}

// Sign in with Email/Password
async function signInWithEmail(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  })
}

// Sign up with Email
async function signUp(email: string, password: string, fullName: string) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: fullName
      }
    }
  })
}

// Get current user
const { data: { user } } = await supabase.auth.getUser()
console.log('Logged in user:', user.id, user.email)
```

### **What You DON'T Need to Do**
- ❌ Store Google/Facebook OAuth tokens
- ❌ Refresh login tokens (Supabase does this)
- ❌ Handle email verification
- ❌ Build password reset flows
- ❌ Manage user sessions

**Supabase Auth handles ALL of this!**

---

## 📱 Flow 2: Platform Integration (YouTube/Instagram/TikTok)

### **What This Handles**
- Connecting user's YouTube channel
- Connecting user's Instagram account
- Connecting user's TikTok account
- Fetching their content
- Posting on their behalf
- Managing API rate limits

### **Flow Diagram**
```
┌─────────────────────────────────────────────────────────────┐
│                  PLATFORM OAUTH (You manage)                │
└─────────────────────────────────────────────────────────────┘

User already logged in via Supabase Auth ✅
    ↓
User clicks "Connect YouTube"
    ↓
Call Edge Function: initiate-youtube-oauth
    ↓
Edge Function generates YouTube OAuth URL
    ↓
Redirect user to YouTube consent screen
    ↓
User approves (grant StreamVibe access to YouTube)
    ↓
YouTube redirects back with authorization code
    ↓
Edge Function: youtube-oauth-callback
    ↓
Exchange code for access_token + refresh_token
    ↓
Store tokens in Supabase Vault (encrypted) 🔐
    ↓
Store reference in platform_credentials table
    ↓
YouTube is now connected ✅
```

### **Implementation (Frontend + Edge Functions)**

#### **Frontend: Initiate Connection**
```typescript
// src/platforms/ConnectYouTube.tsx
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

async function connectYouTube() {
  // 1. Get current user (from Supabase Auth)
  const { data: { user } } = await supabase.auth.getUser()
  
  if (!user) {
    alert('Please sign in first')
    return
  }
  
  // 2. Call Edge Function to get OAuth URL
  const { data } = await supabase.functions.invoke('initiate-platform-oauth', {
    body: { 
      platform: 'youtube',
      userId: user.id 
    }
  })
  
  // 3. Redirect user to YouTube consent screen
  window.location.href = data.authUrl
}

// Check if platforms are connected
async function getConnectedPlatforms() {
  const { data: platforms } = await supabase
    .from('platform_credentials')
    .select('platform_id, platform_username, scopes, is_active, last_verified_at')
    .eq('is_active', true)
  
  return platforms
  // Returns: [{ platform_id: 'youtube-id', platform_username: '@mychannel', ... }]
}
```

#### **Edge Function: Initiate OAuth**
```typescript
// supabase/functions/initiate-platform-oauth/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const { platform, userId } = await req.json()
  
  const REDIRECT_URI = 'https://streamvibe.app/oauth/callback'
  
  // YouTube OAuth configuration
  if (platform === 'youtube') {
    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?` +
      `client_id=${Deno.env.get('YOUTUBE_CLIENT_ID')}` +
      `&redirect_uri=${REDIRECT_URI}` +
      `&response_type=code` +
      `&scope=https://www.googleapis.com/auth/youtube.readonly` +
      `&access_type=offline` + // Get refresh token
      `&state=${userId}_youtube` // Track user + platform
    
    return new Response(JSON.stringify({ authUrl }))
  }
  
  // Instagram OAuth
  if (platform === 'instagram') {
    const authUrl = `https://api.instagram.com/oauth/authorize?` +
      `client_id=${Deno.env.get('INSTAGRAM_CLIENT_ID')}` +
      `&redirect_uri=${REDIRECT_URI}` +
      `&scope=user_profile,user_media` +
      `&response_type=code` +
      `&state=${userId}_instagram`
    
    return new Response(JSON.stringify({ authUrl }))
  }
  
  return new Response('Platform not supported', { status: 400 })
})
```

#### **Edge Function: OAuth Callback**
```typescript
// supabase/functions/platform-oauth-callback/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const url = new URL(req.url)
  const code = url.searchParams.get('code')
  const state = url.searchParams.get('state') // Contains "userId_platform"
  
  const [userId, platform] = state.split('_')
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // For Vault access
  )
  
  // Exchange code for tokens
  let tokens
  let platformAccountInfo
  
  if (platform === 'youtube') {
    // Exchange with YouTube
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id: Deno.env.get('YOUTUBE_CLIENT_ID')!,
        client_secret: Deno.env.get('YOUTUBE_CLIENT_SECRET')!,
        redirect_uri: 'https://streamvibe.app/oauth/callback',
        grant_type: 'authorization_code'
      })
    })
    
    tokens = await tokenResponse.json()
    
    // Get user's YouTube channel info
    const channelResponse = await fetch(
      'https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true',
      {
        headers: { 'Authorization': `Bearer ${tokens.access_token}` }
      }
    )
    
    const channelData = await channelResponse.json()
    platformAccountInfo = {
      accountId: channelData.items[0].id,
      username: channelData.items[0].snippet.title
    }
  }
  
  // Store tokens in Supabase Vault
  const secretName = `platform_token_${userId}_${platform}_${Date.now()}`
  
  const { error: vaultError } = await supabase
    .from('vault.secrets')
    .insert({
      name: secretName,
      secret: JSON.stringify({
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token,
        token_type: tokens.token_type,
        expires_in: tokens.expires_in,
        scope: tokens.scope
      })
    })
  
  if (vaultError) {
    console.error('Vault error:', vaultError)
    return new Response('Failed to store credentials', { status: 500 })
  }
  
  // Get platform_id from database
  const { data: platformData } = await supabase
    .from('supported_platform_types')
    .select('id')
    .eq('name', platform)
    .single()
  
  // Store reference in platform_credentials
  await supabase
    .from('platform_credentials')
    .upsert({
      user_id: userId,
      platform_id: platformData.id,
      vault_secret_name: secretName,
      token_expires_at: new Date(Date.now() + tokens.expires_in * 1000),
      scopes: tokens.scope.split(' '),
      is_active: true,
      last_verified_at: new Date(),
      platform_account_id: platformAccountInfo.accountId,
      platform_username: platformAccountInfo.username
    }, {
      onConflict: 'user_id,platform_id'
    })
  
  // Redirect back to app
  return Response.redirect('https://streamvibe.app/platforms?connected=youtube', 302)
})
```

---

## 🗂️ Database Schema

### **Supabase Auth Tables (Built-in)**
```sql
-- ✅ Provided by Supabase (you don't create these)
auth.users (
    id UUID PRIMARY KEY,
    email TEXT,
    encrypted_password TEXT,
    email_confirmed_at TIMESTAMPTZ,
    last_sign_in_at TIMESTAMPTZ,
    raw_user_meta_data JSONB,  -- Contains full_name, etc.
    ...
)
```

### **Your Application Tables**
```sql
-- Triggered automatically when user signs up
public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ
)

-- Platform connections (your Edge Functions manage this)
public.platform_credentials (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES profiles(id),  -- Links to Supabase Auth user
    platform_id UUID REFERENCES supported_platform_types(id),
    vault_secret_name TEXT,  -- Reference to Vault secret (YouTube/Instagram tokens)
    token_expires_at TIMESTAMPTZ,
    platform_account_id TEXT,  -- e.g., YouTube channel ID
    platform_username TEXT,    -- e.g., @mychannel
    is_active BOOLEAN
)
```

---

## 🔄 Complete User Journey

### **Step 1: User Signs Up**
```
User → StreamVibe landing page
    ↓
Clicks "Sign in with Google"
    ↓
Supabase Auth redirects to Google
    ↓
User approves (login to StreamVibe app)
    ↓
Google redirects to Supabase Auth
    ↓
Supabase creates auth.users record
    ↓
Trigger creates profiles + user_roles + subscription_settings
    ↓
User sees StreamVibe dashboard ✅
```

### **Step 2: User Connects YouTube**
```
User → Dashboard (already logged in via Supabase Auth)
    ↓
Clicks "Connect YouTube"
    ↓
Edge Function generates YouTube OAuth URL
    ↓
User approves (grant StreamVibe access to YouTube channel)
    ↓
YouTube redirects to Edge Function callback
    ↓
Edge Function stores tokens in Vault
    ↓
platform_credentials record created
    ↓
User sees "YouTube connected as @mychannel" ✅
```

### **Step 3: User Syncs Content**
```
User clicks "Sync YouTube videos"
    ↓
Edge Function: sync-youtube
    ↓
Gets user_id from Supabase Auth session
    ↓
Looks up platform_credentials for YouTube
    ↓
Retrieves tokens from Vault (decrypted)
    ↓
Calls YouTube API with access_token
    ↓
Stores videos in handle_content table
    ↓
User sees their YouTube videos in StreamVibe ✅
```

---

## 🔒 Security Summary

| Layer | Managed By | Stored In | Purpose |
|-------|-----------|-----------|---------|
| **User Login** | Supabase Auth | `auth.users` | Authenticate user into StreamVibe |
| **Login Session** | Supabase Auth | JWT (httpOnly cookie) | Maintain user session |
| **Platform Tokens** | Your Edge Functions | Supabase Vault | Access user's YouTube/Instagram |
| **Token Reference** | Your database | `platform_credentials` | Point to Vault secret |

**Key Point:** You NEVER see or store Google/Facebook login tokens. Supabase Auth handles that completely!

---

## ⚙️ Configuration

### **Supabase Auth Settings**
```bash
# In Supabase Dashboard → Authentication → Providers

✅ Enable Google OAuth
   - Add Google Client ID
   - Add Google Client Secret
   - Set redirect URL: https://<project-ref>.supabase.co/auth/v1/callback

✅ Enable Facebook OAuth
   - Add Facebook App ID
   - Add Facebook App Secret
   - Set redirect URL: https://<project-ref>.supabase.co/auth/v1/callback

✅ Enable Email/Password
   - Configure email templates
   - Set up SMTP (optional)
```

### **Platform OAuth Settings (Your App)**
```bash
# In Supabase Dashboard → Project Settings → Secrets

# YouTube Data API
YOUTUBE_CLIENT_ID=your-youtube-client-id.apps.googleusercontent.com
YOUTUBE_CLIENT_SECRET=your-youtube-secret

# Instagram Basic Display API
INSTAGRAM_CLIENT_ID=your-instagram-app-id
INSTAGRAM_CLIENT_SECRET=your-instagram-app-secret

# TikTok Developer API
TIKTOK_CLIENT_KEY=your-tiktok-client-key
TIKTOK_CLIENT_SECRET=your-tiktok-client-secret
```

---

## 🎯 What You Need to Build

### **✅ Supabase Auth (Minimal Code)**
```typescript
// Just call Supabase Auth methods
await supabase.auth.signInWithOAuth({ provider: 'google' })
await supabase.auth.signInWithPassword({ email, password })
await supabase.auth.signUp({ email, password })
```

### **✅ Platform OAuth (Custom Edge Functions)**
```typescript
// You build these:
1. initiate-platform-oauth (generate OAuth URLs)
2. platform-oauth-callback (exchange codes for tokens)
3. refresh-platform-token (refresh expired tokens)
4. disconnect-platform (revoke and delete tokens)
5. sync-platform-content (use tokens to fetch content)
```

---

## 📚 Key Takeaways

1. **Two separate OAuth systems** - Don't confuse them!
   - Supabase Auth = User login (Google, Facebook sign-in)
   - Platform OAuth = Access user's content (YouTube, Instagram APIs)

2. **Supabase Auth is fully managed** - You don't handle any tokens

3. **Platform OAuth requires your Edge Functions** - You manage these tokens (in Vault)

4. **User flow:**
   ```
   Sign in with Google (Supabase Auth)
       ↓
   Connect YouTube (Platform OAuth)
       ↓
   Sync videos (Use YouTube tokens from Vault)
   ```

5. **Never store Google/Facebook login tokens** - Supabase Auth handles this

6. **Always store YouTube/Instagram tokens in Vault** - Never in database tables

---

## 🚀 Next Steps

1. ✅ Enable Supabase Auth providers (Google, Facebook)
2. ✅ Test user sign-up with Supabase Auth
3. ✅ Build Edge Functions for platform OAuth
4. ✅ Test YouTube connection flow
5. ✅ Implement token refresh logic
6. ✅ Add more platforms (Instagram, TikTok)

**Questions?** Just ask! This architecture separates concerns perfectly:
- Supabase Auth = Who is the user?
- Platform OAuth = What can we access for them?
