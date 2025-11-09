# 🗄️ StreamVibe Database - Phase-Wise Architecture

**Philosophy**: Domain-driven design with clear bounded contexts. Deploy and test incrementally, one phase at a time.

---

## 📂 Folder Structure (Clean & Simple)

```
database/
├── README.md                           # ← All documentation here
│
├── phases/                             # 🎯 Single Source of Truth
│   ├── phase_1_user_onboarding/schema.sql         # 607 lines
│   ├── phase_2_platform_oauth/schema.sql          # 208 lines
│   ├── phase_3_content_sync/schema.sql            # 264 lines
│   ├── phase_4_ai_enhancement/schema.sql          # 305 lines
│   ├── phase_5_seo_integration/schema.sql         # 209 lines
│   ├── phase_6_discovery_platform/schema.sql      # 343 lines
│   └── phase_7_async_infrastructure/schema.sql    # 763 lines
│
└── archive/                            # 📦 Old files (reference only)
    ├── 000_initial_schema_20251108.sql
    ├── old_migrations/
    ├── old_modular_schema/
    ├── old_schema/
    └── production/
```

**Total**: 2,699 lines of SQL across 7 phases | 38 tables | 33 functions | 80+ indexes

---

## 🎯 Quick Start

### Deploy Phase 1 Only (Recommended)
```bash
# Copy to Supabase migrations
cp database/phases/phase_1_user_onboarding/schema.sql \
   supabase/migrations/20251109000001_phase1_user_onboarding.sql

# Apply
supabase db push
```

### Deploy All Phases at Once
```bash
# Combine all phases
cat database/phases/phase_*/schema.sql > \
    supabase/migrations/20251109000001_full_schema.sql

# Apply
supabase db push
```

---

## 📊 Phase Overview & Dependencies

| # | Phase | Domain | Tables | Functions | Depends On | Deploy Time |
|---|-------|--------|--------|-----------|------------|-------------|
| **1** | User Onboarding | Auth, profiles, subscriptions, billing | 10 | 4 | None | 30s |
| **2** | Platform OAuth | YouTube, Instagram, TikTok OAuth | 4 | 0 | Phase 1 | 15s |
| **3** | Content Sync | Content management, search | 3 | 1 | 1, 2 | 20s |
| **4** | AI Enhancement | AI tagging, cost tracking | 7 | 0 | 1, 3 | 25s |
| **5** | SEO Integration | Search engine indexing | 4 | 0 | 1, 3 | 15s |
| **6** | Discovery Platform | Public browsing, trending | 6 | 4 | 1, 3 | 20s |
| **7** | Async Infrastructure | Job queue, webhooks, Stripe | 4 | 24 | 1 | 30s |

### Dependency Graph
```
Phase 1: User Onboarding (Foundation)
    ↓
    ├─→ Phase 2: Platform OAuth
    │       ↓
    │   Phase 3: Content Sync
    │       ↓
    │       ├─→ Phase 4: AI Enhancement
    │       ├─→ Phase 5: SEO Integration
    │       └─→ Phase 6: Discovery Platform
    │
    └─→ Phase 7: Async Infrastructure (independent)
```

---

## 📋 Phase Details & Testing

### Phase 1: User Onboarding (Foundation)
**Domain**: User authentication, profiles, subscriptions, billing infrastructure

**What's Included**:
- Tables (10): users, user_role, user_setting, subscription, subscription_tier, subscription_status, notification, audit_log, quota_usage_history, cache_store
- Functions (4): check_quota(), increment_quota(), decrement_quota(), has_role()
- Enums (4): visibility_enum, app_role_enum, notification_type_enum, action_mode_enum

**Edge Functions**: `auth-profile-setup`

**Testing**:
```sql
-- 1. Create user via Supabase Auth
-- 2. Verify user row auto-created
SELECT id, is_onboarded FROM users WHERE id = auth.uid();

-- 3. Assign free tier
INSERT INTO subscription (user_id, tier_id, status_id, cycle_start_date, cycle_end_date)
SELECT auth.uid(), 
    (SELECT id FROM subscription_tier WHERE slug = 'free'),
    (SELECT id FROM subscription_status WHERE slug = 'active'),
    NOW(), NOW() + INTERVAL '1 month';

-- 4. Test quota
SELECT check_quota(auth.uid(), 'sync'); -- Should return true
SELECT increment_quota(auth.uid(), 'sync', 1);
SELECT syncs_used FROM subscription WHERE user_id = auth.uid(); -- Should be 1
```

**Success Criteria**:
- ✅ 10 tables created
- ✅ Free tier with 10 syncs, 25 AI analyses, 0 SEO submissions
- ✅ RLS policies working
- ✅ PII in auth.users.raw_user_meta_data (encrypted)

---

### Phase 2: Platform OAuth (Connection)
**Domain**: OAuth integration with social media platforms

**What's Included**:
- Tables (4): platform, account_status, platform_connection, social_account
- Initial Data: 5 platforms, 4 account statuses

**Edge Functions**: `oauth-youtube-init/callback`, `oauth-instagram-init/callback`, `oauth-tiktok-init/callback`

**API Keys**: YOUTUBE_CLIENT_ID, INSTAGRAM_CLIENT_ID, TIKTOK_CLIENT_ID

**Testing**:
```sql
-- 1. Get OAuth URL (POST /oauth-youtube-init)
-- 2. After callback, verify connection
SELECT * FROM platform_connection WHERE user_id = auth.uid();

-- 3. Verify token in Vault (NOT database!)
-- Check vault_secret_name is populated

-- 4. Verify social account
SELECT * FROM social_account WHERE user_id = auth.uid();

-- 5. Test quota (free tier = 1 account max)
```

**Success Criteria**:
- ✅ Tokens in Vault (GDPR compliant)
- ✅ Quota enforced (1 account for free tier)

---

### Phase 3: Content Sync (Data Ingestion)
**Domain**: Content synchronization from connected platforms

**What's Included**:
- Tables (3): content_type, content_item, content_revision
- Functions (1): prevent_account_deletion_with_content()
- Indexes: Full-text search (GIN), array search

**Edge Functions**: `sync-youtube`, `sync-instagram`, `sync-tiktok`

**Testing**:
```sql
-- 1. Sync content (POST /sync-youtube {"social_account_id": "..."})

-- 2. Verify content created
SELECT * FROM content_item WHERE social_account_id IN (
    SELECT id FROM social_account WHERE user_id = auth.uid()
) ORDER BY published_at DESC LIMIT 5;

-- 3. Test full-text search
SELECT title FROM content_item 
WHERE search_vector @@ plainto_tsquery('gaming') LIMIT 10;

-- 4. Test soft delete protection
DELETE FROM social_account WHERE user_id = auth.uid();
-- Should fail: "Cannot delete social account with existing content"
```

**Success Criteria**:
- ✅ Deduplication works (UNIQUE constraint)
- ✅ Full-text search returns results
- ✅ Soft delete protection active

---

### Phase 4: AI Enhancement (Intelligence)
**Domain**: AI-powered content tagging and optimization

**What's Included**:
- Tables (7): ai_provider, ai_model, user_ai_setting, ai_suggestion, ai_suggestion_application, ai_usage, trending_keyword
- Initial Data: 4 providers, 5 models

**Edge Functions**: `ai-generate-tags`

**API Keys**: OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_AI_API_KEY

**Testing**:
```sql
-- 1. Generate tags (POST /ai-generate-tags {"content_item_id": "..."})

-- 2. Verify suggestion
SELECT suggested_titles, suggested_tags, total_cost_cents
FROM ai_suggestion WHERE content_item_id = '...'

-- 3. Check usage tracking
SELECT prompt_tokens, completion_tokens, cost_cents
FROM ai_usage WHERE user_id = auth.uid() ORDER BY created_at DESC;

-- 4. Verify quota
SELECT ai_analyses_used FROM subscription WHERE user_id = auth.uid();
```

**Success Criteria**:
- ✅ Token usage tracked
- ✅ Cost calculated
- ✅ Quota enforced (25 analyses free tier)

---

### Phase 5: SEO Integration (Discoverability)
**Domain**: Search engine indexing and submission

**What's Included**:
- Tables (4): search_engine, seo_connection, seo_submission, seo_usage
- Initial Data: 4 search engines

**Edge Functions**: `get-seo-metadata`, `robots`, `sitemap`

**API Keys**: GOOGLE_SEARCH_CONSOLE_API_KEY, BING_WEBMASTER_API_KEY

**Testing**:
```sql
-- 1. Get SEO metadata (GET /get-seo-metadata?content_id=...)
-- 2. Get robots.txt (GET /robots)
-- 3. Get sitemap (GET /sitemap)

-- 4. Check submissions
SELECT submitted_url, status FROM seo_submission
WHERE connection_id IN (SELECT id FROM seo_connection WHERE user_id = auth.uid());
```

**Success Criteria**:
- ✅ SEO metadata with OG tags
- ✅ robots.txt allows crawlers
- ✅ Sitemap lists public content
- ✅ Free tier quota: 0 submissions

---

### Phase 6: Discovery Platform (Public Features)
**Domain**: Public browsing, trending content, creator discovery

**What's Included**:
- Tables (6): content_category, content_tag, content_click, content_media, trending_content, featured_creator
- Functions (4): generate_profile_slug(), update_total_followers(), increment_content_clicks(), calculate_trend_score()
- Initial Data: 15 categories

**Edge Functions**: `browse-content`, `browse-creators`, `search-content`, `get-trending`, `track-click`

**Testing**:
```sql
-- 1. Browse categories (GET /browse-categories)
-- 2. Search content (GET /search-content?q=minecraft)
-- 3. Track click (POST /track-click {"content_id": "..."})

-- 4. Check trending
SELECT title, calculate_trend_score(total_clicks, views_count, published_at)
FROM content_item ORDER BY 2 DESC LIMIT 10;

-- 5. Generate slug
SELECT generate_profile_slug('Tech Gaming', auth.uid());
-- Returns: 'tech-gaming'
```

**Success Criteria**:
- ✅ 15 categories browsable
- ✅ Trending algorithm works
- ✅ Click tracking (anonymous OK)
- ✅ Profile slugs unique

---

### Phase 7: Async Infrastructure (Background Processing)
**Domain**: Job queue, webhooks, background processing, Stripe billing

**What's Included**:
- Tables (4): job_type, job_queue, job_log, stripe_webhook_events
- Functions (24): Job management, webhook handlers, Stripe caching
- Indexes (20): Performance optimized

**Edge Functions**: `job-processor`, `stripe-webhook`, `job-status`

**API Keys**: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET

**Testing**:
```sql
-- 1. Create job
SELECT create_job(auth.uid(), 'sync_youtube', '{}'::jsonb, 5);

-- 2. Check status
SELECT * FROM get_user_jobs(auth.uid(), NULL, NULL, 10, 0);

-- 3. Test deduplication
SELECT * FROM find_or_create_job(auth.uid(), 'sync_youtube', '{}'::jsonb);
-- Should return existing job

-- 4. Simulate Stripe webhook
SELECT log_stripe_webhook_event('evt_test', 'subscription.created', '{}'::jsonb);

-- 5. Test caching
SELECT cache_stripe_data('stripe:product:test', '{"name":"Premium"}'::jsonb, 3600);
SELECT get_cached_stripe_data('stripe:product:test');
```

**Success Criteria**:
- ✅ Jobs queued and processed
- ✅ Deduplication works (5-min window)
- ✅ Stripe webhooks idempotent
- ✅ Rate limiting (10 jobs/user)

---

## 🔐 Security & Compliance

### PII Protection (GDPR/CCPA)
⚠️ **CRITICAL**: Email, full name, location stored in `auth.users.raw_user_meta_data` (encrypted), NOT in `public.users`

**Access PII**:
```sql
SELECT email FROM auth.users WHERE id = auth.uid();
-- Or use: auth.email()
```

### OAuth Token Security
- ✅ Tokens in Supabase Vault (encrypted)
- ✅ `vault_secret_name` reference only
- ✅ Never in database dumps

### Row Level Security
- ✅ Enabled on all user tables
- ✅ Users access own data only
- ✅ Public profiles visible to all

---

## 📊 Performance

| Phase | Deploy Time | Query Time | Indexes |
|-------|-------------|------------|---------|
| 1 | 30s | < 10ms | 12 |
| 2 | 15s | < 5ms | 3 |
| 3 | 20s | < 500ms | 8 |
| 4 | 25s | < 10ms | 5 |
| 5 | 15s | < 10ms | 3 |
| 6 | 20s | < 500ms | 12 |
| 7 | 30s | < 50ms | 20 |

**Total**: ~155s (phase-by-phase) or ~30s (combined)

---

## 🔧 Maintenance

### Updating a Phase
```bash
# 1. Edit schema
vim database/phases/phase_1_user_onboarding/schema.sql

# 2. Test locally
psql $DEV_DB -f database/phases/phase_1_user_onboarding/schema.sql

# 3. Create migration
cp database/phases/phase_1_user_onboarding/schema.sql \
   supabase/migrations/$(date +%Y%m%d%H%M%S)_update_phase1.sql

# 4. Deploy
supabase db push
```

### Combining Phases
```bash
cat database/phases/phase_*/schema.sql > combined_$(date +%Y%m%d).sql
```

---

## 🐛 Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| "table does not exist" | Missing dependency phase | Deploy phases in order |
| RLS blocks queries | Missing JWT token | Add Authorization header |
| OAuth tokens in database | Not using Vault | Update Edge Functions |
| Slow queries | Outdated statistics | Run `ANALYZE table_name` |

---

## ✅ Success Checklist

```sql
-- 38 tables
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- 33+ functions
SELECT COUNT(*) FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND p.prokind = 'f';

-- 80+ indexes
SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';

-- Initial data
SELECT COUNT(*) FROM subscription_tier; -- 3
SELECT COUNT(*) FROM platform; -- 5
SELECT COUNT(*) FROM content_category; -- 15
```

---

## 🎯 What Changed

**Before** (confusing):
- Multiple READMEs scattered everywhere
- Duplicate schemas in 3 locations
- Misnamed files (phase1 = actually phase6)

**After** (clean):
- ✅ One README with all docs
- ✅ One phases/ folder (single source of truth)
- ✅ Properly named by domain
- ✅ Clear DDD boundaries

---

## 📚 More Documentation

- `../PHASE_IMPLEMENTATION_ROADMAP.md` - Complete guide
- `../docs/DATABASE.md` - Architecture
- `../docs/ASYNC_ARCHITECTURE.md` - Job queue system

---

**🚀 Ready to deploy! Start with Phase 1.**
