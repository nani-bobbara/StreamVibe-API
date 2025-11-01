# StreamVibe - Architecture Decisions

## 🎯 Key Design Principles

1. **Stripe is Source of Truth** - Never duplicate Stripe-managed data in database tables
2. **Cache for Performance** - Use multi-layer caching (memory + database) for frequently accessed data
3. **Minimal Database Tables** - Only store what's essential: references, idempotency, usage tracking
4. **Supabase Vault for Secrets** - Never store OAuth tokens in regular tables
5. **Edge Functions for Async** - No persistent job queue; use Edge Functions + audit logging

---

## 📊 Architecture Comparison

### **Approach 1: Database Tables (❌ Not Recommended)**

```sql
-- Duplicate Stripe data in database
CREATE TABLE stripe_products (...)
CREATE TABLE stripe_prices (...)
CREATE TABLE stripe_customers (...)
```

**Problems:**
- ⚠️ **Sync Issues**: Database can become stale, out of sync with Stripe
- ⚠️ **Data Duplication**: Two sources of truth (Stripe + database)
- ⚠️ **Maintenance Overhead**: Need to keep tables updated via webhooks
- ⚠️ **Migration Complexity**: Schema changes require coordinated updates

---

### **Approach 2: Direct API Calls (⚠️ Slow)**

```typescript
// Every request hits Stripe API
const products = await stripe.products.list()
const prices = await stripe.prices.list()
```

**Problems:**
- 🐌 **Slow Performance**: API calls add 200-500ms latency
- 💰 **API Rate Limits**: Can hit Stripe rate limits with high traffic
- ❌ **No Offline Capability**: Depends on Stripe API availability

---

### **Approach 3: Multi-Layer Caching (✅ Recommended)**

```typescript
// Memory cache → Database cache → Stripe API
const products = await getCachedProducts(stripe, cache)
```

**Benefits:**
- ✅ **Fast Performance**: Memory cache returns in <1ms
- ✅ **No Sync Issues**: Stripe is source of truth, cache auto-invalidates
- ✅ **Reduced API Calls**: 90%+ cache hit rate reduces costs
- ✅ **Graceful Degradation**: Falls back to Stripe if cache fails
- ✅ **Flexible TTL**: Different cache durations for different data types

---

## 🗄️ Database Design

### **What We Store in Database**

| Table | Purpose | Why |
|-------|---------|-----|
| `cache_store` | Generic key-value cache | Fast access to Stripe data without sync issues |
| `stripe_webhook_events` | Webhook idempotency log | Prevent duplicate processing (critical!) |
| `stripe_usage_records` | Metered usage tracking | Billing reconciliation, user dashboard |
| `payment_history` | Payment audit trail | Optional - can query Stripe API instead |
| `subscription_settings` | User quotas + Stripe refs | App-specific logic, not managed by Stripe |

### **What We DON'T Store**

| Data | Managed By | Access Method |
|------|-----------|---------------|
| Products | Stripe | Cached API calls (1hr TTL) |
| Prices | Stripe | Cached API calls (1hr TTL) |
| Customers | Stripe | Cached API calls (5min TTL) |
| Subscriptions | Stripe | Cached API calls (1min TTL) |
| Invoices | Stripe | Direct API calls (no cache) |
| Payment Methods | Stripe | Direct API calls (PCI compliance) |

---

## 🔐 Security Design

### **OAuth Token Management**

```
❌ NEVER: Store tokens in database tables
✅ ALWAYS: Store tokens in Supabase Vault

Database Table:
  platform_credentials.vault_secret_name = "platform_token_user123_youtube"
  
Supabase Vault:
  vault.secrets.name = "platform_token_user123_youtube"
  vault.secrets.secret = {"access_token": "...", "refresh_token": "..."}
```

**Why:**
- Vault is encrypted at rest
- Service role key required for access
- Automatic key rotation support
- Audit logging built-in

### **Two OAuth Systems**

| Purpose | System | Tokens Stored |
|---------|--------|---------------|
| **User Login** | Supabase Auth | Managed by Supabase (automatic) |
| **Platform Access** | YouTube/Instagram/TikTok OAuth | Stored in Vault (manual) |

---

## 🔄 Job Queue vs Edge Functions

### **Approach 1: Persistent Job Queue (❌ Not Recommended)**

```sql
-- Persistent job queue table
CREATE TABLE job_queue (
  id UUID,
  job_type TEXT,
  status TEXT,
  payload JSONB,
  ...
)
```

**Problems:**
- ⚠️ **Performance**: Queue grows large, slows down queries
- ⚠️ **Cleanup**: Need cron jobs to delete old jobs
- ⚠️ **Complexity**: Worker processes to poll queue

---

### **Approach 2: Edge Functions + Audit Log (✅ Recommended)**

```typescript
// Edge Function executes immediately
const result = await syncPlatformContent(handleId)

// Log execution in audit_log
await supabase.from('audit_log').insert({
  action: 'platform_sync',
  job_type: 'handle_sync',
  job_status: 'completed',
  job_result: result
})
```

**Benefits:**
- ✅ **No Queue Bloat**: No persistent queue, jobs execute and log
- ✅ **Simpler**: No worker processes needed
- ✅ **Audit Trail**: Complete history in audit_log
- ✅ **Scalable**: Edge Functions auto-scale

---

## 💰 Usage Quota & Billing Flow

```
┌─────────────────────────────────────────────────────────┐
│            USAGE TRACKING FLOW                          │
└─────────────────────────────────────────────────────────┘

1. User Action (Sync Content)
   ↓
2. Check Quota (subscription_settings)
   ↓ (Allow even if over - bill overage)
3. Perform Action
   ↓
4. Increment Usage Counter (RPC function)
   ↓
5. Log Usage (quota_usage_history)
   ↓
6. Hourly Cron Job
   ↓
7. Calculate Overage
   ↓
8. Report to Stripe (metered billing)
   ↓
9. Stripe Generates Invoice
   ↓
10. Payment Processed
    ↓
11. Webhook: Reset Counters
```

**Key Points:**
- Users can exceed quotas (pay for overage)
- Usage reported to Stripe hourly
- Billing happens at end of period
- Webhooks reset counters automatically

---

## 🎯 Data Flow Summary

### **User Signup Flow**

```
User → Supabase Auth (Google/Email) → 
Profile Created (trigger) → 
subscription_settings Created (free tier) →
Dashboard
```

### **Platform Connection Flow**

```
User → "Connect YouTube" →
Edge Function: initiate-platform-oauth →
YouTube Auth Screen →
User Grants Permission →
OAuth Callback →
Edge Function: platform-oauth-callback →
Exchange Code for Tokens →
Store in Vault →
Update platform_credentials (vault reference) →
Dashboard (Connected ✓)
```

### **Content Sync Flow**

```
User → "Sync YouTube" →
Edge Function: sync-platform-content →
Retrieve Tokens from Vault →
Call YouTube API →
Store Videos in handle_content →
Increment Quota Counter →
Log to quota_usage_history →
Update last_synced_at →
Return Success
```

### **Billing Flow**

```
User → Pricing Page →
Edge Function: create-checkout-session →
Stripe Checkout →
Payment Success →
Webhook: checkout.session.completed →
Update subscription_settings (quotas) →
Store stripe_subscription_id →
Dashboard (Basic Plan ✓)

(Meanwhile, hourly cron job reports usage to Stripe)
```

---

## 📈 Performance Optimization

### **Caching Strategy**

| Data Type | Cache Layer | TTL | Invalidation |
|-----------|-------------|-----|--------------|
| Stripe Products | Memory + DB | 1 hour | product.updated webhook |
| Stripe Prices | Memory + DB | 1 hour | price.updated webhook |
| User Profile | Memory + DB | 5 min | profile update |
| Subscription | Memory + DB | 1 min | subscription.updated webhook |

### **Database Indexes**

```sql
-- Performance-critical indexes
CREATE INDEX idx_handle_content_user_platform_published 
  ON handle_content(user_id, platform_id, published_at DESC);

CREATE INDEX idx_platform_credentials_user_platform 
  ON platform_credentials(user_id, platform_id) 
  WHERE is_active = true;

CREATE INDEX idx_subscription_settings_stripe_customer 
  ON subscription_settings(stripe_customer_id) 
  WHERE stripe_customer_id IS NOT NULL;
```

### **Full-Text Search**

```sql
-- tsvector for fast content search
ALTER TABLE handle_content 
ADD COLUMN search_vector tsvector 
GENERATED ALWAYS AS (
  setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(description, '')), 'B')
) STORED;

CREATE INDEX idx_handle_content_search ON handle_content USING GIN(search_vector);
```

---

## 🔒 Security Best Practices

1. **✅ Row Level Security (RLS)**: Enabled on all user-facing tables
2. **✅ Service Role**: Used only in Edge Functions for Vault access
3. **✅ Anon Key**: Used in frontend, restricted by RLS
4. **✅ Webhook Secrets**: Verify Stripe webhook signatures
5. **✅ Token Storage**: OAuth tokens only in Vault, never in database
6. **✅ HTTPS Only**: All API calls use HTTPS
7. **✅ Environment Variables**: All secrets in env vars, never in code

---

## 🚀 Deployment Checklist

### **Supabase Setup**
- [ ] Create Supabase project
- [ ] Enable pg_cron extension
- [ ] Deploy schema (StreamVibe_v2_improved.sql)
- [ ] Enable RLS on all tables
- [ ] Configure Auth providers (Google, Facebook)

### **Stripe Setup**
- [ ] Create Stripe account
- [ ] Create products (Free, Basic, Premium)
- [ ] Create prices (recurring + metered)
- [ ] Configure webhook endpoint
- [ ] Add webhook secret to env vars
- [ ] Test webhook with Stripe CLI

### **Edge Functions**
- [ ] Deploy initiate-platform-oauth
- [ ] Deploy platform-oauth-callback
- [ ] Deploy sync-platform-content
- [ ] Deploy create-checkout-session
- [ ] Deploy stripe-webhook
- [ ] Deploy report-stripe-usage
- [ ] Configure cron job for usage reporting

### **Platform OAuth Apps**
- [ ] Register YouTube Data API app
- [ ] Register Instagram Basic Display API app
- [ ] Register TikTok Developer app
- [ ] Add OAuth credentials to env vars
- [ ] Configure redirect URIs

### **Frontend**
- [ ] Build signup/login flow
- [ ] Build dashboard with platform connections
- [ ] Build pricing page with Stripe Checkout
- [ ] Build usage dashboard
- [ ] Build content sync UI
- [ ] Test end-to-end flows

---

## 🎯 Summary: Why This Architecture?

| Decision | Rationale |
|----------|-----------|
| **Stripe as Source of Truth** | No sync issues, simpler maintenance |
| **Multi-Layer Caching** | Fast performance without data duplication |
| **Vault for Tokens** | Security best practice, encrypted storage |
| **Edge Functions vs Queue** | Simpler, auto-scaling, no cleanup needed |
| **Minimal Database Tables** | Only essential data, reduces complexity |
| **Metered Billing** | Fair pricing, users pay for what they use |
| **Webhook-Driven** | Real-time updates, automated workflows |

This architecture balances **performance**, **security**, **maintainability**, and **cost**! 🚀
