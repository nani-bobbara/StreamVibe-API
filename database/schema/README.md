# 📦 StreamVibe Modular Schema Architecture

> **Philosophy**: Test each feature end-to-end before building the next. Catch design issues early, iterate fast.

## 🎯 Why Modular Schema?

During **active development**, modular schemas provide:

- ✅ **Feature isolation** - Test each module independently
- ✅ **Early bug detection** - Catch issues in authentication before building AI features
- ✅ **Faster iteration** - Deploy only what changed
- ✅ **Team collaboration** - Different developers can work on different modules
- ✅ **Clear dependencies** - See what depends on what

---

## 📚 Module Overview

| Module | Lines | Tables | Functions | Dependencies | Purpose |
|--------|-------|--------|-----------|--------------|---------|
| **000_base_core.sql** | ~800 | 10 | 4 | None | Users, auth, subscriptions, quotas |
| **001_platform_connections.sql** | ~400 | 4 | 0 | 000 | OAuth, platform accounts |
| **002_content_management.sql** | ~400 | 3 | 1 | 000, 001 | Content sync, search, revisions |
| **003_ai_integration.sql** | ~500 | 7 | 0 | 000, 002 | AI providers, tagging, cost tracking |
| **004_seo_integration.sql** | ~300 | 4 | 0 | 000, 002 | Search engine indexing |
| **005_discovery_platform.sql** | ~500 | 6 | 4 | 000, 002 | Public browsing, trending, creators |
| **006_async_infrastructure.sql** | ~1,500 | 4 | 24 | 000 | Job queue, webhooks, caching |

**Total**: ~3,900 lines, 38 tables, 33 functions

---

## 🔄 Deployment Order & Testing

### **Step 1: Apply Module 000 (Base Core)** ⏱️ 30 seconds

```bash
psql $DATABASE_URL < database/schema/000_base_core.sql
```

**✅ Verification Checklist:**
- [ ] Tables created: 10 (users, subscription, subscription_tier, etc.)
- [ ] Enums: 4 (visibility_enum, app_role_enum, notification_type_enum, action_mode_enum)
- [ ] Functions: 4 (check_quota, increment_quota, decrement_quota, has_role)
- [ ] Subscription tiers: 3 (free, basic, premium)

**🧪 Testing:**
```sql
-- 1. Create test user via Supabase Auth (use dashboard or CLI)
-- 2. Verify user row auto-created
SELECT * FROM users WHERE email = 'test@example.com';

-- 3. Assign free tier subscription
INSERT INTO subscription (user_id, tier_id, status_id, cycle_start_date, cycle_end_date)
SELECT 
    (SELECT id FROM users WHERE email = 'test@example.com'),
    (SELECT id FROM subscription_tier WHERE slug = 'free'),
    (SELECT id FROM subscription_status WHERE slug = 'active'),
    NOW(),
    NOW() + INTERVAL '1 month';

-- 4. Test quota functions
SELECT check_quota(
    (SELECT id FROM users WHERE email = 'test@example.com'),
    'sync'
); -- Should return true (not at limit)

-- 5. Test role assignment
INSERT INTO user_role (user_id, role)
VALUES ((SELECT id FROM users WHERE email = 'test@example.com'), 'user');

SELECT has_role(
    (SELECT id FROM users WHERE email = 'test@example.com'),
    'user'
); -- Should return true
```

**🐛 Common Issues:**
- `auth.users` doesn't exist → Enable Supabase Auth first
- Subscription insert fails → Check tier_id and status_id are valid UUIDs

---

### **Step 2: Apply Module 001 (Platform Connections)** ⏱️ 15 seconds

```bash
psql $DATABASE_URL < database/schema/001_platform_connections.sql
```

**✅ Verification:**
- [ ] Tables created: 4 (platform, account_status, platform_connection, social_account)
- [ ] Platforms: 5 (YouTube, Instagram, TikTok, Facebook, Twitter)
- [ ] Account statuses: 4 (active, inactive, suspended, disconnected)

**🧪 Testing:**
```sql
-- 1. Check platforms loaded
SELECT * FROM platform ORDER BY sort_order;

-- 2. Deploy oauth-youtube-init Edge Function first
-- Then test OAuth flow: GET /functions/v1/oauth-youtube-init

-- 3. After OAuth callback, verify connection created
SELECT * FROM platform_connection WHERE user_id = (SELECT id FROM users WHERE email = 'test@example.com');

-- 4. Verify credentials are in Vault (NOT in database!)
-- Check vault_secret_name is populated (e.g., 'user_123_youtube_token')

-- 5. Check social account auto-created
SELECT * FROM social_account WHERE user_id = (SELECT id FROM users WHERE email = 'test@example.com');
```

**🐛 Common Issues:**
- OAuth fails → Check YOUTUBE_CLIENT_ID and YOUTUBE_CLIENT_SECRET in Supabase secrets
- Vault secret not found → Ensure Edge Function is storing credentials correctly
- social_account not created → Check OAuth callback completed successfully

---

### **Step 3: Apply Module 002 (Content Management)** ⏱️ 20 seconds

```bash
psql $DATABASE_URL < database/schema/002_content_management.sql
```

**✅ Verification:**
- [ ] Tables created: 3 (content_type, content_item, content_revision)
- [ ] Content types: 7 (long_video, short_video, image, carousel, story, reel, post)
- [ ] Full-text search index created on content_item

**🧪 Testing:**
```sql
-- 1. Check content types
SELECT * FROM content_type ORDER BY sort_order;

-- 2. Deploy sync-youtube Edge Function
-- Then sync content: POST /functions/v1/sync-youtube {"social_account_id": "..."}

-- 3. Verify content items created
SELECT * FROM content_item 
WHERE social_account_id = (
    SELECT id FROM social_account 
    WHERE user_id = (SELECT id FROM users WHERE email = 'test@example.com')
)
ORDER BY published_at DESC
LIMIT 5;

-- 4. Test full-text search
SELECT title, description 
FROM content_item 
WHERE search_vector @@ plainto_tsquery('gaming OR tutorial')
LIMIT 10;

-- 5. Test soft delete protection
-- Try to delete social_account with content → should fail
DELETE FROM social_account 
WHERE user_id = (SELECT id FROM users WHERE email = 'test@example.com');
-- ERROR: Cannot delete social account with existing content
```

**🐛 Common Issues:**
- Sync fails → Check platform_connection is active and token not expired
- Search returns nothing → Content needs title/description populated
- Can't delete account → Working as designed! Archive content first

---

### **Step 4: Apply Module 003 (AI Integration)** ⏱️ 25 seconds

```bash
psql $DATABASE_URL < database/schema/003_ai_integration.sql
```

**✅ Verification:**
- [ ] Tables created: 7 (ai_provider, ai_model, user_ai_setting, ai_suggestion, ai_suggestion_application, ai_usage, trending_keyword)
- [ ] AI providers: 4 (OpenAI, Anthropic, Google AI, Local)
- [ ] AI models: 5 (GPT-4o, GPT-4o Mini, Claude 3.5 Sonnet, Gemini 1.5 Pro, Llama 3.2)

**🧪 Testing:**
```sql
-- 1. Check AI providers and models
SELECT p.display_name, m.display_name, m.input_cost_per_1k_tokens
FROM ai_model m
JOIN ai_provider p ON m.provider_id = p.id
ORDER BY m.input_cost_per_1k_tokens;

-- 2. Set OpenAI API key in Supabase secrets
-- Dashboard → Settings → Vault → Add secret: OPENAI_API_KEY

-- 3. Deploy ai-generate-tags Edge Function
-- Then generate tags: POST /functions/v1/ai-generate-tags {"content_item_id": "..."}

-- 4. Verify AI suggestion created
SELECT 
    suggested_titles,
    suggested_tags,
    trending_keywords,
    trending_score,
    seo_score,
    total_cost_cents
FROM ai_suggestion
WHERE content_item_id = (SELECT id FROM content_item ORDER BY created_at DESC LIMIT 1);

-- 5. Check AI usage tracking
SELECT 
    operation_type,
    prompt_tokens,
    completion_tokens,
    cost_cents,
    created_at
FROM ai_usage
WHERE user_id = (SELECT id FROM users WHERE email = 'test@example.com')
ORDER BY created_at DESC
LIMIT 5;

-- 6. Verify quota incremented
SELECT ai_analyses_used, max_ai_analyses_per_month
FROM subscription s
JOIN subscription_tier t ON s.tier_id = t.id
WHERE s.user_id = (SELECT id FROM users WHERE email = 'test@example.com');
```

**🐛 Common Issues:**
- AI call fails → Check OPENAI_API_KEY is set correctly
- Cost not tracked → Ensure ai_usage row inserted after API call
- Quota not incremented → Call increment_quota() in Edge Function

---

### **Step 5: Apply Module 004 (SEO Integration)** ⏱️ 15 seconds

```bash
psql $DATABASE_URL < database/schema/004_seo_integration.sql
```

**✅ Verification:**
- [ ] Tables created: 4 (search_engine, seo_connection, seo_submission, seo_usage)
- [ ] Search engines: 4 (Google, Bing, Yandex, IndexNow)

**🧪 Testing:**
```sql
-- 1. Check search engines
SELECT * FROM search_engine;

-- 2. Set up Google Search Console API credentials
-- Store in Vault: GOOGLE_SEARCH_CONSOLE_API_KEY

-- 3. Create SEO connection
INSERT INTO seo_connection (user_id, search_engine_id, vault_secret_name, site_url, is_active, is_verified)
VALUES (
    (SELECT id FROM users WHERE email = 'test@example.com'),
    (SELECT id FROM search_engine WHERE slug = 'google'),
    'user_123_google_search_console',
    'https://streamvibe.com',
    true,
    false
);

-- 4. Submit URL to Google (via Edge Function or manual)
-- POST /functions/v1/submit-to-seo {"content_item_id": "...", "search_engine": "google"}

-- 5. Check submission status
SELECT 
    submitted_url,
    submission_type,
    status,
    response_status,
    error_message
FROM seo_submission
WHERE connection_id IN (
    SELECT id FROM seo_connection 
    WHERE user_id = (SELECT id FROM users WHERE email = 'test@example.com')
)
ORDER BY created_at DESC
LIMIT 10;

-- 6. Verify SEO quota incremented
SELECT seo_submissions_used, max_seo_submissions_per_month
FROM subscription s
JOIN subscription_tier t ON s.tier_id = t.id
WHERE s.user_id = (SELECT id FROM users WHERE email = 'test@example.com');
```

**🐛 Common Issues:**
- Google API fails → Check credentials and site ownership verification
- Status stuck at 'pending' → Indexing takes time (hours/days)
- Quota exceeded → Free tier has 0 SEO submissions

---

### **Step 6: Apply Module 005 (Discovery Platform)** ⏱️ 20 seconds

```bash
psql $DATABASE_URL < database/schema/005_discovery_platform.sql
```

**✅ Verification:**
- [ ] Tables created: 6 (content_category, content_tag, content_click, content_media, trending_content, featured_creator)
- [ ] Categories: 15 (music, gaming, education, etc.)
- [ ] Functions: 4 (generate_profile_slug, update_total_followers, increment_content_clicks, calculate_trend_score)

**🧪 Testing:**
```sql
-- 1. Check categories
SELECT * FROM content_category ORDER BY sort_order;

-- 2. Deploy browse-content Edge Function
-- Then browse: GET /functions/v1/browse-content?category=gaming

-- 3. Assign category to content
UPDATE content_item
SET category_code = 'gaming'
WHERE id = (SELECT id FROM content_item ORDER BY created_at DESC LIMIT 1);

-- 4. Add AI-generated tags
INSERT INTO content_tag (content_id, tag, source, confidence_score, tag_type)
VALUES (
    (SELECT id FROM content_item ORDER BY created_at DESC LIMIT 1),
    'minecraft',
    'ai_generated',
    0.95,
    'keyword'
);

-- 5. Track click (simulated)
INSERT INTO content_click (content_id, user_id, referrer, user_agent)
VALUES (
    (SELECT id FROM content_item ORDER BY created_at DESC LIMIT 1),
    (SELECT id FROM users WHERE email = 'test@example.com'),
    'https://google.com',
    'Mozilla/5.0 ...'
);

-- 6. Update click counters
SELECT increment_content_clicks(
    (SELECT id FROM content_item ORDER BY created_at DESC LIMIT 1)
);

-- 7. Check trending score
SELECT 
    title,
    total_clicks,
    views_count,
    calculate_trend_score(total_clicks, views_count, published_at) as trend_score
FROM content_item
ORDER BY trend_score DESC
LIMIT 10;

-- 8. Generate profile slug
SELECT generate_profile_slug('Tech Gaming Channel', 
    (SELECT id FROM users WHERE email = 'test@example.com')
); -- Returns: 'tech-gaming-channel'

-- 9. Update user profile for discovery
UPDATE users
SET 
    display_name = 'Tech Gaming Channel',
    bio = 'Gaming tutorials and reviews',
    profile_slug = generate_profile_slug('Tech Gaming Channel', id),
    primary_category = 'gaming',
    is_public = true
WHERE email = 'test@example.com';

-- 10. Test public discovery
-- GET /functions/v1/browse-creators?category=gaming
```

**🐛 Common Issues:**
- Trending score always 0 → Need views_count and clicks populated
- Slug collision → generate_profile_slug() auto-appends counter
- Creator not discoverable → Check is_public = true

---

### **Step 7: Apply Module 006 (Async Infrastructure)** ⏱️ 30 seconds

```bash
psql $DATABASE_URL < database/schema/006_async_infrastructure.sql
```

**✅ Verification:**
- [ ] Tables created: 4 (job_type, job_queue, job_log, stripe_webhook_events)
- [ ] Indexes: 20 (11 on job_queue + 4 on job_log + 5 on stripe_webhook_events)
- [ ] Functions: 24 (16 job + 4 webhook + 4 cache)
- [ ] Job types: 5 (platform_sync, ai_analysis, seo_submission, quota_reset, token_refresh)

**🧪 Testing:**
```sql
-- 1. Create a background job
SELECT create_job(
    (SELECT id FROM users WHERE email = 'test@example.com'),
    'sync_youtube',
    '{"social_account_id": "123e4567-e89b-12d3-a456-426614174000"}'::jsonb,
    5 -- priority
);

-- 2. Check job status
SELECT * FROM get_user_jobs(
    (SELECT id FROM users WHERE email = 'test@example.com'),
    NULL, -- all statuses
    NULL, -- all types
    10,   -- limit
    0     -- offset
);

-- 3. Test job deduplication
-- Call create_job again with same params → should dedupe
SELECT * FROM find_or_create_job(
    (SELECT id FROM users WHERE email = 'test@example.com'),
    'sync_youtube',
    '{"social_account_id": "123e4567-e89b-12d3-a456-426614174000"}'::jsonb
);

-- 4. Simulate job processing (as service_role)
SELECT start_job(
    (SELECT id FROM job_queue WHERE status = 'pending' LIMIT 1),
    'edge-function-xyz'
);

-- 5. Update progress
SELECT update_job_progress(
    (SELECT id FROM job_queue WHERE status = 'processing' LIMIT 1),
    50,
    'Synced 50 of 100 videos'
);

-- 6. Complete job
SELECT complete_job(
    (SELECT id FROM job_queue WHERE status = 'processing' LIMIT 1),
    '{"synced_count": 100, "new_items": 10}'::jsonb
);

-- 7. Test caching
SELECT * FROM get_cached_job_result(
    (SELECT id FROM users WHERE email = 'test@example.com'),
    'sync_youtube',
    '{"social_account_id": "123e4567-e89b-12d3-a456-426614174000"}'::jsonb,
    INTERVAL '1 hour'
); -- Should return cached result

-- 8. Simulate Stripe webhook
SELECT log_stripe_webhook_event(
    'evt_test_123',
    'customer.subscription.created',
    '{"id": "sub_123", "customer": "cus_456"}'::jsonb
);

-- 9. Check webhook logged
SELECT * FROM stripe_webhook_events ORDER BY created_at DESC LIMIT 5;

-- 10. Test Stripe caching
SELECT cache_stripe_data(
    'stripe:product:prod_test',
    '{"id": "prod_test", "name": "Premium Plan"}'::jsonb,
    3600 -- 1 hour TTL
);

SELECT get_cached_stripe_data('stripe:product:prod_test');

-- 11. Get job queue stats
SELECT * FROM get_job_queue_stats(
    (SELECT id FROM users WHERE email = 'test@example.com')
);
```

**🐛 Common Issues:**
- Rate limit exceeded → Max 10 concurrent jobs per user
- Job stuck in 'processing' → detect_stuck_jobs() will fail it after 30 min
- Webhook duplicate → Working as designed! Idempotency protection
- Cache miss → Check expires_at not in the past

---

## 🚀 Quick Deploy All Modules

```bash
#!/bin/bash
# Deploy all modules in order

DATABASE_URL="postgresql://user:pass@host:5432/streamvibe"

echo "🚀 Deploying StreamVibe Modular Schema..."

psql $DATABASE_URL -f database/schema/000_base_core.sql
echo "✅ Module 000: Base Core"

psql $DATABASE_URL -f database/schema/001_platform_connections.sql
echo "✅ Module 001: Platform Connections"

psql $DATABASE_URL -f database/schema/002_content_management.sql
echo "✅ Module 002: Content Management"

psql $DATABASE_URL -f database/schema/003_ai_integration.sql
echo "✅ Module 003: AI Integration"

psql $DATABASE_URL -f database/schema/004_seo_integration.sql
echo "✅ Module 004: SEO Integration"

psql $DATABASE_URL -f database/schema/005_discovery_platform.sql
echo "✅ Module 005: Discovery Platform"

psql $DATABASE_URL -f database/schema/006_async_infrastructure.sql
echo "✅ Module 006: Async Infrastructure"

echo "🎉 All modules deployed successfully!"
echo "📊 Run verification: SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
```

---

## 🔍 Verification Queries

After deploying all modules, run these verification queries:

```sql
-- Count tables (should be 38)
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- Count functions (should be 33+)
SELECT COUNT(*) FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND p.prokind = 'f';

-- Count indexes (should be 80+)
SELECT COUNT(*) FROM pg_indexes 
WHERE schemaname = 'public';

-- Count RLS policies (should be 35+)
SELECT COUNT(*) FROM pg_policies 
WHERE schemaname = 'public';

-- List all tables by module
SELECT 
    CASE 
        WHEN tablename IN ('users', 'user_role', 'user_setting', 'subscription', 'subscription_tier', 'subscription_status', 'notification', 'audit_log', 'quota_usage_history', 'cache_store') THEN '000_base_core'
        WHEN tablename IN ('platform', 'account_status', 'platform_connection', 'social_account') THEN '001_platform_connections'
        WHEN tablename IN ('content_type', 'content_item', 'content_revision') THEN '002_content_management'
        WHEN tablename IN ('ai_provider', 'ai_model', 'user_ai_setting', 'ai_suggestion', 'ai_suggestion_application', 'ai_usage', 'trending_keyword') THEN '003_ai_integration'
        WHEN tablename IN ('search_engine', 'seo_connection', 'seo_submission', 'seo_usage') THEN '004_seo_integration'
        WHEN tablename IN ('content_category', 'content_tag', 'content_click', 'content_media', 'trending_content', 'featured_creator') THEN '005_discovery_platform'
        WHEN tablename IN ('job_type', 'job_queue', 'job_log', 'stripe_webhook_events') THEN '006_async_infrastructure'
        ELSE 'unknown'
    END as module,
    tablename
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY module, tablename;
```

---

## 🐛 Troubleshooting

### **Issue: Module fails to apply**

```bash
# Check current schema state
psql $DATABASE_URL -c "SELECT * FROM pg_tables WHERE schemaname = 'public';"

# Check for errors in specific module
psql $DATABASE_URL -f database/schema/003_ai_integration.sql 2>&1 | grep ERROR
```

### **Issue: Dependency error (table not found)**

**Cause**: Applied modules out of order

**Solution**: Apply in correct order (000 → 001 → 002 → ...)

### **Issue: Duplicate key error**

**Cause**: Module already partially applied

**Solution**: Drop affected table and re-apply
```sql
DROP TABLE IF EXISTS ai_provider CASCADE;
```

---

## 📈 Performance Monitoring

```sql
-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Find unused indexes
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey';

-- Check table sizes
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 🎉 Success Checklist

After deploying all 7 modules, you should have:

- [ ] 38 tables created
- [ ] 33+ functions deployed
- [ ] 80+ indexes optimized
- [ ] 35+ RLS policies securing data
- [ ] 5 enums defined
- [ ] All test queries pass
- [ ] Edge Functions can interact with database
- [ ] Stripe webhooks can be received
- [ ] Job queue processing works
- [ ] Full-text search returns results

---

## 📞 Support

**Issues with specific modules?**

1. Check the **🧪 Testing** section for that module
2. Run verification queries
3. Check Edge Function logs in Supabase dashboard
4. Review RLS policies (common cause of "permission denied" errors)

**Need to rollback a module?**

```sql
-- Example: Rollback module 006 (async infrastructure)
DROP TABLE IF EXISTS stripe_webhook_events CASCADE;
DROP TABLE IF EXISTS job_log CASCADE;
DROP TABLE IF EXISTS job_queue CASCADE;
DROP TABLE IF EXISTS job_type CASCADE;
-- Drop all functions from that module...
```

---

## 🏁 Next Steps

Once all modules are deployed and tested:

1. **Build remaining Edge Functions**: job-processor, stripe-webhook, job-status
2. **Set up pg_cron**: Enable extension and create schedulers
3. **Configure Stripe webhooks**: Point to `/functions/v1/stripe-webhook`
4. **Deploy to production**: Use consolidated 000_initial_schema_20251108.sql (coming next)
5. **Monitor performance**: Check index usage, query times, cache hit rates

---

**🚀 Happy Building!**
