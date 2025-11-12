# Edge Functions Update Guide for PR#27

## Overview

The revised OAuth migration (`20251111220000_fix_oauth_blockers.sql`) fixes critical schema conflicts. Edge Functions must be updated to work with the corrected schema.

## Required Changes

### 1. Use `vault_upsert()` Instead of `vault_insert()`

**Current code (WILL FAIL on reconnection):**
```typescript
// In oauth-youtube-callback, oauth-instagram-callback, oauth-tiktok-callback
await supabase.rpc('vault_insert', {
  p_name: vaultKey,
  p_secret: JSON.stringify(tokenData)
});
```

**Updated code (handles reconnection):**
```typescript
// Use vault_upsert for insert-or-update pattern
await supabase.rpc('vault_upsert', {
  p_name: vaultKey,
  p_secret: JSON.stringify(tokenData)
});
```

### 2. Use `platform_id` UUID Instead of `platform` TEXT

**Current schema expectation:**
```typescript
// WRONG - doesn't match existing schema
await supabase.from('social_account').insert({
  user_id: userId,
  platform: 'youtube', // ❌ This column doesn't exist
  platform_user_id: channelId,
  // ...
});
```

**Corrected schema usage:**
```typescript
// Get platform_id from platform table first
const { data: platform } = await supabase
  .from('platform')
  .select('id')
  .eq('slug', 'youtube')
  .single();

// Then insert with platform_id
await supabase.from('social_account').insert({
  user_id: userId,
  connection_id: connectionId, // Required FK
  platform_id: platform.id, // ✅ Use UUID FK
  status_id: statusId, // Required FK
  account_name: channelTitle, // Required, existing column
  platform_user_id: channelId,
  display_name: channelTitle, // New column
  handle: channelCustomUrl,
  profile_url: `https://youtube.com/channel/${channelId}`,
  avatar_url: channelThumbnail,
  follower_count: subscriberCount, // ✅ Use existing column
  post_count: videoCount, // ✅ Use existing column (not total_content_count)
  vault_key: vaultKey,
  // ...
});
```

### 3. Column Mapping Reference

| Edge Function Uses | Actual Database Column | Note |
|--------------------|------------------------|------|
| `platform` (TEXT) | `platform_id` (UUID FK) | Must lookup platform table first |
| `followers_count` | `follower_count` | Existing column, use this |
| `total_content_count` | `post_count` | Existing column, use this |
| `display_name` | `display_name` | New column, OK to use |
| `platform_user_id` | `platform_user_id` | New column, OK to use |
| `vault_key` | `vault_key` | New column, OK to use |
| `handle` | `handle` | New column, OK to use |

### 4. Missing Required Columns

The Edge Functions must provide values for existing required columns:

```typescript
{
  connection_id: connectionId, // UUID - must create platform_connection first
  status_id: statusId, // UUID - lookup from account_status table
  account_name: channelTitle, // TEXT NOT NULL - existing column
}
```

## Example: Complete OAuth Callback Flow

### Step 1: Get Foreign Key IDs

```typescript
// Get platform_id
const { data: platform } = await supabase
  .from('platform')
  .select('id')
  .eq('slug', 'youtube')
  .single();

// Get status_id (e.g., "active")
const { data: status } = await supabase
  .from('account_status')
  .select('id')
  .eq('name', 'active')
  .single();
```

### Step 2: Create or Update platform_connection

```typescript
const vaultKey = `youtube_tokens_${userId}_${channelId}`;

// Store tokens using vault_upsert
const { data: secretId } = await supabase.rpc('vault_upsert', {
  p_name: vaultKey,
  p_secret: JSON.stringify({
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_at: expiresAt,
    scope: scope
  })
});

// Upsert platform_connection
const { data: connection } = await supabase
  .from('platform_connection')
  .upsert({
    user_id: userId,
    platform_id: platform.id,
    is_active: true,
    last_connected_at: new Date().toISOString()
  }, {
    onConflict: 'user_id,platform_id'
  })
  .select('id')
  .single();
```

### Step 3: Create or Update social_account

```typescript
const { data: socialAccount } = await supabase
  .from('social_account')
  .upsert({
    user_id: userId,
    connection_id: connection.id,
    platform_id: platform.id,
    status_id: status.id,
    account_name: channelTitle, // Required existing column
    platform_user_id: channelId, // New column
    display_name: channelTitle, // New column
    handle: channelCustomUrl, // New column
    profile_url: `https://youtube.com/channel/${channelId}`,
    avatar_url: channelThumbnail,
    follower_count: subscriberCount, // Existing column
    post_count: videoCount, // Existing column
    vault_key: vaultKey, // New column
    is_active: true, // New column
    last_synced_at: new Date().toISOString() // Existing column
  }, {
    onConflict: 'user_id,platform_id,platform_user_id'
  })
  .select()
  .single();
```

### Step 4: Update total followers count

```typescript
// Call helper function to aggregate follower counts
await supabase.rpc('update_total_followers', {
  p_user_id: userId
});
```

## Testing Checklist

After updating Edge Functions:

- [ ] First-time OAuth connection works (YouTube)
- [ ] Tokens stored in Vault with `vault_upsert`
- [ ] social_account created with all required fields
- [ ] platform_connection created and linked
- [ ] Reconnection works (same user, same channel)
- [ ] Tokens updated on reconnection (not error)
- [ ] total_followers_count updated correctly
- [ ] Test with Instagram OAuth
- [ ] Test with TikTok OAuth
- [ ] Verify no empty strings in platform_user_id

## Files to Update

Based on the existing Edge Function structure:

1. `supabase/functions/oauth-youtube-init/index.ts`
2. `supabase/functions/oauth-youtube-callback/index.ts`
3. `supabase/functions/oauth-instagram-init/index.ts`
4. `supabase/functions/oauth-instagram-callback/index.ts`
5. `supabase/functions/oauth-tiktok-init/index.ts`
6. `supabase/functions/oauth-tiktok-callback/index.ts`

## Migration Path

1. ✅ **Deploy revised migration** - Already fixed in PR#27
2. ⏳ **Update Edge Functions** - Use this guide
3. ⏳ **Deploy Edge Functions** - `supabase functions deploy`
4. ⏳ **Test OAuth flows** - All 3 platforms
5. ⏳ **Close PR#27** - After successful testing

## Notes

- The migration is now idempotent (uses `IF NOT EXISTS` and `CREATE OR REPLACE`)
- Can be run multiple times without errors
- Handles existing data gracefully (no blanket defaults)
- Compatible with existing schema architecture
