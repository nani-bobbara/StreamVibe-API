# StreamVibe - Stripe Caching Strategy

## 🎯 Problem
- Database tables create sync issues with Stripe
- API calls on every page load hurt performance
- Need balance between performance and data consistency

## ✅ Solution: Multi-Layer Caching

```
┌─────────────────────────────────────────────────────────┐
│                    CACHING LAYERS                       │
└─────────────────────────────────────────────────────────┘

Layer 1: App Config (Hardcoded)
  ↓ (For static IDs only)
  
Layer 2: Redis/Memory Cache (5-60 min TTL)
  ↓ (For frequently accessed data)
  
Layer 3: Stripe API (Source of Truth)
  ↓ (Always fresh, but slower)
```

---

## 📦 Implementation

### **1. App Config - Static References Only**

```typescript
// src/config/stripe.ts
export const STRIPE_CONFIG = {
  products: {
    free: {
      id: 'prod_FREE_TIER', // Hardcoded, never changes
      stripePriceId: null
    },
    basic: {
      id: 'prod_BASIC_TIER',
      stripePriceId: 'price_1234567890' // From Stripe Dashboard
    },
    premium: {
      id: 'prod_PREMIUM_TIER',
      stripePriceId: 'price_0987654321'
    }
  },
  
  // Metered usage price IDs
  meteredPrices: {
    syncs: 'price_metered_syncs',
    ai: 'price_metered_ai',
    indexing: 'price_metered_indexing'
  }
}

// These IDs NEVER change - safe to hardcode
// If you need to create new products, update config and redeploy
```

---

### **2. Supabase Edge Function with Caching**

```typescript
// supabase/functions/_shared/stripe-cache.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CACHE_TTL = {
  products: 3600, // 1 hour (rarely changes)
  prices: 3600,   // 1 hour
  customer: 300,  // 5 minutes (can change)
  subscription: 60 // 1 minute (frequently updates)
}

interface CacheEntry {
  data: any
  expiresAt: number
}

// In-memory cache (per Edge Function instance)
const memoryCache = new Map<string, CacheEntry>()

// Redis-like persistent cache using Supabase table
export class StripeCache {
  private supabase: any

  constructor(supabaseUrl: string, supabaseKey: string) {
    this.supabase = createClient(supabaseUrl, supabaseKey)
  }

  // Get from cache (memory → database → Stripe)
  async get(key: string, fetcher: () => Promise<any>, ttl: number): Promise<any> {
    // Layer 1: Check memory cache
    const memCached = memoryCache.get(key)
    if (memCached && memCached.expiresAt > Date.now()) {
      console.log(`Cache HIT (memory): ${key}`)
      return memCached.data
    }

    // Layer 2: Check persistent cache (Supabase table)
    const { data: cached } = await this.supabase
      .from('cache_store')
      .select('value, expires_at')
      .eq('key', key)
      .single()

    if (cached && new Date(cached.expires_at) > new Date()) {
      console.log(`Cache HIT (database): ${key}`)
      const parsed = JSON.parse(cached.value)
      
      // Store in memory for next request
      memoryCache.set(key, {
        data: parsed,
        expiresAt: new Date(cached.expires_at).getTime()
      })
      
      return parsed
    }

    // Layer 3: Fetch from Stripe
    console.log(`Cache MISS: ${key} - fetching from Stripe`)
    const freshData = await fetcher()

    // Store in both caches
    const expiresAt = new Date(Date.now() + ttl * 1000)
    
    // Memory cache
    memoryCache.set(key, {
      data: freshData,
      expiresAt: expiresAt.getTime()
    })

    // Persistent cache
    await this.supabase
      .from('cache_store')
      .upsert({
        key,
        value: JSON.stringify(freshData),
        expires_at: expiresAt.toISOString()
      })

    return freshData
  }

  // Invalidate cache
  async invalidate(key: string) {
    memoryCache.delete(key)
    await this.supabase
      .from('cache_store')
      .delete()
      .eq('key', key)
  }

  // Clear all cache
  async clear() {
    memoryCache.clear()
    await this.supabase
      .from('cache_store')
      .delete()
      .neq('key', '')
  }
}

// Helper functions
export async function getCachedProducts(stripe: any, cache: StripeCache) {
  return cache.get(
    'stripe:products:active',
    async () => {
      const products = await stripe.products.list({ active: true })
      return products.data
    },
    CACHE_TTL.products
  )
}

export async function getCachedPrices(stripe: any, cache: StripeCache) {
  return cache.get(
    'stripe:prices:active',
    async () => {
      const prices = await stripe.prices.list({ active: true })
      return prices.data
    },
    CACHE_TTL.prices
  )
}

export async function getCachedCustomer(stripe: any, cache: StripeCache, customerId: string) {
  return cache.get(
    `stripe:customer:${customerId}`,
    async () => {
      return await stripe.customers.retrieve(customerId)
    },
    CACHE_TTL.customer
  )
}

export async function getCachedSubscription(stripe: any, cache: StripeCache, subscriptionId: string) {
  return cache.get(
    `stripe:subscription:${subscriptionId}`,
    async () => {
      return await stripe.subscriptions.retrieve(subscriptionId)
    },
    CACHE_TTL.subscription
  )
}
```

---

### **3. Cache Store Table (Minimal)**

```sql
-- Simple key-value cache table in Supabase
CREATE TABLE public.cache_store (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cache_store_expires ON public.cache_store(expires_at);

COMMENT ON TABLE public.cache_store IS 'Generic cache store for external API responses (Stripe, etc)';

-- Auto-delete expired cache entries
CREATE OR REPLACE FUNCTION delete_expired_cache()
RETURNS void AS $$
BEGIN
    DELETE FROM public.cache_store
    WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup every hour
SELECT cron.schedule(
  'cleanup-expired-cache',
  '0 * * * *', -- Every hour
  $$
  SELECT delete_expired_cache();
  $$
);
```

---

### **4. Usage in Edge Functions**

```typescript
// supabase/functions/get-pricing/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.0.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { StripeCache, getCachedProducts, getCachedPrices } from '../_shared/stripe-cache.ts'
import { corsHeaders } from '../_shared/cors.ts'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient()
})

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const cache = new StripeCache(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Get cached products and prices (1 hour TTL)
    const [products, prices] = await Promise.all([
      getCachedProducts(stripe, cache),
      getCachedPrices(stripe, cache)
    ])

    // Combine data
    const pricing = products.map((product: any) => {
      const productPrices = prices.filter((price: any) => price.product === product.id)
      return {
        id: product.id,
        name: product.name,
        description: product.description,
        prices: productPrices.map((price: any) => ({
          id: price.id,
          amount: price.unit_amount,
          currency: price.currency,
          interval: price.recurring?.interval
        }))
      }
    })

    return new Response(
      JSON.stringify({ pricing }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Pricing error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

---

### **5. Cache Invalidation via Webhook**

```typescript
// supabase/functions/stripe-webhook/index.ts
import { StripeCache } from '../_shared/stripe-cache.ts'

// In webhook handler, invalidate cache when data changes
async function handleProductUpdated(product: any, supabase: any) {
  const cache = new StripeCache(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Invalidate products cache
  await cache.invalidate('stripe:products:active')
  
  console.log('Product cache invalidated:', product.id)
}

async function handlePriceUpdated(price: any, supabase: any) {
  const cache = new StripeCache(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Invalidate prices cache
  await cache.invalidate('stripe:prices:active')
  
  console.log('Price cache invalidated:', price.id)
}

async function handleSubscriptionUpdated(subscription: any, supabase: any) {
  const cache = new StripeCache(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Invalidate specific subscription cache
  await cache.invalidate(`stripe:subscription:${subscription.id}`)
  
  // Also invalidate customer cache (subscription data embedded)
  await cache.invalidate(`stripe:customer:${subscription.customer}`)
  
  console.log('Subscription cache invalidated:', subscription.id)
}

// Add these to webhook switch statement:
switch (event.type) {
  case 'product.created':
  case 'product.updated':
  case 'product.deleted':
    await handleProductUpdated(event.data.object, supabaseClient)
    break

  case 'price.created':
  case 'price.updated':
  case 'price.deleted':
    await handlePriceUpdated(event.data.object, supabaseClient)
    break

  case 'customer.subscription.updated':
    await handleSubscriptionUpdated(event.data.object, supabaseClient)
    break
  
  // ... existing webhook handlers
}
```

---

### **6. Frontend: Use Cached API**

```typescript
// src/lib/stripe-api.ts
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

// Fetch pricing (returns cached data from Edge Function)
export async function getPricing() {
  const { data, error } = await supabase.functions.invoke('get-pricing')
  
  if (error) throw error
  return data.pricing
}

// Frontend component
export default function PricingPage() {
  const [pricing, setPricing] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    getPricing()
      .then(setPricing)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [])

  // Pricing data is cached - fast response!
  return <div>...</div>
}
```

---

## 📊 Performance Comparison

| Approach | First Load | Subsequent Loads | Data Freshness | Sync Issues |
|----------|-----------|------------------|----------------|-------------|
| **Database Tables** | Fast | Fast | Stale (sync issues) | ⚠️ High Risk |
| **Direct API Calls** | Slow | Slow | Always Fresh | ✅ No Issues |
| **Multi-Layer Cache** | Medium | Fast | Fresh (auto-invalidate) | ✅ No Issues |

---

## 🎯 Cache Strategy Summary

| Data Type | Cache TTL | Invalidation Trigger |
|-----------|-----------|---------------------|
| **Products** | 1 hour | `product.updated` webhook |
| **Prices** | 1 hour | `price.updated` webhook |
| **Customer** | 5 minutes | `customer.updated` webhook |
| **Subscription** | 1 minute | `subscription.updated` webhook |
| **Invoices** | No cache | Always fetch fresh (infrequent access) |

---

## ✅ Benefits

1. **Performance**: Fast response times with caching
2. **Consistency**: Stripe is source of truth, auto-invalidation prevents stale data
3. **Scalability**: Memory + database caching reduces Stripe API calls
4. **Reliability**: Falls back to Stripe if cache fails
5. **No Sync Issues**: No duplicate data to keep in sync

---

## 🚫 What NOT to Cache

- Payment methods (PCI compliance)
- Sensitive customer data
- Real-time subscription status (use short TTL)
- Webhook events (process immediately)

This approach gives you the performance of database tables without the sync headaches! 🚀
