# 🗺️ StreamVibe Phase-by-Phase Implementation Roadmap

**Goal:** Production-ready, scalable, secured backend API with full CI/CD and phase-by-phase testing

---

## 📊 Implementation Phases Overview

```
Phase 1: User Onboarding (Foundation)
├── Database: Module 000 (Base Core)
├── Edge Functions: auth-profile-setup
├── Features: Signup, Profile, Subscriptions
└── Testing: User creation, quota assignment

Phase 2: Platform OAuth (Connection)
├── Database: Module 001 (Platform Connections)
├── Edge Functions: oauth-*-init, oauth-*-callback (YouTube, Instagram, TikTok)
├── Features: OAuth flow, Token storage (Vault), Multi-platform
└── Testing: OAuth flow, token refresh, account linking

Phase 3: Content Sync (Data Ingestion)
├── Database: Module 002 (Content Management)
├── Edge Functions: sync-youtube, sync-instagram, sync-tiktok
├── Features: Content sync, Full-text search, Deduplication
└── Testing: Sync content, search, soft delete

Phase 4: AI Enhancement (Intelligence)
├── Database: Module 003 (AI Integration)
├── Edge Functions: ai-generate-tags
├── Features: AI tagging, Cost tracking, Multi-provider
└── Testing: Generate tags, track costs, quota enforcement

Phase 5: SEO Integration (Discoverability)
├── Database: Module 004 (SEO Integration)
├── Edge Functions: get-seo-metadata, robots, sitemap
├── Features: Google/Bing indexing, Auto-submission
└── Testing: Submit URLs, check status, quota enforcement

Phase 6: Discovery Platform (Public Features)
├── Database: Module 005 (Discovery Platform)
├── Edge Functions: browse-*, search-*, get-trending, track-click
├── Features: Categories, Trending, Click tracking
└── Testing: Browse, search, trending algorithm

Phase 7: Async Infrastructure (Background Processing)
├── Database: Module 006 (Async Infrastructure)
├── Edge Functions: Job processor, webhook handler
├── Features: Job queue, Webhooks, Caching, Auto-retry
└── Testing: Jobs, webhooks, deduplication, caching
```

---

## 🎯 Phase 1: User Onboarding (Foundation)

### **Database Resources**
```sql
-- Module: 000_base_core.sql

Tables:
- users (profile, onboarding status)
- user_role (admin, user, moderator)
- user_setting (preferences, auto-sync settings)
- subscription (tier, usage, billing)
- subscription_tier (free, basic, premium)
- subscription_status (active, trialing, canceled)
- notification (alerts, messages)
- audit_log (security tracking)
- quota_usage_history (analytics)
- cache_store (external API caching)

Functions:
- check_quota(user_id, quota_type) → boolean
- increment_quota(user_id, quota_type, amount)
- decrement_quota(user_id, quota_type, amount)
- has_role(user_id, role) → boolean

Triggers:
- update_updated_at (auto-timestamp)

RLS Policies: 12 policies
```

### **Edge Functions**
```
✅ auth-profile-setup
   - Input: { display_name, bio, category, avatar_url }
   - Output: { profile_slug, is_public }
   - Security: Requires auth
   - Quota: N/A
```

### **Supabase Resources**
```toml
# config.toml additions
[auth]
enabled = true
email_enabled = true
email_confirm = true
password_min_length = 8

[auth.email]
template = "auth/confirm-signup.html"
```

### **API Keys Required**
- None (uses Supabase Auth)

### **Realtime Subscriptions**
```typescript
// Subscribe to user notifications
supabase
  .channel('user-notifications')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'notification',
    filter: `user_id=eq.${userId}`
  }, (payload) => {
    showNotification(payload.new);
  })
  .subscribe();
```

### **Cron Jobs**
```sql
-- Reset monthly quotas (1st of month)
SELECT cron.schedule('reset-quotas', '0 0 1 * *', $$
  UPDATE subscription SET syncs_used = 0, ai_analyses_used = 0, seo_submissions_used = 0
  WHERE cycle_end_date < NOW();
$$);
```

### **Postman Tests**
```
Phase_1_User_Onboarding.postman_collection.json
├── 1.1 Sign Up (Email/Password)
├── 1.2 Confirm Email
├── 1.3 Sign In
├── 1.4 Setup Profile (POST /auth-profile-setup)
├── 1.5 Get Profile (GET /rest/users?id=eq.{user_id})
├── 1.6 Update Profile (PATCH /rest/users?id=eq.{user_id})
├── 1.7 Get Subscription Info
└── 1.8 Check Quotas

Expected Results:
✅ User created in auth.users
✅ User row auto-created in public.users
✅ Free tier subscription assigned
✅ Profile slug generated (unique)
✅ Quotas: 10 syncs, 25 AI analyses, 0 SEO submissions
```

### **CI/CD Pipeline**
```yaml
# .github/workflows/test-phase-1.yml
name: Test Phase 1 - User Onboarding

on:
  pull_request:
    paths:
      - 'database/schema/000_base_core.sql'
      - 'supabase/functions/auth-profile-setup/**'

jobs:
  test-phase-1:
    runs-on: ubuntu-latest
    steps:
      - name: Apply Module 000
        run: psql $DATABASE_URL -f database/schema/000_base_core.sql
      
      - name: Deploy auth-profile-setup
        run: supabase functions deploy auth-profile-setup
      
      - name: Run Phase 1 Tests
        run: newman run postman/Phase_1_User_Onboarding.postman_collection.json
```

---

## 🔗 Phase 2: Platform OAuth (Connection)

### **Database Resources**
```sql
-- Module: 001_platform_connections.sql
-- Depends on: 000_base_core.sql

Tables:
- platform (YouTube, Instagram, TikTok, Facebook, Twitter)
- account_status (active, inactive, suspended, disconnected)
- platform_connection (OAuth credentials - Vault references!)
- social_account (user's channels/profiles)

Functions:
- None (OAuth handled in Edge Functions)

Triggers:
- update_updated_at

RLS Policies: 2 policies
```

### **Edge Functions**
```
✅ oauth-youtube-init
   - Output: { authorization_url }
   - Security: Requires auth
   - Quota: N/A

✅ oauth-youtube-callback
   - Input: { code, state }
   - Output: { social_account_id }
   - Security: Requires auth
   - Quota: Checks max_social_accounts

✅ oauth-instagram-init, oauth-instagram-callback
✅ oauth-tiktok-init, oauth-tiktok-callback
```

### **Supabase Resources**
```sql
-- Vault secrets (stored securely, NOT in database!)
INSERT INTO vault.secrets (secret, name) VALUES
  ('ya29.a0Ae...', 'user_123_youtube_token'),
  ('IGQVJ...', 'user_123_instagram_token'),
  ('act.123...', 'user_123_tiktok_token');
```

### **API Keys Required**
```bash
# YouTube Data API
YOUTUBE_CLIENT_ID=123456789.apps.googleusercontent.com
YOUTUBE_CLIENT_SECRET=GOCSPX-...
YOUTUBE_API_KEY=AIzaSy...

# Instagram Graph API
INSTAGRAM_CLIENT_ID=123456789
INSTAGRAM_CLIENT_SECRET=abc123...

# TikTok API
TIKTOK_CLIENT_ID=aw123...
TIKTOK_CLIENT_SECRET=abc123...
```

### **Realtime Subscriptions**
```typescript
// Subscribe to social account connection status
supabase
  .channel('social-accounts')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'social_account',
    filter: `user_id=eq.${userId}`
  }, (payload) => {
    updateAccountList(payload.new);
  })
  .subscribe();
```

### **Cron Jobs**
```sql
-- Refresh expiring OAuth tokens (every 6 hours)
SELECT cron.schedule('refresh-tokens', '0 */6 * * *', $$
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/refresh-oauth-tokens',
    headers := '{"Authorization": "Bearer SERVICE_ROLE"}'::jsonb
  )
  WHERE EXISTS (
    SELECT 1 FROM platform_connection
    WHERE token_expires_at < NOW() + INTERVAL '24 hours'
  );
$$);
```

### **Postman Tests**
```
Phase_2_Platform_OAuth.postman_collection.json
├── 2.1 Get YouTube OAuth URL (POST /oauth-youtube-init)
├── 2.2 Simulate YouTube Callback (POST /oauth-youtube-callback)
├── 2.3 Verify Connection Created
├── 2.4 Verify Token in Vault (admin check)
├── 2.5 Verify Social Account Created
├── 2.6 Test Max Accounts Quota (try to add 2nd account on free tier)
├── 2.7 List User's Social Accounts
└── 2.8 Disconnect Account (soft delete)

Expected Results:
✅ OAuth URL generated with correct scopes
✅ Tokens stored in Vault (NOT in database)
✅ platform_connection created with vault_secret_name
✅ social_account created with channel details
✅ Quota enforced (1 account for free tier)
✅ RLS prevents viewing other users' accounts
```

---

## 📥 Phase 3: Content Sync (Data Ingestion)

### **Database Resources**
```sql
-- Module: 002_content_management.sql
-- Depends on: 000, 001

Tables:
- content_type (long_video, short_video, image, carousel, story, reel, post)
- content_item (synced content with full-text search)
- content_revision (edit history tracking)

Functions:
- prevent_account_deletion_with_content() (trigger function)

Triggers:
- update_updated_at
- prevent_account_deletion_with_content

RLS Policies: 3 policies

Indexes:
- Full-text search (GIN index on tsvector)
- Array search (GIN on tags[], hashtags[])
- Time-based queries (published_at DESC)
```

### **Edge Functions**
```
✅ sync-youtube
   - Input: { social_account_id, max_results: 50 }
   - Output: { synced_count, new_items, updated_items }
   - Security: Requires auth
   - Quota: Increments syncs_used

✅ sync-instagram
✅ sync-tiktok
```

### **Supabase Resources**
```sql
-- Enable full-text search extension
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- For fuzzy matching

-- Optimize search performance
CREATE INDEX idx_content_search_trgm ON content_item USING gin(title gin_trgm_ops);
```

### **API Keys Required**
- YouTube Data API Key (same as Phase 2)
- Instagram Graph API (same as Phase 2)
- TikTok API (same as Phase 2)

### **Realtime Subscriptions**
```typescript
// Subscribe to new content synced
supabase
  .channel('content-updates')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'content_item',
    filter: `social_account_id=eq.${socialAccountId}`
  }, (payload) => {
    addContentToUI(payload.new);
  })
  .subscribe();
```

### **Cron Jobs**
```sql
-- Auto-sync enabled accounts (every 4 hours)
SELECT cron.schedule('auto-sync', '0 */4 * * *', $$
  SELECT net.http_post(
    url := format('https://your-project.supabase.co/functions/v1/sync-%s', platform),
    headers := '{"Authorization": "Bearer SERVICE_ROLE"}'::jsonb,
    body := jsonb_build_object('social_account_id', id)
  )
  FROM social_account sa
  JOIN platform p ON sa.platform_id = p.id
  WHERE sa.sync_mode = 'auto'
    AND sa.next_sync_at < NOW()
    AND sa.deleted_at IS NULL;
$$);
```

### **Postman Tests**
```
Phase_3_Content_Sync.postman_collection.json
├── 3.1 Sync YouTube Videos (POST /sync-youtube)
├── 3.2 Verify Content Created
├── 3.3 Test Deduplication (sync same video again)
├── 3.4 Search Content (Full-text)
├── 3.5 Filter by Tags
├── 3.6 Test Soft Delete
├── 3.7 Test Quota Enforcement (exceed 10 syncs on free tier)
└── 3.8 Test RLS (try to access other user's content)

Expected Results:
✅ Content synced from platform API
✅ Duplicate content not re-created (UNIQUE constraint)
✅ Full-text search returns relevant results
✅ Tags and hashtags indexed for fast filtering
✅ Soft delete works (deleted_at IS NULL filter)
✅ Quota enforced after 10 syncs
✅ RLS prevents unauthorized access
```

---

## 🤖 Phase 4: AI Enhancement (Intelligence)

### **Database Resources**
```sql
-- Module: 003_ai_integration.sql
-- Depends on: 000, 002

Tables:
- ai_provider (OpenAI, Anthropic, Google AI, Local)
- ai_model (GPT-4o, Claude 3.5, Gemini 1.5 Pro, etc.)
- user_ai_setting (user preferences)
- ai_suggestion (generated tags, titles, descriptions)
- ai_suggestion_application (track applied suggestions)
- ai_usage (token usage, cost tracking)
- trending_keyword (cached trending topics)

Functions:
- None (AI logic in Edge Functions)

Triggers:
- update_updated_at

RLS Policies: 4 policies

Indexes:
- GIN index on trending_keywords[]
- Time-based for billing (billing_cycle_start, billing_cycle_end)
```

### **Edge Functions**
```
✅ ai-generate-tags
   - Input: { content_item_id, provider?: 'openai' }
   - Output: { suggested_titles[], suggested_tags[], trending_score }
   - Security: Requires auth
   - Quota: Increments ai_analyses_used
   - Cost: Tracks tokens and calculates cost
```

### **Supabase Resources**
```sql
-- Vault secrets for AI API keys
INSERT INTO vault.secrets (secret, name) VALUES
  ('sk-proj-...', 'OPENAI_API_KEY'),
  ('sk-ant-...', 'ANTHROPIC_API_KEY'),
  ('AIza...', 'GOOGLE_AI_API_KEY');
```

### **API Keys Required**
```bash
# AI Providers
OPENAI_API_KEY=sk-proj-...
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_AI_API_KEY=AIza...

# Optional: Local model endpoint
LOCAL_AI_ENDPOINT=http://localhost:11434
```

### **Realtime Subscriptions**
```typescript
// Subscribe to AI suggestion completions
supabase
  .channel('ai-suggestions')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'ai_suggestion',
    filter: `content_item_id=eq.${contentId}`
  }, (payload) => {
    displayAISuggestions(payload.new);
  })
  .subscribe();
```

### **Cron Jobs**
```sql
-- Update trending keywords cache (every 6 hours)
SELECT cron.schedule('update-trending-keywords', '0 */6 * * *', $$
  -- Fetch from Google Trends API, Twitter Trends, etc.
  -- Store in trending_keyword table with TTL
$$);
```

### **Postman Tests**
```
Phase_4_AI_Enhancement.postman_collection.json
├── 4.1 Generate AI Tags (POST /ai-generate-tags)
├── 4.2 Verify AI Suggestion Created
├── 4.3 Check Token Usage Tracked
├── 4.4 Check Cost Calculated
├── 4.5 Apply AI Suggestion
├── 4.6 Test Quota Enforcement (exceed 25 analyses on free tier)
├── 4.7 Test Multiple Providers (OpenAI vs Anthropic)
└── 4.8 Verify Trending Keywords Cached

Expected Results:
✅ AI generates relevant tags for content
✅ Token usage tracked (prompt + completion tokens)
✅ Cost calculated based on model pricing
✅ Quota incremented (ai_analyses_used++)
✅ Quota enforced after 25 analyses
✅ Multiple AI providers supported
✅ Trending keywords cached for reuse
```

---

## 🔍 Phase 5: SEO Integration (Discoverability)

### **Database Resources**
```sql
-- Module: 004_seo_integration.sql
-- Depends on: 000, 002

Tables:
- search_engine (Google, Bing, Yandex, IndexNow)
- seo_connection (user's search console connections)
- seo_submission (URL submissions to search engines)
- seo_usage (quota tracking)

Functions:
- None (SEO logic in Edge Functions)

Triggers:
- update_updated_at

RLS Policies: 3 policies
```

### **Edge Functions**
```
✅ get-seo-metadata
   - Input: { content_item_id }
   - Output: { title, description, canonical_url, og_tags }
   - Security: Public (for SEO crawlers)

✅ robots
   - Output: robots.txt content
   - Security: Public

✅ sitemap
   - Output: XML sitemap
   - Security: Public
```

### **Supabase Resources**
```sql
-- Vault secrets for search console API keys
INSERT INTO vault.secrets (secret, name) VALUES
  ('ya29.a0...', 'user_123_google_search_console'),
  ('ABC123...', 'user_123_bing_webmaster');
```

### **API Keys Required**
```bash
# Search Engine APIs
GOOGLE_SEARCH_CONSOLE_API_KEY=ya29.a0...
BING_WEBMASTER_API_KEY=ABC123...
INDEXNOW_API_KEY=xyz789...
```

### **Realtime Subscriptions**
```typescript
// Subscribe to SEO submission status updates
supabase
  .channel('seo-submissions')
  .on('postgres_changes', {
    event: 'UPDATE',
    schema: 'public',
    table: 'seo_submission',
    filter: `connection_id=eq.${connectionId}`
  }, (payload) => {
    updateSubmissionStatus(payload.new);
  })
  .subscribe();
```

### **Cron Jobs**
```sql
-- Check SEO indexing status (daily at 6 AM)
SELECT cron.schedule('check-seo-status', '0 6 * * *', $$
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/check-seo-status',
    headers := '{"Authorization": "Bearer SERVICE_ROLE"}'::jsonb
  );
$$);
```

### **Postman Tests**
```
Phase_5_SEO_Integration.postman_collection.json
├── 5.1 Get SEO Metadata (GET /get-seo-metadata?content_id=...)
├── 5.2 Get Robots.txt (GET /robots)
├── 5.3 Get Sitemap (GET /sitemap)
├── 5.4 Submit URL to Google (requires auth)
├── 5.5 Check Submission Status
├── 5.6 Test Quota Enforcement (free tier = 0 submissions)
└── 5.7 Verify Premium Tier Can Submit

Expected Results:
✅ SEO metadata generated with Open Graph tags
✅ robots.txt allows search engine crawling
✅ Sitemap lists all public content
✅ URL submitted to Google Search Console
✅ Submission status tracked (pending → indexed)
✅ Free tier quota enforcement (0 submissions)
✅ Premium tier can submit (200 submissions/month)
```

---

## 🌐 Phase 6: Discovery Platform (Public Features)

### **Database Resources**
```sql
-- Module: 005_discovery_platform.sql
-- Depends on: 000, 002

Tables:
- content_category (15 categories: music, gaming, education, etc.)
- content_tag (AI-generated + platform tags)
- content_click (click tracking analytics)
- content_media (multi-media support for carousels)
- trending_content (algorithm-based trending)
- featured_creator (manually curated)

Functions:
- generate_profile_slug(display_name, user_id) → text
- update_total_followers(user_id)
- increment_content_clicks(content_id)
- calculate_trend_score(clicks, views, created_at) → decimal

Triggers:
- None (functions called explicitly)

RLS Policies: 7 policies
```

### **Edge Functions**
```
✅ browse-content
   - Input: { category?, limit: 50, offset: 0 }
   - Output: { content_items[], total_count }
   - Security: Public

✅ browse-creators
   - Input: { category?, limit: 50 }
   - Output: { creators[], total_count }
   - Security: Public

✅ browse-categories
   - Output: { categories[] }
   - Security: Public

✅ search-content
   - Input: { q, category?, limit: 50 }
   - Output: { results[], total_count }
   - Security: Public

✅ search-creators
   - Input: { q, category?, limit: 50 }
   - Output: { results[], total_count }
   - Security: Public

✅ get-trending
   - Input: { period: 'today' | 'week' | 'month', limit: 100 }
   - Output: { trending_items[], trend_scores }
   - Security: Public

✅ track-click
   - Input: { content_id, referrer?, user_agent? }
   - Output: { success: true }
   - Security: Public (anonymous allowed)

✅ get-content-detail
   - Input: { content_id }
   - Output: { content_item, related_content[] }
   - Security: Public

✅ get-creator-by-slug
   - Input: { slug }
   - Output: { user, social_accounts[], recent_content[] }
   - Security: Public
```

### **Supabase Resources**
```sql
-- Enable realtime for trending content
ALTER PUBLICATION supabase_realtime ADD TABLE trending_content;
```

### **API Keys Required**
- None (public discovery features)

### **Realtime Subscriptions**
```typescript
// Subscribe to trending content updates
supabase
  .channel('trending-updates')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'trending_content'
  }, (payload) => {
    updateTrendingList(payload.new);
  })
  .subscribe();
```

### **Cron Jobs**
```sql
-- Update trending content (every hour)
SELECT cron.schedule('update-trending', '0 * * * *', $$
  DELETE FROM trending_content WHERE last_updated_at < NOW() - INTERVAL '7 days';
  
  INSERT INTO trending_content (content_id, trend_score, trend_category, rank_position)
  SELECT 
    id,
    calculate_trend_score(total_clicks, views_count, published_at),
    'today',
    ROW_NUMBER() OVER (ORDER BY calculate_trend_score(total_clicks, views_count, published_at) DESC)
  FROM content_item
  WHERE published_at > NOW() - INTERVAL '1 day'
    AND deleted_at IS NULL
  ORDER BY trend_score DESC
  LIMIT 100
  ON CONFLICT (content_id, trend_category) DO UPDATE
  SET trend_score = EXCLUDED.trend_score,
      rank_position = EXCLUDED.rank_position,
      last_updated_at = NOW();
$$);
```

### **Postman Tests**
```
Phase_6_Discovery_Platform.postman_collection.json
├── 6.1 Browse All Categories (GET /browse-categories)
├── 6.2 Browse Gaming Content (GET /browse-content?category=gaming)
├── 6.3 Search Content (GET /search-content?q=minecraft)
├── 6.4 Search Creators (GET /search-creators?q=tech)
├── 6.5 Get Trending Today (GET /get-trending?period=today)
├── 6.6 Track Click (POST /track-click)
├── 6.7 Get Content Detail (GET /get-content-detail?id=...)
├── 6.8 Get Creator Profile (GET /get-creator-by-slug?slug=tech-gaming-channel)
└── 6.9 Verify Click Counter Incremented

Expected Results:
✅ All 15 categories listed
✅ Content filtered by category
✅ Full-text search returns relevant results
✅ Creator search finds matching profiles
✅ Trending algorithm surfaces popular content
✅ Click tracked (anonymous allowed)
✅ Content detail includes related items
✅ Creator profile shows all content
✅ Click counters updated in real-time
```

---

## ⚙️ Phase 7: Async Infrastructure (Background Processing)

### **Database Resources**
```sql
-- Module: 006_async_infrastructure.sql
-- Depends on: 000

Tables:
- job_type (platform_sync, ai_analysis, seo_submission, quota_reset, token_refresh)
- job_queue (20+ indexes for performance!)
- job_log (detailed execution logs)
- stripe_webhook_events (idempotency protection)

Functions:
- create_job(user_id, job_type, params) → uuid
- update_job_progress(job_id, percent, message)
- start_job(job_id, worker_id) → boolean
- complete_job(job_id, result) → boolean
- fail_job(job_id, error_message) → boolean
- cancel_job(job_id, user_id) → boolean
- add_job_log(job_id, level, message)
- get_user_jobs(user_id, status?, job_type?) → table
- get_job_logs(job_id, user_id) → table
- find_or_create_job(user_id, job_type, params) → table (deduplication!)
- get_cached_job_result(user_id, job_type, params) → table (caching!)
- get_job_queue_stats(user_id?) → table
- retry_failed_jobs() → table
- cleanup_old_jobs() → bigint
- expire_stale_jobs() → table
- detect_stuck_jobs() → table
- log_stripe_webhook_event(event_id, type, data) → uuid
- mark_webhook_processed(event_id, error?)
- retry_failed_webhooks(max_retries) → table
- cleanup_old_webhook_events(days_old) → int
- cache_stripe_data(key, data, ttl)
- get_cached_stripe_data(key) → jsonb
- invalidate_stripe_cache(pattern)
- invalidate_stripe_cache_from_webhook(event_type, object_id)

Triggers:
- job_status_change_notify (pg_notify for real-time updates)
- update_updated_at

RLS Policies: 7 policies

Indexes:
- 11 on job_queue (composite, partial, GIN for JSONB)
- 4 on job_log (time-based, error filtering, full-text, JSONB)
- 5 on stripe_webhook_events (idempotency, type, processed)
```

### **Edge Functions**
```
🆕 job-processor (new - needs to be created)
   - Picks up pending jobs from queue
   - Executes job based on type
   - Updates progress in real-time
   - Handles errors with auto-retry

🆕 stripe-webhook (new - needs to be created)
   - Receives Stripe webhook events
   - Validates webhook signature
   - Logs to stripe_webhook_events (idempotency)
   - Updates subscriptions based on event type
   - Invalidates Stripe cache

🆕 job-status (new - needs to be created)
   - Input: { job_id }
   - Output: { status, progress_percent, progress_message, result }
   - Security: Requires auth (user's own jobs only)
```

### **Supabase Resources**
```sql
-- Enable realtime for job queue
ALTER PUBLICATION supabase_realtime ADD TABLE job_queue;

-- Enable realtime for job logs
ALTER PUBLICATION supabase_realtime ADD TABLE job_log;

-- Enable pg_notify for job status changes (already in schema)
```

### **API Keys Required**
```bash
# Stripe
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
```

### **Realtime Subscriptions**
```typescript
// Subscribe to job status changes (via pg_notify)
supabase
  .channel('job-updates')
  .on('postgres_changes', {
    event: 'UPDATE',
    schema: 'public',
    table: 'job_queue',
    filter: `user_id=eq.${userId}`
  }, (payload) => {
    updateJobStatus(payload.new);
  })
  .subscribe();

// Subscribe to job logs in real-time
supabase
  .channel('job-logs')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'job_log',
    filter: `job_id=eq.${jobId}`
  }, (payload) => {
    appendLog(payload.new);
  })
  .subscribe();
```

### **Cron Jobs**
```sql
-- Retry failed jobs (every 15 minutes)
SELECT cron.schedule('retry-jobs', '*/15 * * * *', $$
  SELECT retry_failed_jobs();
$$);

-- Cleanup old jobs (daily at 3 AM)
SELECT cron.schedule('cleanup-jobs', '0 3 * * *', $$
  SELECT cleanup_old_jobs();
$$);

-- Detect stuck jobs (every 5 minutes)
SELECT cron.schedule('detect-stuck', '*/5 * * * *', $$
  SELECT detect_stuck_jobs();
$$);

-- Expire stale jobs (every 10 minutes)
SELECT cron.schedule('expire-stale', '*/10 * * * *', $$
  SELECT expire_stale_jobs();
$$);

-- Cleanup old webhooks (weekly on Sunday at 4 AM)
SELECT cron.schedule('cleanup-webhooks', '0 4 * * 0', $$
  SELECT cleanup_old_webhook_events(90);
$$);
```

### **Postman Tests**
```
Phase_7_Async_Infrastructure.postman_collection.json
├── 7.1 Create Sync Job (use create_job function)
├── 7.2 Get Job Status (GET /job-status?job_id=...)
├── 7.3 Monitor Job Progress (realtime subscription test)
├── 7.4 Test Job Deduplication (create same job twice)
├── 7.5 Test Result Caching (get cached result)
├── 7.6 Test Rate Limiting (create 11 jobs → should fail)
├── 7.7 Cancel Job
├── 7.8 Simulate Stripe Webhook (POST /stripe-webhook)
├── 7.9 Verify Webhook Idempotency (send same event twice)
└── 7.10 Verify Stripe Cache Invalidation

Expected Results:
✅ Job created and queued
✅ Job status updates in real-time
✅ Progress messages visible
✅ Deduplication prevents duplicate jobs (5-min window)
✅ Result cached for 1 hour
✅ Rate limiting enforced (10 concurrent jobs/user)
✅ Job cancelled successfully
✅ Stripe webhook received and processed
✅ Duplicate webhook events ignored (idempotency)
✅ Stripe cache invalidated after webhook
```

---

## 🔐 Security Checklist (All Phases)

### **Authentication & Authorization**
- [ ] All Edge Functions validate JWT tokens
- [ ] RLS policies enforce user ownership
- [ ] Admin endpoints require `has_role('admin')`
- [ ] Service role endpoints validate worker_id

### **Rate Limiting**
- [ ] 100 requests/hour per user (authenticated)
- [ ] 20 requests/hour per IP (anonymous)
- [ ] 10 concurrent jobs per user
- [ ] Quota enforcement on all paid features

### **Input Validation**
- [ ] All Edge Functions use Zod schemas
- [ ] SQL injection prevented (parameterized queries)
- [ ] XSS prevention (sanitize user input)
- [ ] File upload size limits enforced

### **Secrets Management**
- [ ] All API keys in Supabase Vault (NOT in database)
- [ ] Secrets rotated every 90 days
- [ ] Environment variables for service keys
- [ ] OAuth tokens encrypted at rest

### **Monitoring**
- [ ] Sentry integration for error tracking
- [ ] Health check endpoint (`/health`)
- [ ] Logging standard (JSON format)
- [ ] Query performance monitoring

---

## 📊 Success Metrics

### **Phase 1: User Onboarding**
- ✅ User signup → profile created < 5 seconds
- ✅ Email confirmation rate > 80%
- ✅ Profile completion rate > 70%

### **Phase 2: Platform OAuth**
- ✅ OAuth success rate > 95%
- ✅ Token refresh success rate > 99%
- ✅ Average OAuth flow time < 30 seconds

### **Phase 3: Content Sync**
- ✅ Sync success rate > 90%
- ✅ Average sync time < 60 seconds (per 50 items)
- ✅ Deduplication accuracy 100%

### **Phase 4: AI Enhancement**
- ✅ AI generation success rate > 95%
- ✅ Average generation time < 10 seconds
- ✅ Cost per analysis < $0.05

### **Phase 5: SEO Integration**
- ✅ Indexing submission success rate > 90%
- ✅ Average time to indexed < 24 hours
- ✅ Sitemap update latency < 5 minutes

### **Phase 6: Discovery Platform**
- ✅ Search response time < 500ms (p95)
- ✅ Trending algorithm accuracy > 80%
- ✅ Click tracking accuracy 100%

### **Phase 7: Async Infrastructure**
- ✅ Job completion rate > 95%
- ✅ Average job latency < 5 minutes
- ✅ Webhook processing success rate > 99%

---

## 🚀 Ready to Implement?

Next steps:
1. **Create missing cron jobs** → `database/cron-jobs.sql`
2. **Setup realtime channels** → `database/realtime-channels.sql`
3. **Create 7 phase-specific Postman collections**
4. **Add rate limiting to all Edge Functions**
5. **Deploy and test phase-by-phase**

Which phase should we start implementing first?
