# StreamVibe - OAuth Quick Reference Card

## 🎯 The Two OAuth Systems

### **Supabase Auth** (User Login) 🔐
**Question:** "Who is using StreamVibe?"

```typescript
// Sign in with Google
await supabase.auth.signInWithOAuth({ provider: 'google' })

// You DON'T manage:
// - Google OAuth tokens ❌
// - Token refresh ❌
// - Session management ❌
// - Password storage ❌

// Supabase handles ALL of this automatically! ✅
```

---

### **Platform OAuth** (Content Access) 📱
**Question:** "Which YouTube/Instagram accounts can we access?"

```typescript
// Connect YouTube
await supabase.functions.invoke('connect-youtube')

// You DO manage:
// - YouTube OAuth tokens ✅ (in Vault)
// - Token refresh ✅ (your Edge Function)
// - API calls ✅ (your code)
// - Revocation ✅ (delete from Vault)
```

---

## 📊 Quick Comparison

| What | Supabase Auth | Platform OAuth |
|------|--------------|----------------|
| **Login User** | ✅ Yes | ❌ No |
| **Access YouTube** | ❌ No | ✅ Yes |
| **Managed By** | Supabase | You |
| **Tokens In** | Cookie (auto) | Vault |
| **Setup** | Dashboard | Edge Functions |

---

## 🔑 Analogy

```
Supabase Auth = Building Access Card
├─ Gets you into StreamVibe
├─ Building management handles it
└─ You just swipe and enter

Platform OAuth = Your Garage Door Opener
├─ StreamVibe needs it to access your YouTube
├─ You give it to StreamVibe
├─ StreamVibe keeps it in a safe (Vault)
└─ You can take it back anytime
```

---

## ✅ What's Already Done for You

**Supabase Auth provides:**
- Social login buttons
- Email/password forms
- Session cookies
- Token refresh
- Password reset
- Email verification
- User management UI

**You just call:**
```typescript
supabase.auth.signInWithOAuth({ provider: 'google' })
```

---

## 🔨 What You Need to Build

**Platform OAuth requires:**
- Edge Functions for OAuth flow
- Vault secret management
- Token refresh logic
- Platform API integration

**You need to create:**
```typescript
1. initiate-youtube-oauth (start flow)
2. youtube-oauth-callback (receive tokens)
3. refresh-youtube-token (refresh expired tokens)
4. sync-youtube-content (use tokens to fetch videos)
```

---

## 🎯 User Perspective

### **Step 1: Sign Up**
```
User clicks: "Sign in with Google"
    ↓
Google asks: "Let StreamVibe access your basic info?"
    ↓
User approves
    ↓
User is now LOGGED IN to StreamVibe ✅
```

### **Step 2: Connect Platform**
```
User clicks: "Connect YouTube"
    ↓
YouTube asks: "Let StreamVibe access your channel?"
    ↓
User approves
    ↓
YouTube is now CONNECTED ✅
```

### **Step 3: Use App**
```
User clicks: "Sync my videos"
    ↓
StreamVibe uses YouTube tokens (from Vault)
    ↓
Videos appear in StreamVibe ✅
```

---

## 🔒 Security Rules

### **Client Side (Anon Key)**
```typescript
✅ CAN do:
- Sign in users (Supabase Auth)
- Check if platforms connected
- View own data
- Call Edge Functions

❌ CANNOT do:
- Access Vault directly
- See OAuth tokens
- Call YouTube API directly
```

### **Server Side (Service Role)**
```typescript
✅ CAN do:
- Access Vault
- Decrypt secrets
- Call platform APIs
- Bypass RLS policies

⚠️ MUST do:
- Verify user JWT
- Check quotas
- Validate permissions
- Audit actions
```

---

## 💾 Where Things Live

```
┌─────────────────────────────────────────┐
│ auth.users (Supabase Auth - Built-in)  │
│ ├─ User ID                              │
│ ├─ Email                                │
│ └─ Google/Facebook ID                   │
└─────────────────────────────────────────┘
          ↓ (your trigger)
┌─────────────────────────────────────────┐
│ profiles (Your table)                   │
│ ├─ User ID (FK to auth.users)          │
│ ├─ Full Name                            │
│ └─ Avatar                               │
└─────────────────────────────────────────┘
          ↓ (user connects platform)
┌─────────────────────────────────────────┐
│ platform_credentials (Your table)       │
│ ├─ User ID                              │
│ ├─ Platform ID (YouTube/Instagram)     │
│ ├─ vault_secret_name (reference only)  │
│ └─ platform_username                    │
└─────────────────────────────────────────┘
          ↓ (points to)
┌─────────────────────────────────────────┐
│ vault.secrets (Supabase Vault)          │
│ ├─ Secret name                          │
│ └─ Encrypted tokens (actual OAuth)     │
└─────────────────────────────────────────┘
```

---

## 🚦 Decision Tree

**User clicks a button. Which OAuth?**

```
Is it for logging in?
├─ Yes → Supabase Auth
│         └─ supabase.auth.signInWithOAuth()
│
└─ No → Is it for connecting a platform?
        ├─ Yes → Platform OAuth
        │         └─ supabase.functions.invoke('connect-platform')
        │
        └─ Neither → Not OAuth!
```

---

## 🔄 Token Lifecycle

### **Supabase Auth Tokens (Automatic)**
```
User logs in
    ↓
Supabase creates JWT (expires in 1 hour)
    ↓
Supabase auto-refreshes (using refresh token)
    ↓
User stays logged in indefinitely ✅
    ↓
User clicks "Sign out"
    ↓
Session destroyed
```

### **Platform Tokens (You Manage)**
```
User connects YouTube
    ↓
Store tokens in Vault (expires in 1 hour)
    ↓
Use token to call YouTube API
    ↓
Token expires
    ↓
Your Edge Function refreshes token
    ↓
Store new token in Vault
    ↓
Delete old token
    ↓
Continue using YouTube API ✅
    ↓
User clicks "Disconnect YouTube"
    ↓
Delete tokens from Vault
```

---

## 📝 Cheat Sheet

### **Supabase Auth (Client-Side)**
```typescript
// Sign in with provider
await supabase.auth.signInWithOAuth({ provider: 'google' })

// Sign in with email
await supabase.auth.signInWithPassword({ email, password })

// Sign up
await supabase.auth.signUp({ email, password })

// Get current user
const { data: { user } } = await supabase.auth.getUser()

// Sign out
await supabase.auth.signOut()
```

### **Platform OAuth (Edge Functions)**
```typescript
// Store in Vault
await supabase.from('vault.secrets').insert({
  name: 'platform_token_user_youtube',
  secret: JSON.stringify(tokens)
})

// Retrieve from Vault
const { data } = await supabase
  .from('vault.decrypted_secrets')
  .select('decrypted_secret')
  .eq('name', secretName)
  .single()

// Store reference
await supabase.from('platform_credentials').insert({
  user_id: userId,
  vault_secret_name: secretName,
  platform_account_id: youtubeChannelId
})
```

---

## ⚡ Common Mistakes

### ❌ **WRONG: Trying to store login tokens**
```typescript
// DON'T DO THIS!
const { data } = await supabase.auth.signInWithOAuth({ provider: 'google' })
// You WON'T get Google's OAuth tokens here
// Supabase Auth manages those internally
```

### ✅ **RIGHT: Let Supabase handle login**
```typescript
// DO THIS!
await supabase.auth.signInWithOAuth({ provider: 'google' })
// That's it! User is logged in.
```

---

### ❌ **WRONG: Storing platform tokens in database**
```typescript
// DON'T DO THIS!
await supabase.from('platform_credentials').insert({
  access_token: youtubeToken,  // ❌ Exposed in database!
  refresh_token: refreshToken   // ❌ Security risk!
})
```

### ✅ **RIGHT: Store in Vault, reference in DB**
```typescript
// DO THIS!
await supabase.from('vault.secrets').insert({
  name: secretName,
  secret: JSON.stringify({ access_token, refresh_token })
})

await supabase.from('platform_credentials').insert({
  vault_secret_name: secretName  // ✅ Just a reference!
})
```

---

## 🎓 Remember

1. **Supabase Auth** = Who are you?
2. **Platform OAuth** = What can we access?

3. **Supabase handles** = Login tokens (automatic)
4. **You handle** = Platform tokens (in Vault)

5. **Client can** = Authenticate users
6. **Client cannot** = See platform tokens

7. **Edge Functions can** = Use platform tokens
8. **Edge Functions must** = Verify user identity

---

## 🚀 Final Checklist

**For User Login (Supabase Auth):**
- [ ] Enable OAuth providers in Supabase dashboard
- [ ] Add sign-in button to frontend
- [ ] Call `supabase.auth.signInWithOAuth()`
- [ ] Create trigger to populate profiles
- [ ] Done! Supabase handles the rest ✅

**For Platform Access (Platform OAuth):**
- [ ] Register app with YouTube/Instagram
- [ ] Create Edge Functions for OAuth flow
- [ ] Store tokens in Supabase Vault
- [ ] Store reference in platform_credentials
- [ ] Implement token refresh logic
- [ ] Test OAuth flow end-to-end
- [ ] Add disconnect functionality

---

**Still confused? Remember the house analogy:**
- 🔑 Supabase Auth = Your house key (login)
- 🚗 Platform OAuth = Your car keys (access content)

Both use OAuth, but for completely different purposes!
