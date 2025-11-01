# StreamVibe - Schema Refactoring Analysis

## 🎯 Naming Convention Issues & Fixes

### **Current Issues:**

1. **Inconsistent Pluralization**
   - ❌ `supported_platform_types` (plural)
   - ❌ `supported_content_types` (plural)
   - ❌ `supported_job_types` (plural)
   - ✅ `profiles` (plural - correct for user-facing)
   - ❌ `user_roles` (plural)
   - ❌ `notifications` (plural)

2. **Redundant Prefixes**
   - ❌ `supported_*` prefix is verbose
   - ❌ `user_*` prefix sometimes redundant (already has user_id FK)

3. **Unclear Table Names**
   - ❌ `handle_content` - unclear what "handle" means
   - ❌ `seo_payloads` - "payloads" is technical jargon
   - ❌ `platform_credentials` - could be clearer

---

## ✅ Proposed Naming Refactor

### **System/Lookup Tables (Singular)**
```
supported_platform_types → platforms
supported_content_types → content_types  
supported_job_types → job_types
```

### **User Data Tables (Plural)**
```
profiles → users (or keep profiles - both valid)
user_roles → user_roles (keep - junction table)
user_preferences → user_settings (clearer)
subscription_settings → subscriptions (standard)
```

### **Core Business Tables (Plural)**
```
platform_credentials → platform_connections
account_handles → social_accounts
handle_content → content_items
content_edit_history → content_revisions
ai_content_suggestions → ai_suggestions
seo_payloads → seo_submissions
notifications → notifications (keep)
audit_log → audit_logs
quota_usage_history → quota_usage
```

---

## 🗄️ Normalization Issues

### **Issue 1: Denormalization in `subscription_settings`**

**Current:**
```sql
CREATE TABLE subscription_settings (
  max_handles INT,
  max_syncs INT,
  max_ai_enhancements INT,
  max_indexing_submissions INT,
  current_handles_count INT,
  current_syncs_count INT,
  current_ai_count INT,
  current_indexing_count INT,
  ...
)
```

**Problem:** Quota limits should be in a separate tier config table

**Fix:** Create `subscription_tiers` lookup table

```sql
CREATE TABLE subscription_tiers (
  id UUID PRIMARY KEY,
  tier_name tier_enum NOT NULL UNIQUE,
  max_social_accounts INT NOT NULL,
  max_syncs_per_month INT NOT NULL,
  max_ai_analyses_per_month INT NOT NULL,
  max_seo_submissions_per_month INT NOT NULL,
  stripe_price_id TEXT,
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES users(id),
  tier_id UUID NOT NULL REFERENCES subscription_tiers(id),
  
  -- Current usage (resets monthly)
  syncs_used INT DEFAULT 0,
  ai_analyses_used INT DEFAULT 0,
  seo_submissions_used INT DEFAULT 0,
  
  -- Stripe integration
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  
  -- Billing cycle
  cycle_start_date TIMESTAMPTZ NOT NULL,
  cycle_end_date TIMESTAMPTZ NOT NULL,
  
  -- Status
  status subscription_status_enum DEFAULT 'active',
  canceled_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### **Issue 2: Redundant `user_id` in Many Tables**

**Current:** Many tables have both `user_id` and related entity FK

Example:
```sql
CREATE TABLE handle_content (
  user_id UUID REFERENCES profiles(id), -- Redundant!
  handle_id UUID REFERENCES account_handles(id),
  ...
)
```

**Problem:** `user_id` can be derived via `handle_id -> account_handles -> user_id`

**Fix:** Remove redundant `user_id` columns where relationship exists

---

### **Issue 3: Missing Junction Tables**

**Current:** `ai_content_suggestions.applied_fields TEXT[]` - array column

**Problem:** Can't query "all suggestions where title was applied"

**Fix:** Create junction table

```sql
CREATE TABLE ai_suggestion_applications (
  id UUID PRIMARY KEY,
  suggestion_id UUID NOT NULL REFERENCES ai_suggestions(id),
  field_name TEXT NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  applied_by_user_id UUID NOT NULL REFERENCES users(id)
);
```

---

### **Issue 4: Overly Generic JSONB Columns**

**Current:**
```sql
metadata JSONB
response_data JSONB
```

**Problem:** Unclear structure, hard to query

**Fix:** Create typed columns for common fields, keep JSONB for extras

```sql
-- Instead of:
seo_payloads (
  response_data JSONB
)

-- Do:
seo_submissions (
  http_status_code INT,
  success BOOLEAN,
  error_code TEXT,
  error_message TEXT,
  additional_data JSONB -- Only for extras
)
```

---

## 📊 Index Optimization

### **Missing Composite Indexes**

```sql
-- Frequently queried together
CREATE INDEX idx_content_user_platform_date 
ON content_items(user_id, platform_id, published_at DESC);

CREATE INDEX idx_content_status_visibility 
ON content_items(user_id, visibility, deleted_at) 
WHERE deleted_at IS NULL;

-- Covering index for dashboard queries
CREATE INDEX idx_social_accounts_user_active 
ON social_accounts(user_id, platform_id, is_active, last_synced_at DESC) 
WHERE deleted_at IS NULL;
```

### **Missing Partial Indexes**

```sql
-- Only index active/pending records
CREATE INDEX idx_seo_submissions_pending 
ON seo_submissions(user_id, status, next_retry_at) 
WHERE status IN ('pending', 'failed') AND retry_count < max_retries;

-- Only index unread notifications
CREATE INDEX idx_notifications_unread 
ON notifications(user_id, created_at DESC) 
WHERE status = 'unread';
```

### **Missing GIN Indexes**

```sql
-- For array searches
CREATE INDEX idx_ai_suggestions_keywords_gin 
ON ai_suggestions USING GIN(keywords);

CREATE INDEX idx_content_tags_gin 
ON content_items USING GIN(tags);

-- For JSONB queries
CREATE INDEX idx_audit_logs_metadata_gin 
ON audit_logs USING GIN(metadata);
```

---

## 🏗️ Column Naming Issues

### **Inconsistent Timestamp Names**

**Current Mix:**
- `created_at`, `updated_at` ✅
- `published_at` ✅
- `last_synced_at` ✅
- `applied_at` ✅
- `canceled_at` ✅ (should be `cancelled_at` in UK English)

**Fix:** Standardize to `*_at` suffix for all timestamps

### **Boolean Column Naming**

**Current Mix:**
- `is_active` ✅
- `fully_applied` ❌ (should be `is_fully_applied`)
- `auto_renew` ❌ (should be `is_auto_renew` or `auto_renew_enabled`)
- `verified` ❌ (should be `is_verified`)

**Fix:** All booleans should use `is_*` or `has_*` or `*_enabled` prefix

---

## 🔄 Edge Function Naming

### **Current Names:**
```
initiate-platform-oauth
platform-oauth-callback
sync-platform-content
create-checkout-session
stripe-webhook
report-stripe-usage
ai-analyze-content
seo-submit-url
seo-check-status
```

### **Proposed Standardized Names:**
```
oauth/initiate           (group by domain)
oauth/callback
sync/content
sync/batch-content

billing/create-checkout
billing/webhook
billing/report-usage

ai/analyze-content
ai/apply-suggestions
ai/batch-analyze

seo/submit-url
seo/check-status
seo/batch-submit
```

---

## 📋 Enum Refactoring

### **Current:**
```sql
CREATE TYPE subscription_tier AS ENUM ('free', 'basic', 'premium');
CREATE TYPE subscription_status AS ENUM ('active', 'canceled', 'past_due', 'trialing');
```

### **Issues:**
- Enums are hard to modify (need migration)
- Better to use lookup tables for extensibility

### **Proposed Fix:**
```sql
-- Replace enums with lookup tables for flexibility
CREATE TABLE subscription_tiers (
  id UUID PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE, -- 'free', 'basic', 'premium'
  display_name TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE subscription_statuses (
  id UUID PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE, -- 'active', 'canceled', etc.
  display_name TEXT NOT NULL,
  description TEXT
);
```

---

## 🎯 Final Recommendations

### **High Priority:**
1. ✅ Rename tables for consistency (singular lookup, plural data)
2. ✅ Extract `subscription_tiers` to separate table
3. ✅ Remove redundant `user_id` columns
4. ✅ Add composite indexes for common queries
5. ✅ Add partial indexes for active/pending records
6. ✅ Standardize boolean column naming (`is_*`)

### **Medium Priority:**
1. ⚠️ Replace enums with lookup tables (for extensibility)
2. ⚠️ Create junction tables for many-to-many relationships
3. ⚠️ Break down large JSONB columns into typed columns
4. ⚠️ Add GIN indexes for array/JSONB columns

### **Low Priority:**
1. 💡 Rename Edge Functions for grouping
2. 💡 Add covering indexes for specific queries
3. 💡 Consider partitioning for `audit_logs` (if high volume)

---

## 📊 Before & After Comparison

| Aspect | Before (v2) | After (v3) | Benefit |
|--------|-------------|------------|---------|
| **Table Names** | Mixed singular/plural | Consistent convention | Clarity |
| **Normalization** | Some redundancy | Fully normalized | Data integrity |
| **Indexes** | Basic indexes | Composite + Partial | Query performance |
| **Booleans** | Mixed naming | `is_*` prefix | Consistency |
| **Enums** | Hardcoded | Lookup tables | Flexibility |
| **Columns** | Some redundant | Minimal duplication | Maintainability |

---

## 🚀 Next Steps

1. Review and approve naming changes
2. Create StreamVibe_v3_production.sql with all improvements
3. Update all Edge Function names and references
4. Update frontend API calls to match new names
5. Create migration script from v2 → v3
