# StreamVibe - Database Guide

## 📊 Schema Overview

**Schema File**: `database/schema.sql` (StreamVibe v3 Production)

### Statistics

- **Tables**: 33 (8 lookup, 24 data, 1 junction)
- **Enums**: 5 custom types
- **Functions**: 7 (quota management, triggers)
- **Indexes**: 60+ (composite, partial, GIN)
- **RLS Policies**: 20+ comprehensive policies
- **Scheduled Jobs**: 4 pg_cron jobs

## 🏗️ Database Structure

### Lookup Tables (Singular Names)

| Table | Purpose | Records |
|-------|---------|---------|
| `platform` | Social media platforms | 5 (YouTube, Instagram, TikTok, Facebook, Twitter) |
| `content_type` | Content categories | 7 (long_video, short_video, image, carousel, story, reel, post) |
| `subscription_tier` | Pricing tiers | 3 (free, basic, premium) |
| `subscription_status` | Subscription states | 5 (active, trialing, past_due, canceled, paused) |
| `account_status` | Account connection states | 4 (active, inactive, suspended, disconnected) |
| `ai_provider` | AI service providers | 4 (OpenAI, Anthropic, Google, Local) |
| `search_engine` | SEO targets | 4 (Google, Bing, Yandex, IndexNow) |
| `job_type` | Background job types | Reference for audit logs |

### Core Data Tables (Plural Names)

**User Management**
- `users` - User profiles (extends auth.users)
- `user_role` - Role assignments (junction)
- `user_setting` - User preferences
- `subscription` - Subscription + usage tracking

**Platform Integration**
- `platform_connection` - OAuth connections (Vault refs)
- `social_account` - Connected accounts
- `content_item` - Synced content
- `content_revision` - Edit history

**AI Integration**
- `ai_model` - Available models + pricing
- `user_ai_setting` - AI preferences
- `ai_suggestion` - Generated suggestions
- `ai_suggestion_application` - Applied suggestions
- `ai_usage` - Usage tracking for billing

**SEO Integration**
- `trending_keyword` - Cached trending data
- `seo_connection` - Search engine connections
- `seo_submission` - URL submissions
- `seo_usage` - Usage tracking

**System**
- `notification` - User notifications
- `audit_log` - Complete audit trail
- `quota_usage_history` - Analytics
- `cache_store` - Multi-purpose cache

### Enums

```sql
-- Core types
CREATE TYPE visibility_enum AS ENUM ('public', 'private', 'unlisted');
CREATE TYPE app_role_enum AS ENUM ('user', 'admin', 'moderator');
CREATE TYPE notification_type_enum AS ENUM ('info', 'success', 'warning', 'error');
CREATE TYPE action_mode_enum AS ENUM ('auto', 'manual', 'disabled');
```

## 🔑 Key Relationships

```
users (auth.users)
  ├─→ user_setting (1:1)
  ├─→ user_role (1:N)
  ├─→ subscription (1:1)
  ├─→ platform_connection (1:N)
  │     ├─→ social_account (1:N)
  │     │     └─→ content_item (1:N)
  │     │           ├─→ content_revision (1:N)
  │     │           ├─→ ai_suggestion (1:N)
  │     │           └─→ seo_submission (1:N)
  │     └─→ (Vault: encrypted tokens)
  ├─→ seo_connection (1:N)
  │     └─→ seo_submission (1:N)
  ├─→ notification (1:N)
  ├─→ audit_log (1:N)
  └─→ quota_usage_history (1:N)

subscription
  ├─→ subscription_tier (N:1) - Quotas & pricing
  └─→ subscription_status (N:1) - Current state

content_item
  ├─→ platform (N:1)
  ├─→ content_type (N:1)
  └─→ social_account (N:1)

ai_suggestion
  ├─→ ai_provider (N:1)
  ├─→ ai_model (N:1)
  └─→ content_item (N:1)
```

## 🔐 Security Model

### Row Level Security (RLS)

**All tables with user data have RLS enabled**

```sql
-- Example: Users can only access their own records
CREATE POLICY users_select_own ON users
FOR SELECT USING (auth.uid() = id);

-- Example: Derived ownership through joins
CREATE POLICY content_item_select_own ON content_item
FOR ALL USING (
  auth.uid() IN (
    SELECT user_id FROM social_account
    WHERE id = content_item.social_account_id
  )
);

-- Example: Public content visible to all
CREATE POLICY content_item_select_public ON content_item
FOR SELECT USING (
  visibility = 'public' AND deleted_at IS NULL
);

-- Example: Admin override
CREATE POLICY admin_all_access ON users
FOR ALL USING (has_role(auth.uid(), 'admin'));
```

### Vault Integration

```sql
-- ❌ NEVER store sensitive tokens in database
platform_connection {
  vault_secret_name TEXT NOT NULL  -- "oauth_youtube_user123"
  -- NO access_token column!
  -- NO refresh_token column!
}

-- ✅ Access tokens via Edge Function with service role
-- Edge Function code:
const { data, error } = await supabase.rpc('vault.get_secret', {
  secret_name: 'oauth_youtube_user123'
});
```

## 📝 Key Functions

### Quota Management

```sql
-- Check if user has quota remaining
SELECT check_quota(user_id, 'sync');  -- Returns BOOLEAN

-- Increment quota usage
SELECT increment_quota(
  user_id,
  'sync',           -- quota_type
  1,                -- amount
  'content_item',   -- entity_type
  content_id,       -- entity_id
  'manual_sync'     -- reason
);

-- Decrement quota (e.g., undo operation)
SELECT decrement_quota(user_id, 'ai_analysis', 1, 'refund');

-- Reset all quotas (called by pg_cron monthly)
SELECT reset_quotas();
```

### Role Checks

```sql
-- Check if user has specific role
SELECT has_role(auth.uid(), 'admin');  -- Returns BOOLEAN

-- Usage in RLS policy
CREATE POLICY admin_bypass ON sensitive_table
FOR ALL USING (has_role(auth.uid(), 'admin'));
```

### Triggers

```sql
-- Auto-update timestamps (applied to 10 tables)
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Prevent deletion of accounts with active content
CREATE TRIGGER prevent_account_deletion
BEFORE DELETE ON social_account
FOR EACH ROW EXECUTE FUNCTION prevent_account_deletion_with_content();
```

## 📈 Indexing Strategy

### Composite Indexes (Multi-column queries)

```sql
-- Common query: Get user's content for platform, sorted by date
CREATE INDEX idx_content_item_account 
ON content_item(social_account_id, published_at DESC);

-- Common query: Get active connections for user-platform pair
CREATE INDEX idx_platform_connection_user_platform 
ON platform_connection(user_id, platform_id) 
WHERE is_active = true;
```

### Partial Indexes (Filtered, smaller)

```sql
-- Index only active records (90% smaller)
CREATE INDEX idx_active_platform_connections 
ON platform_connection(user_id, platform_id) 
WHERE is_active = true;

-- Index only unread notifications
CREATE INDEX idx_unread_notifications 
ON notification(user_id, created_at DESC) 
WHERE is_read = false;

-- Index only non-deleted content
CREATE INDEX idx_content_item_active 
ON content_item(social_account_id, published_at DESC) 
WHERE deleted_at IS NULL;
```

### GIN Indexes (Arrays, JSONB, Full-text)

```sql
-- Array contains queries
CREATE INDEX idx_content_tags 
ON content_item USING GIN(tags);

CREATE INDEX idx_content_hashtags 
ON content_item USING GIN(hashtags);

-- JSONB queries
CREATE INDEX idx_cache_value 
ON cache_store USING GIN(value);

-- Full-text search (generated column)
CREATE INDEX idx_content_search 
ON content_item USING GIN(search_vector);
```

### Foreign Key Indexes

```sql
-- All foreign keys automatically indexed for join performance
-- Example:
CREATE INDEX idx_social_account_connection 
ON social_account(connection_id);

CREATE INDEX idx_content_item_account 
ON content_item(social_account_id);
```

## 🔍 Common Queries

### User Dashboard

```sql
-- Get user's content summary by platform
SELECT 
  p.display_name AS platform,
  COUNT(*) AS total_content,
  SUM(views_count) AS total_views,
  SUM(likes_count) AS total_likes,
  SUM(comments_count) AS total_comments
FROM content_item ci
JOIN social_account sa ON ci.social_account_id = sa.id
JOIN platform p ON ci.platform_id = p.id
WHERE sa.user_id = $1
  AND ci.deleted_at IS NULL
GROUP BY p.id, p.display_name
ORDER BY total_views DESC;
```

### Subscription Usage

```sql
-- Current billing cycle usage with limits
SELECT 
  s.syncs_used,
  t.max_syncs_per_month,
  ROUND(100.0 * s.syncs_used / NULLIF(t.max_syncs_per_month, 0), 2) AS sync_percent,
  
  s.ai_analyses_used,
  t.max_ai_analyses_per_month,
  ROUND(100.0 * s.ai_analyses_used / NULLIF(t.max_ai_analyses_per_month, 0), 2) AS ai_percent,
  
  s.seo_submissions_used,
  t.max_seo_submissions_per_month,
  ROUND(100.0 * s.seo_submissions_used / NULLIF(t.max_seo_submissions_per_month, 0), 2) AS seo_percent,
  
  s.cycle_end_date,
  t.display_name AS tier_name
FROM subscription s
JOIN subscription_tier t ON s.tier_id = t.id
WHERE s.user_id = $1;
```

### Content Search

```sql
-- Full-text search with ranking
SELECT 
  ci.*,
  ts_rank(ci.search_vector, query) AS rank
FROM content_item ci,
     plainto_tsquery('english', $1) query
WHERE ci.search_vector @@ query
  AND ci.deleted_at IS NULL
  AND ci.visibility = 'public'
ORDER BY rank DESC
LIMIT 20;
```

### AI Suggestions Performance

```sql
-- Top trending keywords from AI suggestions
SELECT 
  keyword,
  COUNT(*) AS suggestion_count,
  AVG(trending_score) AS avg_score
FROM ai_suggestion,
LATERAL unnest(trending_keywords) AS keyword
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY keyword
ORDER BY suggestion_count DESC
LIMIT 20;
```

## 🕐 Scheduled Jobs (pg_cron)

```sql
-- Reset monthly quotas (1st of each month at midnight)
SELECT cron.schedule(
  'reset-monthly-quotas',
  '0 0 1 * *',
  $$ SELECT reset_quotas() $$
);

-- Cleanup expired notifications (daily at 2 AM)
SELECT cron.schedule(
  'cleanup-notifications',
  '0 2 * * *',
  $$ 
    DELETE FROM notification 
    WHERE expires_at < NOW() 
  $$
);

-- Cleanup expired cache (daily at 3 AM)
SELECT cron.schedule(
  'cleanup-cache',
  '0 3 * * *',
  $$ 
    DELETE FROM cache_store 
    WHERE expires_at < NOW() 
  $$
);

-- Verify platform connections (every 6 hours)
SELECT cron.schedule(
  'verify-platform-connections',
  '0 */6 * * *',
  $$ 
    UPDATE platform_connection 
    SET is_verified = false 
    WHERE token_expires_at < NOW() + INTERVAL '1 day'
  $$
);
```

## 🚀 Deployment

### Initial Setup

```bash
# 1. Create Supabase project
# Visit: https://supabase.com/dashboard

# 2. Enable required extensions
# Run in SQL Editor:
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

# 3. Deploy schema
# Copy contents of database/schema.sql
# Paste into SQL Editor and run

# 4. Verify installation
SELECT count(*) FROM information_schema.tables 
WHERE table_schema = 'public';
-- Should return 33
```

### Migrations

```bash
# Future migrations will be in database/migrations/
# Example:
database/migrations/
  ├── 001_initial_schema.sql (already applied)
  ├── 002_add_new_feature.sql
  └── 003_optimize_indexes.sql
```

## 📊 Performance Tips

### Query Optimization

```sql
-- ✅ GOOD: Uses composite index
SELECT * FROM content_item
WHERE social_account_id = $1
ORDER BY published_at DESC
LIMIT 20;

-- ❌ BAD: Scans entire table
SELECT * FROM content_item
WHERE description LIKE '%keyword%';

-- ✅ GOOD: Uses GIN index on search_vector
SELECT * FROM content_item
WHERE search_vector @@ plainto_tsquery('keyword');
```

### Batch Operations

```sql
-- ✅ GOOD: Single transaction
BEGIN;
INSERT INTO content_item VALUES (...), (...), (...);
COMMIT;

-- ❌ BAD: Multiple round-trips
INSERT INTO content_item VALUES (...);
INSERT INTO content_item VALUES (...);
INSERT INTO content_item VALUES (...);
```

### Pagination

```sql
-- ✅ GOOD: Cursor-based pagination
SELECT * FROM content_item
WHERE published_at < $last_cursor
ORDER BY published_at DESC
LIMIT 20;

-- ⚠️ OK: Offset pagination (slower for large offsets)
SELECT * FROM content_item
ORDER BY published_at DESC
LIMIT 20 OFFSET 100;
```

## 🔧 Maintenance

### Database Size Monitoring

```sql
-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check index sizes
SELECT 
  schemaname,
  indexname,
  pg_size_pretty(pg_relation_size(schemaname||'.'||indexname)) AS size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(schemaname||'.'||indexname) DESC;
```

### Vacuum and Analyze

```sql
-- Run periodically to maintain performance
VACUUM ANALYZE content_item;
VACUUM ANALYZE subscription;

-- Full vacuum (requires maintenance window)
VACUUM FULL;
```

## 📚 References

- **Schema File**: `database/schema.sql`
- **Supabase Docs**: https://supabase.com/docs/guides/database
- **PostgreSQL Docs**: https://www.postgresql.org/docs/15/
- **pg_cron**: https://github.com/citusdata/pg_cron
