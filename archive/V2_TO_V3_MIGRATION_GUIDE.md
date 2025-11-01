# StreamVibe v2 to v3 Migration Guide

## Overview

This document details all changes from v2 to v3 schema, providing a comprehensive migration path for the production-ready normalized database.

## Key Philosophy Changes

1. **Consistent Naming**: Singular for lookup tables, plural for data tables
2. **Normalization**: Extracted subscription tiers, removed redundant columns
3. **Performance**: Added composite, partial, and GIN indexes
4. **Flexibility**: Replaced some enums with lookup tables
5. **Standards**: All booleans use `is_*`, all timestamps use `*_at`

## Table Renaming

| v2 Name | v3 Name | Reason |
|---------|---------|--------|
| `profiles` | `users` | More accurate (extends auth.users) |
| `user_preferences` | `user_setting` | Singular (one-to-one with user) |
| `supported_platform_types` | `platform` | Singular lookup, removed redundant prefix |
| `supported_content_types` | `content_type` | Singular lookup, removed redundant prefix |
| `supported_job_types` | `job_type` | Singular lookup, removed redundant prefix |
| `platform_credentials` | `platform_connection` | More descriptive of relationship |
| `account_handles` | `social_account` | More descriptive, clearer purpose |
| `handle_content` | `content_item` | More generic, clearer purpose |
| `content_edit_history` | `content_revision` | More standard terminology |
| `ai_content_suggestions` | `ai_suggestion` | Shorter, not all suggestions are content-related |
| `seo_payloads` | `seo_submission` | More descriptive of action |

## New Tables (v3 Only)

### Normalization Improvements

1. **`subscription_tier`** - Extracted from `subscription_settings`
   - Separates tier definitions from user subscriptions
   - Enables easy tier management without affecting users
   - Fields: quotas, pricing, Stripe IDs

2. **`subscription_status`** - Replaced enum with lookup table
   - More flexible than enum (can add statuses without migration)
   - Fields: slug, display_name, is_active_state

3. **`account_status`** - New lookup for social account statuses
   - Standardizes status values
   - Fields: slug, display_name

### AI Integration Tables

4. **`ai_provider`** - AI service providers
   - Fields: slug, display_name, base_url, capabilities

5. **`ai_model`** - Available AI models
   - Fields: provider_id, model_name, pricing, context limits

6. **`user_ai_setting`** - User AI preferences
   - Fields: preferred_provider, preferred_model, tone

7. **`ai_suggestion_application`** - Track applied AI suggestions
   - Junction table for which fields were applied
   - Fields: suggestion_id, field_name, applied_value

8. **`ai_usage`** - AI API usage tracking
   - Fields: tokens, cost, billing_cycle

9. **`trending_keyword`** - Cached trending keywords
   - Fields: keyword, platform, trending_score, validity period

### SEO Integration Tables

10. **`search_engine`** - Supported search engines
    - Fields: slug, display_name, api_endpoint, supports_indexnow

11. **`seo_connection`** - User search engine connections
    - Fields: user_id, search_engine_id, vault_secret_name

12. **`seo_usage`** - SEO API usage tracking
    - Fields: operation_type, urls_count, billing_cycle

### Caching

13. **`cache_store`** - Multi-purpose cache
    - Replaces need for Stripe product/price tables
    - Fields: key, value (JSONB), category, expires_at

## Column Changes

### Removed Redundant Columns

#### `subscription` (formerly `subscription_settings`)
**Removed:**
- `user_social_accounts_used` - Derivable from `COUNT(social_account WHERE user_id)`
- Tier-specific columns moved to `subscription_tier` table

**Added:**
- `tier_id UUID` - References `subscription_tier`
- `status_id UUID` - References `subscription_status`

#### `social_account` (formerly `account_handles`)
**Removed:**
- `user_id` column - Derivable from `platform_connection.user_id`

**Changed:**
- Now requires `connection_id` to derive user ownership

#### `content_item` (formerly `handle_content`)
**Removed:**
- Direct `user_id` reference - Derivable via `social_account`

**Changed:**
- `social_account_id` is primary foreign key
- `platform_id` kept for denormalization (performance)

### Standardized Column Naming

All boolean columns now use `is_*` prefix:
- `active` → `is_active`
- `verified` → `is_verified`
- `primary` → `is_primary`
- `applied` → `is_applied`

All timestamp columns now use `*_at` suffix:
- `last_sync` → `last_synced_at`
- `next_sync` → `next_sync_at`
- `expires` → `expires_at`
- `canceled` → `canceled_at`

### Enhanced Columns

#### `content_item.search_vector`
- Now a GENERATED column (auto-maintained)
- Combines title (weight A), description (weight B), tags (weight C)

#### `ai_suggestion` scoring fields
- Added `trending_score`, `seo_score`, `readability_score`, `confidence_score`
- All DECIMAL(3,2) from 0.00 to 1.00

## Index Improvements

### New Composite Indexes

```sql
-- Content by account and date
CREATE INDEX idx_content_item_account 
ON content_item(social_account_id, published_at DESC) 
WHERE deleted_at IS NULL;

-- Active connections by user and platform
CREATE INDEX idx_platform_connection_user_platform 
ON platform_connection(user_id, platform_id) 
WHERE is_active = true;

-- Subscription billing cycles
CREATE INDEX idx_subscription_billing_cycle 
ON subscription(cycle_end_date) 
WHERE is_auto_renew_enabled = true;
```

### New Partial Indexes

Partial indexes reduce index size and improve performance:

```sql
-- Only index unread notifications
CREATE INDEX idx_notification_user_unread 
ON notification(user_id, created_at DESC) 
WHERE is_read = false AND (expires_at IS NULL OR expires_at > NOW());

-- Only index active connections
CREATE INDEX idx_platform_connection_user_platform 
ON platform_connection(user_id, platform_id) 
WHERE is_active = true;

-- Only index pending submissions
CREATE INDEX idx_seo_submission_status 
ON seo_submission(status, next_retry_at) 
WHERE status IN ('pending', 'failed');
```

### New GIN Indexes

For array and JSONB columns:

```sql
-- Array search
CREATE INDEX idx_content_item_tags 
ON content_item USING GIN(tags);

CREATE INDEX idx_content_item_hashtags 
ON content_item USING GIN(hashtags);

-- Full-text search
CREATE INDEX idx_content_item_search 
ON content_item USING GIN(search_vector);
```

## Function Changes

### Updated Function Signatures

#### `check_quota()`
**v2:**
```sql
check_quota(p_user_id UUID, p_quota_type TEXT)
```

**v3:** (Same, but implementation changed)
- Now reads from `subscription_tier` table
- Uses `subscription.tier_id` to get limits

#### `increment_quota()` / `decrement_quota()`
**v3:** Enhanced with better tracking
- Stores billing cycle timestamps
- More detailed logging in `quota_usage_history`

### New Functions

#### `reset_quotas()`
- Called by pg_cron monthly
- Resets all active subscription quotas
- Moves billing cycle forward

#### `update_updated_at_column()`
- Generic trigger function for auto-updating timestamps
- Used across all tables with `updated_at`

## RLS Policy Changes

### More Granular Policies

**v3 adds separate policies for:**
- Public content visibility
- Admin overrides
- Cross-table ownership checks

**Example:**
```sql
-- Users can manage content for their social accounts
CREATE POLICY content_item_all_own ON content_item
FOR ALL USING (
    auth.uid() IN (
        SELECT user_id FROM social_account
        WHERE id = content_item.social_account_id
    )
);

-- Anyone can view public content
CREATE POLICY content_item_select_public ON content_item
FOR SELECT USING (
    visibility = 'public' AND deleted_at IS NULL
);
```

## Scheduled Jobs (pg_cron)

### New Jobs in v3

1. **Reset Monthly Quotas**
   ```sql
   '0 0 1 * *' -- First of month at midnight
   SELECT reset_quotas()
   ```

2. **Cleanup Expired Notifications**
   ```sql
   '0 2 * * *' -- Daily at 2 AM
   DELETE FROM notification WHERE expires_at < NOW()
   ```

3. **Cleanup Expired Cache**
   ```sql
   '0 3 * * *' -- Daily at 3 AM
   DELETE FROM cache_store WHERE expires_at < NOW()
   ```

4. **Verify Platform Connections**
   ```sql
   '0 */6 * * *' -- Every 6 hours
   UPDATE platform_connection
   SET is_active = false WHERE token_expires_at < NOW()
   ```

## Migration Strategy

### Phase 1: Schema Preparation

```sql
-- 1. Create v3 tables alongside v2 (no disruption)
\i StreamVibe_v3_production.sql

-- 2. Rename v2 tables (backup)
ALTER TABLE profiles RENAME TO profiles_v2_backup;
ALTER TABLE user_preferences RENAME TO user_preferences_v2_backup;
-- ... etc
```

### Phase 2: Data Migration

```sql
-- 1. Migrate users
INSERT INTO public.users (id, email, full_name, avatar_url, timezone, language, is_onboarded, onboarded_at, created_at, updated_at)
SELECT id, email, full_name, avatar_url, timezone, language, onboarding_complete, onboarded_at, created_at, updated_at
FROM profiles_v2_backup;

-- 2. Extract and migrate subscription tiers
INSERT INTO public.subscription_tier (slug, display_name, max_social_accounts, max_syncs_per_month, max_ai_analyses_per_month, max_seo_submissions_per_month, price_cents, currency)
SELECT DISTINCT
    tier,
    tier,
    max_social_accounts,
    max_syncs_per_month,
    max_ai_analyses_per_month,
    max_seo_submissions_per_month,
    0, -- Set actual prices separately
    'usd'
FROM subscription_settings_v2_backup;

-- 3. Migrate subscriptions
INSERT INTO public.subscription (
    id, user_id, tier_id, status_id,
    syncs_used, ai_analyses_used, seo_submissions_used,
    cycle_start_date, cycle_end_date,
    stripe_customer_id, stripe_subscription_id,
    created_at, updated_at
)
SELECT 
    s.id,
    s.user_id,
    (SELECT id FROM subscription_tier WHERE slug = s.tier),
    (SELECT id FROM subscription_status WHERE slug = s.status),
    s.syncs_used,
    s.ai_analyses_used,
    s.seo_submissions_used,
    s.cycle_start_date,
    s.cycle_end_date,
    s.stripe_customer_id,
    s.stripe_subscription_id,
    s.created_at,
    s.updated_at
FROM subscription_settings_v2_backup s;

-- 4. Migrate platform connections
INSERT INTO public.platform_connection (
    id, user_id, platform_id, vault_secret_name,
    scopes, token_expires_at,
    platform_user_id, platform_username,
    is_active, is_verified, last_verified_at,
    created_at, updated_at
)
SELECT 
    id,
    user_id,
    platform_id,
    vault_secret_name,
    scopes,
    token_expires_at,
    platform_user_id,
    platform_username,
    active,
    verified,
    last_verified,
    created_at,
    updated_at
FROM platform_credentials_v2_backup;

-- 5. Migrate social accounts
INSERT INTO public.social_account (
    id, user_id, connection_id, platform_id, status_id,
    account_name, account_url, description,
    follower_count, following_count, post_count,
    sync_mode, last_synced_at, next_sync_at,
    visibility, is_primary,
    deleted_at, created_at, updated_at
)
SELECT 
    a.id,
    c.user_id, -- Derive from connection
    a.connection_id,
    a.platform_id,
    (SELECT id FROM account_status WHERE slug = a.status),
    a.account_name,
    a.account_url,
    a.description,
    a.follower_count,
    a.following_count,
    a.post_count,
    a.sync_mode,
    a.last_sync,
    a.next_sync,
    a.visibility,
    a.primary_handle,
    a.deleted_at,
    a.created_at,
    a.updated_at
FROM account_handles_v2_backup a
JOIN platform_credentials_v2_backup c ON a.connection_id = c.id;

-- 6. Migrate content items
INSERT INTO public.content_item (
    id, social_account_id, platform_id, content_type_id,
    platform_content_id, platform_url,
    title, description, thumbnail_url, media_url, duration_seconds,
    views_count, likes_count, comments_count, shares_count,
    tags, hashtags, category, language,
    published_at, synced_at, visibility, deleted_at,
    created_at, updated_at
)
SELECT 
    id,
    account_handle_id,
    platform_id,
    content_type_id,
    platform_content_id,
    platform_url,
    title,
    description,
    thumbnail_url,
    media_url,
    duration_seconds,
    views_count,
    likes_count,
    comments_count,
    shares_count,
    tags,
    hashtags,
    category,
    language,
    published_at,
    synced_at,
    visibility,
    deleted_at,
    created_at,
    updated_at
FROM handle_content_v2_backup;

-- 7. Migrate remaining tables similarly...
```

### Phase 3: Validation

```sql
-- Verify counts match
SELECT 'users' as table_name, COUNT(*) as v2_count FROM profiles_v2_backup
UNION ALL
SELECT 'users', COUNT(*) FROM users;

SELECT 'subscriptions' as table_name, COUNT(*) as v2_count FROM subscription_settings_v2_backup
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscription;

-- Verify data integrity
SELECT 
    COUNT(*) as orphaned_content
FROM content_item c
LEFT JOIN social_account s ON c.social_account_id = s.id
WHERE s.id IS NULL;
-- Should return 0
```

### Phase 4: Cutover

```sql
-- 1. Stop application
-- 2. Final incremental migration
-- 3. Drop v2 backup tables (keep SQL dumps!)
DROP TABLE profiles_v2_backup;
DROP TABLE subscription_settings_v2_backup;
-- ... etc

-- 4. Restart application with v3 schema
```

## Breaking Changes for Application Code

### API Endpoint Changes

| v2 Endpoint | v3 Endpoint | Notes |
|-------------|-------------|-------|
| `GET /profiles/:id` | `GET /users/:id` | Table renamed |
| `GET /account-handles` | `GET /social-accounts` | Table renamed |
| `GET /handle-content` | `GET /content-items` | Table renamed |
| `POST /ai-content-suggestions` | `POST /ai-suggestions` | Table renamed |
| `POST /seo-payloads` | `POST /seo-submissions` | Table renamed |

### GraphQL Type Changes

```graphql
# v2
type Profile {
  id: UUID!
  onboarding_complete: Boolean
  # ...
}

# v3
type User {
  id: UUID!
  is_onboarded: Boolean
  # ...
}
```

### Function Call Changes

```typescript
// v2
const { data } = await supabase
  .from('profiles')
  .select('*')
  .eq('id', userId);

// v3
const { data } = await supabase
  .from('users')
  .select('*')
  .eq('id', userId);
```

### Quota Check Changes

```typescript
// v2 - Direct column access
const { subscription } = user;
if (subscription.syncs_used < subscription.max_syncs_per_month) {
  // allowed
}

// v3 - Use tier relation
const { subscription } = user;
if (subscription.syncs_used < subscription.tier.max_syncs_per_month) {
  // allowed
}

// OR use function
const { data: canSync } = await supabase.rpc('check_quota', {
  p_user_id: userId,
  p_quota_type: 'sync'
});
```

## Testing Checklist

- [ ] All table migrations complete
- [ ] Row counts match v2
- [ ] No orphaned foreign keys
- [ ] All indexes created
- [ ] All triggers active
- [ ] RLS policies tested for:
  - [ ] Own data access
  - [ ] Public data access
  - [ ] Admin access
  - [ ] Unauthorized access blocked
- [ ] Functions return correct results
- [ ] pg_cron jobs scheduled
- [ ] Cache operations working
- [ ] Quota functions working
- [ ] Full-text search working
- [ ] API endpoints updated
- [ ] Frontend updated
- [ ] Integration tests passing
- [ ] Load testing passed

## Rollback Plan

```sql
-- If critical issues found:

-- 1. Stop application
-- 2. Restore v2 tables from backup
ALTER TABLE profiles_v2_backup RENAME TO profiles;
ALTER TABLE subscription_settings_v2_backup RENAME TO subscription_settings;
-- ... etc

-- 3. Restart application on v2
-- 4. Investigate issues
-- 5. Fix and retry migration
```

## Performance Improvements Expected

1. **Faster quota checks** - Normalized tier table, indexed queries
2. **Faster content search** - Generated search_vector, GIN indexes
3. **Faster user dashboards** - Composite indexes on common queries
4. **Reduced storage** - Removed redundant columns
5. **Faster filtered queries** - Partial indexes on active/pending records
6. **Faster array searches** - GIN indexes on tags, hashtags, keywords

## Post-Migration Tasks

1. **Update documentation**
   - API docs with new table names
   - GraphQL schema
   - ERD diagrams

2. **Monitor performance**
   - Query execution times
   - Index usage statistics
   - Cache hit rates

3. **Optimize as needed**
   - Add materialized views for dashboards
   - Consider partitioning for large tables
   - Adjust pg_cron schedules

4. **Update SDKs/clients**
   - TypeScript types
   - Mobile app models
   - CLI tools

## Conclusion

The v3 schema provides:
- ✅ Better normalization
- ✅ Consistent naming conventions
- ✅ Improved performance via indexes
- ✅ Greater flexibility via lookup tables
- ✅ Enhanced security via granular RLS
- ✅ Better maintainability

Total effort: ~2-4 hours for migration execution
Recommended timeline: Plan 1 week for testing before production deployment
