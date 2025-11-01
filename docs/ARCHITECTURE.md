# StreamVibe - Architecture Guide

## 🎯 Core Design Principles

1. **Stripe is Source of Truth** - Never duplicate Stripe-managed data
2. **Multi-Layer Caching** - Memory + database cache for performance
3. **Vault for Secrets** - OAuth tokens stored in Supabase Vault only
4. **Edge Functions** - Serverless async processing
5. **Minimal Database** - Store only essential data

## 📊 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CLIENT (Frontend)                      │
│                 React/Next.js + Supabase JS                 │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   SUPABASE AUTH (Built-in)                  │
│              Google, Facebook, Email/Password               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    EDGE FUNCTIONS (Deno)                    │
│  OAuth Flows │ Content Sync │ AI Analysis │ SEO Submit     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   POSTGRESQL DATABASE                       │
│  Users │ Subscriptions │ Content │ Audit Logs              │
│                  + Row Level Security                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    SUPABASE VAULT                           │
│        OAuth Tokens │ API Keys (Encrypted Storage)          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                  EXTERNAL SERVICES                          │
│  Stripe │ YouTube │ Instagram │ TikTok │ OpenAI │ Google   │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow Patterns

### User Authentication Flow

```
User → Supabase Auth (Google/Email) → 
Create auth.users entry → 
Trigger creates users profile → 
Create default subscription (free tier) → 
Dashboard
```

### Platform Connection Flow

```
User → "Connect YouTube" Button →
Edge Function: initiate-oauth →
YouTube Authorization Screen →
User Grants Permission →
OAuth Callback URL →
Edge Function: oauth-callback →
Exchange code for tokens →
Store tokens in Vault →
Create platform_connection record (vault reference) →
Dashboard shows "Connected ✓"
```

### Content Sync Flow

```
User → "Sync Now" (or Auto-sync Trigger) →
Check quota: check_quota(user_id, 'sync') →
Edge Function: sync-content →
Retrieve tokens from Vault →
Call Platform API (YouTube Data API) →
Insert/update content_item records →
Increment quota: increment_quota(user_id, 'sync') →
Update last_synced_at →
Create notification →
Log to audit_log
```

### AI Analysis Flow

```
User → "Analyze Content" →
Check quota: check_quota(user_id, 'ai_analysis') →
Edge Function: ai-analyze →
Get user AI preferences →
Call AI API (OpenAI/Anthropic) →
Parse suggestions →
Insert ai_suggestion record →
Track usage: ai_usage (tokens, cost) →
Increment quota →
Display suggestions to user →
User applies suggestions →
Update content_item →
Log content_revision
```

### Billing Flow

```
Monthly Cycle:
├─ pg_cron: reset_quotas() (monthly)
├─ Reset syncs_used, ai_analyses_used, seo_submissions_used
├─ Move billing cycle forward
└─ Log to quota_usage_history

Stripe Events:
├─ subscription.created → Create subscription record
├─ subscription.updated → Update tier, status
├─ subscription.deleted → Mark canceled
├─ invoice.paid → Update cycle dates
└─ invoice.payment_failed → Mark past_due

Overage:
├─ User exceeds quota (still allowed)
├─ Usage reported to Stripe (metered billing)
├─ Stripe generates invoice
└─ Webhook updates subscription
```

## 🗄️ Database Strategy

### What We Store

| Table | Purpose | Why |
|-------|---------|-----|
| `cache_store` | External API cache | Fast access without sync issues |
| `subscription` | User quotas + Stripe refs | App logic, not in Stripe |
| `platform_connection` | Vault references | Pointer to encrypted tokens |
| `content_item` | Synced content | Core feature data |
| `audit_log` | Action history | Compliance & debugging |
| `quota_usage_history` | Usage analytics | Billing reconciliation |

### What We DON'T Store

| Data | Source of Truth | Access Method |
|------|----------------|---------------|
| Stripe Products | Stripe | Cached API (1hr TTL) |
| Stripe Prices | Stripe | Cached API (1hr TTL) |
| Stripe Customers | Stripe | Cached API (5min TTL) |
| OAuth Tokens | Vault | Service role access |
| Payment Methods | Stripe | Direct API (PCI) |

## 🔐 Security Architecture

### Two OAuth Systems

**1. User Authentication (Supabase Auth)**
- Purpose: Login to StreamVibe app
- Providers: Google, Facebook, Email
- Tokens: Managed by Supabase automatically
- Storage: Supabase Auth system

**2. Platform Access (Platform OAuth)**
- Purpose: Access user's social media content
- Providers: YouTube, Instagram, TikTok, Facebook
- Tokens: Managed by Edge Functions
- Storage: Supabase Vault (encrypted)

### Token Storage Pattern

```
❌ NEVER:
platform_connection {
  access_token: "ya29.a0...",  // DON'T DO THIS!
  refresh_token: "1//0..."     // SECURITY RISK!
}

✅ ALWAYS:
platform_connection {
  vault_secret_name: "oauth_youtube_user123"  // Reference only
}

Supabase Vault {
  name: "oauth_youtube_user123",
  secret: {
    access_token: "ya29.a0...",
    refresh_token: "1//0...",
    expires_at: "2025-11-02T10:00:00Z"
  }
}
```

### Row Level Security (RLS)

```sql
-- Users can only see their own data
CREATE POLICY users_select_own ON users
FOR SELECT USING (auth.uid() = id);

-- Derive ownership through joins
CREATE POLICY content_item_select_own ON content_item
FOR SELECT USING (
  auth.uid() IN (
    SELECT user_id FROM social_account
    WHERE id = content_item.social_account_id
  )
);

-- Public content visible to all
CREATE POLICY content_item_select_public ON content_item
FOR SELECT USING (
  visibility = 'public' AND deleted_at IS NULL
);

-- Admins bypass restrictions
CREATE POLICY admin_all ON users
FOR ALL USING (has_role(auth.uid(), 'admin'));
```

## 💾 Caching Strategy

### Cache Layers

```
Request → Memory Cache (1-5 min TTL)
            ↓ miss
         Database Cache (5-60 min TTL)
            ↓ miss
         External API (Stripe, etc.)
            ↓
         Update caches
```

### Cache Configuration

| Data Type | Memory TTL | DB TTL | Invalidation |
|-----------|-----------|---------|--------------|
| Stripe Products | 5 min | 1 hour | product.updated webhook |
| Stripe Prices | 5 min | 1 hour | price.updated webhook |
| User Profile | 1 min | 5 min | Profile update |
| Subscription | 30 sec | 1 min | subscription.* webhook |
| Trending Keywords | 10 min | 24 hours | Scheduled refresh |

### Implementation

```typescript
// Multi-layer cache function
async function getCachedStripeProducts(stripe: Stripe) {
  // Layer 1: Memory cache (in-process)
  const memCached = memoryCache.get('stripe_products');
  if (memCached && !isExpired(memCached)) {
    return memCached.data;
  }

  // Layer 2: Database cache
  const { data: dbCached } = await supabase
    .from('cache_store')
    .select('value')
    .eq('key', 'stripe_products')
    .gt('expires_at', new Date().toISOString())
    .single();

  if (dbCached) {
    memoryCache.set('stripe_products', dbCached.value, 300); // 5 min
    return dbCached.value;
  }

  // Layer 3: Stripe API
  const products = await stripe.products.list({ active: true });
  
  // Update both caches
  await supabase.from('cache_store').upsert({
    key: 'stripe_products',
    value: products.data,
    category: 'stripe_product',
    expires_at: new Date(Date.now() + 3600000) // 1 hour
  });

  memoryCache.set('stripe_products', products.data, 300);
  return products.data;
}
```

## 🔄 Background Jobs

### pg_cron Scheduled Jobs

```sql
-- Reset monthly quotas (1st of every month)
SELECT cron.schedule(
  'reset-monthly-quotas',
  '0 0 1 * *',
  $$ SELECT reset_quotas() $$
);

-- Cleanup expired notifications (daily at 2 AM)
SELECT cron.schedule(
  'cleanup-notifications',
  '0 2 * * *',
  $$ DELETE FROM notification 
     WHERE expires_at < NOW() $$
);

-- Cleanup expired cache (daily at 3 AM)
SELECT cron.schedule(
  'cleanup-cache',
  '0 3 * * *',
  $$ DELETE FROM cache_store 
     WHERE expires_at < NOW() $$
);

-- Verify platform connections (every 6 hours)
SELECT cron.schedule(
  'verify-connections',
  '0 */6 * * *',
  $$ 
    -- Edge Function call to verify OAuth tokens
  $$
);
```

### Edge Functions vs Job Queue

**✅ Edge Functions (Chosen Approach)**
- Execute immediately on trigger
- Auto-scale with demand
- No queue management needed
- Log execution in audit_log
- Stateless and simple

**❌ Persistent Job Queue (Rejected)**
- Requires queue table and cleanup
- Need worker processes
- Queue can grow large
- More complex architecture

## 📈 Performance Optimization

### Database Indexes

```sql
-- Composite indexes for common queries
CREATE INDEX idx_content_account_date 
ON content_item(social_account_id, published_at DESC);

-- Partial indexes (smaller, faster)
CREATE INDEX idx_active_connections 
ON platform_connection(user_id, platform_id) 
WHERE is_active = true;

-- GIN indexes for arrays/JSONB
CREATE INDEX idx_content_tags 
ON content_item USING GIN(tags);

-- Full-text search
CREATE INDEX idx_content_search 
ON content_item USING GIN(search_vector);
```

### Query Patterns

```sql
-- ✅ EFFICIENT: Uses composite index
SELECT * FROM content_item
WHERE social_account_id = $1
  AND deleted_at IS NULL
ORDER BY published_at DESC
LIMIT 20;

-- ✅ EFFICIENT: Uses partial index
SELECT * FROM platform_connection
WHERE user_id = $1
  AND is_active = true;

-- ✅ EFFICIENT: Uses GIN index
SELECT * FROM content_item
WHERE tags @> ARRAY['tutorial', 'javascript'];

-- ✅ EFFICIENT: Uses generated tsvector
SELECT * FROM content_item
WHERE search_vector @@ plainto_tsquery('english', 'react hooks tutorial')
ORDER BY ts_rank(search_vector, plainto_tsquery('english', 'react hooks tutorial')) DESC;
```

## 🚀 Deployment Architecture

### Environment Setup

```
Development:
├─ Local Supabase (Docker)
├─ Stripe Test Mode
├─ Mock AI responses
└─ Test OAuth apps

Staging:
├─ Supabase Staging Project
├─ Stripe Test Mode
├─ Limited AI quota
└─ Test OAuth apps

Production:
├─ Supabase Pro Project (us-east-1)
├─ Stripe Live Mode
├─ Full AI access
├─ Production OAuth apps
└─ CDN + Edge Functions globally
```

### Edge Function Deployment

```bash
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy oauth-callback

# Set secrets
supabase secrets set YOUTUBE_CLIENT_ID=xxx
supabase secrets set OPENAI_API_KEY=xxx
```

## 🛡️ Error Handling

### Retry Strategy

```typescript
// Exponential backoff for API calls
async function callWithRetry(
  apiCall: () => Promise<any>,
  maxRetries = 3
) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await apiCall();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      
      const delay = Math.min(1000 * Math.pow(2, i), 10000);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}
```

### Graceful Degradation

```typescript
// Fallback chain for cache failures
async function getProducts() {
  try {
    return await getCachedProducts(); // Try cache first
  } catch {
    try {
      return await stripe.products.list(); // Fallback to Stripe
    } catch {
      return defaultProducts; // Last resort: static data
    }
  }
}
```

## 📊 Monitoring & Observability

### Key Metrics

- API response times (p50, p95, p99)
- Edge Function execution time
- Database query performance
- Cache hit rates
- Quota usage patterns
- Stripe webhook processing time
- OAuth token refresh failures

### Logging Strategy

```typescript
// Structured logging
logger.info('content_sync_started', {
  user_id: userId,
  platform: 'youtube',
  account_id: accountId
});

logger.error('content_sync_failed', {
  user_id: userId,
  platform: 'youtube',
  error: error.message,
  stack: error.stack
});
```

## 🎯 Summary

| Decision | Rationale |
|----------|-----------|
| **Stripe as Source of Truth** | No sync issues, simpler maintenance |
| **Multi-Layer Caching** | 90%+ cache hit rate, fast responses |
| **Vault for Secrets** | Security best practice, encrypted |
| **Edge Functions** | Auto-scaling, no infrastructure management |
| **Minimal Database** | Only essential data, reduced complexity |
| **Row Level Security** | Database-enforced access control |
| **pg_cron** | Native PostgreSQL scheduling |

This architecture prioritizes **security**, **performance**, **scalability**, and **maintainability**! 🚀
