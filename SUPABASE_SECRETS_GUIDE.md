# Supabase Secrets Management Guide for StreamVibe

## 🔐 Architecture Overview

**Principle:** Never store sensitive data (OAuth tokens, API keys) in database tables. Use Supabase Vault instead.

### **Flow Diagram**
```
User OAuth Flow
    ↓
Edge Function receives tokens
    ↓
Store in Supabase Vault (encrypted)
    ↓
Save vault reference in platform_credentials table
    ↓
When needed: Retrieve from Vault (server-side only)
```

---

## 📋 Updated Schema Design

### **platform_credentials Table**
```sql
CREATE TABLE public.platform_credentials (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    platform_id UUID NOT NULL,
    
    -- ✅ Only stores REFERENCE to Vault secret (not the actual token!)
    vault_secret_name TEXT NOT NULL,
    
    -- Token metadata (safe to store)
    token_expires_at TIMESTAMPTZ,
    scopes TEXT[],
    is_active BOOLEAN DEFAULT true,
    last_verified_at TIMESTAMPTZ,
    
    -- Platform info
    platform_account_id TEXT,
    platform_username TEXT,
    
    UNIQUE(user_id, platform_id)
);
```

**Key Changes:**
- ❌ **Removed:** `encrypted_access_token`, `encrypted_refresh_token`
- ✅ **Added:** `vault_secret_name` (just a reference string)
- ✅ **Added:** `platform_account_id`, `platform_username` for UX

---

## 🔧 Implementation Guide

### **1. Store Tokens in Vault (Edge Function)**

```typescript
// functions/oauth-callback/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { code, userId, platformId } = await req.json()
  
  // 1. Exchange code for tokens (platform-specific OAuth flow)
  const tokens = await exchangeCodeForTokens(code, platformId)
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // Required for Vault access
  )
  
  // 2. Create unique vault secret name
  const secretName = `platform_token_${userId}_${platformId}_${Date.now()}`
  
  // 3. Store tokens in Vault as JSON
  const secretPayload = {
    access_token: tokens.access_token,
    refresh_token: tokens.refresh_token,
    token_type: tokens.token_type,
    scope: tokens.scope
  }
  
  // Insert into Vault
  const { error: vaultError } = await supabase
    .from('vault.secrets')
    .insert({
      name: secretName,
      secret: JSON.stringify(secretPayload),
      description: `OAuth tokens for user ${userId} on platform ${platformId}`
    })
  
  if (vaultError) {
    return new Response(JSON.stringify({ error: vaultError.message }), { 
      status: 500 
    })
  }
  
  // 4. Store reference in platform_credentials
  const { error: dbError } = await supabase
    .from('platform_credentials')
    .upsert({
      user_id: userId,
      platform_id: platformId,
      vault_secret_name: secretName,
      token_expires_at: new Date(Date.now() + tokens.expires_in * 1000),
      scopes: tokens.scope.split(' '),
      is_active: true,
      last_verified_at: new Date(),
      platform_account_id: tokens.user_id, // From platform response
      platform_username: tokens.username
    }, {
      onConflict: 'user_id,platform_id'
    })
  
  if (dbError) {
    return new Response(JSON.stringify({ error: dbError.message }), { 
      status: 500 
    })
  }
  
  return new Response(JSON.stringify({ 
    success: true, 
    message: 'Credentials stored securely' 
  }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

---

### **2. Retrieve Tokens from Vault (Edge Function)**

```typescript
// functions/sync-platform/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { handleId, userId } = await req.json()
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // Service role required
  )
  
  // 1. Get handle and platform info
  const { data: handle } = await supabase
    .from('account_handles')
    .select('*, platform_id')
    .eq('id', handleId)
    .single()
  
  // 2. Get credential reference
  const { data: credential } = await supabase
    .from('platform_credentials')
    .select('vault_secret_name, token_expires_at, platform_account_id')
    .eq('user_id', userId)
    .eq('platform_id', handle.platform_id)
    .eq('is_active', true)
    .single()
  
  if (!credential) {
    return new Response('Platform not connected', { status: 401 })
  }
  
  // 3. Check if token is expired
  if (new Date(credential.token_expires_at) < new Date()) {
    // Token expired - need to refresh (implement refresh logic)
    return new Response('Token expired', { status: 401 })
  }
  
  // 4. Retrieve actual tokens from Vault
  const { data: vaultData } = await supabase
    .from('vault.decrypted_secrets')
    .select('secret, decrypted_secret')
    .eq('name', credential.vault_secret_name)
    .single()
  
  if (!vaultData) {
    return new Response('Credentials not found in vault', { status: 500 })
  }
  
  // 5. Parse tokens
  const tokens = JSON.parse(vaultData.decrypted_secret)
  
  // 6. Use tokens to call platform API
  const platformData = await syncFromPlatform(
    tokens.access_token,
    credential.platform_account_id
  )
  
  // 7. Store synced content
  await supabase.from('handle_content').insert(platformData)
  
  return new Response(JSON.stringify({ 
    success: true, 
    synced: platformData.length 
  }))
})

async function syncFromPlatform(accessToken: string, accountId: string) {
  // Platform-specific API calls
  const response = await fetch(`https://platform-api.com/users/${accountId}/videos`, {
    headers: {
      'Authorization': `Bearer ${accessToken}`
    }
  })
  
  return await response.json()
}
```

---

### **3. Token Refresh Flow**

```typescript
// functions/refresh-token/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { userId, platformId } = await req.json()
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  // 1. Get existing credential
  const { data: credential } = await supabase
    .from('platform_credentials')
    .select('vault_secret_name')
    .eq('user_id', userId)
    .eq('platform_id', platformId)
    .single()
  
  // 2. Get current tokens from Vault
  const { data: vaultData } = await supabase
    .from('vault.decrypted_secrets')
    .select('decrypted_secret')
    .eq('name', credential.vault_secret_name)
    .single()
  
  const oldTokens = JSON.parse(vaultData.decrypted_secret)
  
  // 3. Refresh tokens using platform API
  const newTokens = await refreshPlatformTokens(
    oldTokens.refresh_token,
    platformId
  )
  
  // 4. Delete old secret
  await supabase
    .from('vault.secrets')
    .delete()
    .eq('name', credential.vault_secret_name)
  
  // 5. Create new secret
  const newSecretName = `platform_token_${userId}_${platformId}_${Date.now()}`
  
  await supabase
    .from('vault.secrets')
    .insert({
      name: newSecretName,
      secret: JSON.stringify(newTokens)
    })
  
  // 6. Update reference
  await supabase
    .from('platform_credentials')
    .update({
      vault_secret_name: newSecretName,
      token_expires_at: new Date(Date.now() + newTokens.expires_in * 1000),
      last_verified_at: new Date()
    })
    .eq('user_id', userId)
    .eq('platform_id', platformId)
  
  return new Response(JSON.stringify({ success: true }))
})
```

---

### **4. Delete Credentials (Disconnect Platform)**

```typescript
// functions/disconnect-platform/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { userId, platformId } = await req.json()
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  // 1. Get credential
  const { data: credential } = await supabase
    .from('platform_credentials')
    .select('vault_secret_name')
    .eq('user_id', userId)
    .eq('platform_id', platformId)
    .single()
  
  if (credential) {
    // 2. Delete from Vault
    await supabase
      .from('vault.secrets')
      .delete()
      .eq('name', credential.vault_secret_name)
    
    // 3. Delete credential reference
    await supabase
      .from('platform_credentials')
      .delete()
      .eq('user_id', userId)
      .eq('platform_id', platformId)
  }
  
  return new Response(JSON.stringify({ success: true }))
})
```

---

## 🔒 Security Best Practices

### **1. Access Control**
```typescript
// ✅ GOOD: Service role in Edge Functions only
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// ❌ BAD: Never use service role in client-side code
// This would expose all secrets!
```

### **2. RLS Policies**
```sql
-- Vault tables are protected by default
-- Users cannot access vault.secrets or vault.decrypted_secrets
-- Only service_role can access

-- platform_credentials is user-scoped
CREATE POLICY "Users can view own credentials metadata"
ON platform_credentials FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- But they can't see the vault_secret_name directly (optional extra security)
-- Instead, provide a function to check if platform is connected
CREATE OR REPLACE FUNCTION public.is_platform_connected(
  _user_id UUID,
  _platform_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS(
    SELECT 1 FROM platform_credentials
    WHERE user_id = _user_id 
    AND platform_id = _platform_id
    AND is_active = true
  );
$$;
```

### **3. Secret Naming Convention**
```typescript
// Use consistent, identifiable naming
const secretName = `platform_token_${userId}_${platformId}_${timestamp}`

// Prefix categories:
// - platform_token_* : OAuth tokens
// - api_key_*        : API keys
// - webhook_secret_* : Webhook secrets

// This makes it easy to:
// - Audit access
// - Rotate secrets by category
// - Clean up old secrets
```

### **4. Secret Rotation**
```typescript
// Implement automatic rotation
async function rotateSecret(oldSecretName: string, userId: string, platformId: string) {
  const newSecretName = `platform_token_${userId}_${platformId}_${Date.now()}`
  
  // Get old secret
  const { data: oldSecret } = await supabase
    .from('vault.decrypted_secrets')
    .select('decrypted_secret')
    .eq('name', oldSecretName)
    .single()
  
  // Create new secret with same content
  await supabase.from('vault.secrets').insert({
    name: newSecretName,
    secret: oldSecret.decrypted_secret
  })
  
  // Update reference
  await supabase.from('platform_credentials')
    .update({ vault_secret_name: newSecretName })
    .eq('vault_secret_name', oldSecretName)
  
  // Delete old secret
  await supabase.from('vault.secrets')
    .delete()
    .eq('name', oldSecretName)
}

// Schedule rotation (e.g., every 90 days)
```

---

## 📊 Comparison: Database vs Vault

| Aspect | Database Storage | Supabase Vault (Your Choice ✅) |
|--------|-----------------|--------------------------------|
| **Encryption** | You manage | Supabase manages |
| **Key Management** | You handle | Automatic |
| **Audit Trail** | Manual | Automatic |
| **Access Control** | RLS policies | Service role only |
| **Compliance** | Complex | Built-in (SOC2, GDPR) |
| **Backup Safety** | Risk of exposure | Secrets not in backups |
| **Code Complexity** | High | Low |
| **Security** | Medium | High |

---

## 🎯 Setup Checklist

- [ ] Enable Supabase Vault in project settings
- [ ] Create `platform_credentials` table (no encrypted columns)
- [ ] Implement OAuth callback Edge Function
- [ ] Store tokens in Vault (not database)
- [ ] Store only `vault_secret_name` reference
- [ ] Test token retrieval from Vault
- [ ] Implement token refresh flow
- [ ] Add secret cleanup for disconnected platforms
- [ ] Test with multiple platforms
- [ ] Monitor vault access logs

---

## 🧪 Testing

### **Test Script**
```typescript
// Test storing and retrieving
async function testVaultFlow() {
  const userId = 'test-user-id'
  const platformId = 'youtube-platform-id'
  
  // 1. Store in vault
  const secretName = `platform_token_${userId}_${platformId}_test`
  const tokens = {
    access_token: 'ya29.test_token',
    refresh_token: 'refresh.test_token',
    expires_in: 3600
  }
  
  await supabase.from('vault.secrets').insert({
    name: secretName,
    secret: JSON.stringify(tokens)
  })
  
  // 2. Store reference
  await supabase.from('platform_credentials').insert({
    user_id: userId,
    platform_id: platformId,
    vault_secret_name: secretName,
    token_expires_at: new Date(Date.now() + 3600000)
  })
  
  // 3. Retrieve
  const { data: cred } = await supabase
    .from('platform_credentials')
    .select('vault_secret_name')
    .eq('user_id', userId)
    .single()
  
  const { data: secret } = await supabase
    .from('vault.decrypted_secrets')
    .select('decrypted_secret')
    .eq('name', cred.vault_secret_name)
    .single()
  
  const retrievedTokens = JSON.parse(secret.decrypted_secret)
  
  console.log('✅ Tokens match:', retrievedTokens.access_token === tokens.access_token)
  
  // 4. Cleanup
  await supabase.from('platform_credentials').delete().eq('user_id', userId)
  await supabase.from('vault.secrets').delete().eq('name', secretName)
}
```

---

## 💡 Pro Tips

1. **Never log secrets**: Avoid logging vault data in production
   ```typescript
   // ❌ BAD
   console.log('Token:', tokens.access_token)
   
   // ✅ GOOD
   console.log('Token retrieved successfully')
   ```

2. **Use transaction-like patterns**: Ensure vault and DB stay in sync
   ```typescript
   try {
     await insertToVault(secret)
     await updateCredentialReference(secretName)
   } catch (error) {
     // Rollback: delete vault secret if DB update fails
     await deleteFromVault(secretName)
     throw error
   }
   ```

3. **Monitor expired tokens**: Add a scheduled function to check
   ```sql
   SELECT user_id, platform_id, token_expires_at
   FROM platform_credentials
   WHERE token_expires_at < NOW() + INTERVAL '1 day'
   AND is_active = true;
   ```

4. **Batch vault operations**: Minimize vault queries
   ```typescript
   // Fetch all credentials at once, then lookup tokens
   const credentials = await getActiveCredentials(userId)
   const secrets = await Promise.all(
     credentials.map(c => getVaultSecret(c.vault_secret_name))
   )
   ```

---

## 📚 References

- [Supabase Vault Documentation](https://supabase.com/docs/guides/database/vault)
- [OAuth 2.0 Best Practices](https://oauth.net/2/)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Service Role Security](https://supabase.com/docs/guides/api/api-keys)

---

**Questions?**  
The Vault approach is production-ready and follows industry best practices. Tokens are encrypted at rest, access is logged, and you never handle encryption keys directly.
