# StreamVibe - Stripe Integration for Usage Quotas & Billing

## 🎯 Overview

StreamVibe uses Stripe for:
1. **Subscription Management** - Free, Basic, Premium tiers
2. **Usage-Based Billing** - Metered billing for quotas (syncs, AI enhancements, indexing)
3. **Webhook Events** - Real-time quota updates and billing events
4. **Customer Portal** - Self-service subscription management

---

## 📊 Pricing Strategy

### **Subscription Tiers**

| Tier | Price | Handles | Syncs/Month | AI Enhancements/Month | SEO Indexing/Month |
|------|-------|---------|-------------|----------------------|-------------------|
| **Free** | $0/mo | 1 | 10 | 25 | 0 |
| **Basic** | $19/mo | 5 | 500 | 500 | 100 |
| **Premium** | $49/mo | 20 | 2,000 | 2,000 | 1,000 |

### **Usage-Based Add-ons** (Beyond Quota)
- Extra syncs: $0.10 per 10 syncs
- Extra AI enhancements: $0.05 per enhancement
- Extra indexing: $0.20 per submission

---

## 🗄️ Enhanced Database Schema

### **Add Stripe-Related Tables**

```sql
-- =================================================================================
-- STRIPE INTEGRATION TABLES
-- =================================================================================

-- Stripe Products (Subscription Tiers)
CREATE TABLE public.stripe_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_product_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL, -- 'Free', 'Basic', 'Premium'
    tier public.subscription_tier NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.stripe_products IS 'Maps Stripe products to subscription tiers';

-- Stripe Prices
CREATE TABLE public.stripe_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_price_id TEXT NOT NULL UNIQUE,
    stripe_product_id TEXT NOT NULL REFERENCES public.stripe_products(stripe_product_id),
    unit_amount INT NOT NULL, -- in cents
    currency TEXT NOT NULL DEFAULT 'usd',
    recurring_interval TEXT, -- 'month', 'year', null for one-time
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.stripe_prices IS 'Stripe price objects for products';

-- Stripe Metered Usage (Usage-based billing)
CREATE TABLE public.stripe_usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    stripe_subscription_item_id TEXT NOT NULL,
    usage_type TEXT NOT NULL, -- 'sync', 'ai_enhancement', 'indexing'
    quantity INT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    stripe_usage_record_id TEXT, -- Returned by Stripe after submission
    submitted_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.stripe_usage_records IS 'Tracks metered usage sent to Stripe for billing';

CREATE INDEX idx_stripe_usage_user_type ON public.stripe_usage_records(user_id, usage_type);
CREATE INDEX idx_stripe_usage_submitted ON public.stripe_usage_records(submitted_at) WHERE submitted_at IS NOT NULL;

-- Stripe Webhook Events (Idempotency & Audit)
CREATE TABLE public.stripe_webhook_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_event_id TEXT NOT NULL UNIQUE,
    event_type TEXT NOT NULL,
    event_data JSONB NOT NULL,
    processed BOOLEAN NOT NULL DEFAULT false,
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.stripe_webhook_events IS 'Stripe webhook event log for idempotency and debugging';

CREATE INDEX idx_stripe_webhook_type ON public.stripe_webhook_events(event_type);
CREATE INDEX idx_stripe_webhook_processed ON public.stripe_webhook_events(processed, created_at);

-- Payment History
CREATE TABLE public.payment_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    stripe_invoice_id TEXT,
    stripe_payment_intent_id TEXT,
    amount INT NOT NULL, -- in cents
    currency TEXT NOT NULL DEFAULT 'usd',
    status TEXT NOT NULL, -- 'succeeded', 'failed', 'pending'
    description TEXT,
    invoice_pdf_url TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.payment_history IS 'User payment history from Stripe';

CREATE INDEX idx_payment_history_user ON public.payment_history(user_id, created_at DESC);

-- =================================================================================
-- UPDATE EXISTING subscription_settings TABLE
-- =================================================================================

-- Add Stripe subscription item IDs for metered billing
ALTER TABLE public.subscription_settings
ADD COLUMN IF NOT EXISTS stripe_subscription_item_syncs TEXT,
ADD COLUMN IF NOT EXISTS stripe_subscription_item_ai TEXT,
ADD COLUMN IF NOT EXISTS stripe_subscription_item_indexing TEXT,
ADD COLUMN IF NOT EXISTS stripe_price_id TEXT;

COMMENT ON COLUMN public.subscription_settings.stripe_subscription_item_syncs IS 'Stripe subscription item for metered sync billing';
COMMENT ON COLUMN public.subscription_settings.stripe_subscription_item_ai IS 'Stripe subscription item for metered AI enhancement billing';
COMMENT ON COLUMN public.subscription_settings.stripe_subscription_item_indexing IS 'Stripe subscription item for metered indexing billing';
```

---

## 🔧 Stripe Setup

### **1. Create Products in Stripe Dashboard**

```bash
# Or use Stripe API/CLI
stripe products create \
  --name "StreamVibe Free" \
  --description "Free tier with basic features"

stripe products create \
  --name "StreamVibe Basic" \
  --description "Basic tier for content creators"

stripe products create \
  --name "StreamVibe Premium" \
  --description "Premium tier for professionals"
```

### **2. Create Prices**

```bash
# Basic - $19/month
stripe prices create \
  --product prod_BASIC_ID \
  --unit-amount 1900 \
  --currency usd \
  --recurring interval=month

# Premium - $49/month
stripe prices create \
  --product prod_PREMIUM_ID \
  --unit-amount 4900 \
  --currency usd \
  --recurring interval=month

# Metered pricing for usage-based billing
stripe prices create \
  --product prod_ADDON_SYNCS \
  --currency usd \
  --recurring interval=month \
  --recurring usage_type=metered \
  --billing_scheme tiered \
  --tiers-mode graduated \
  --tiers[0][up_to]=100 \
  --tiers[0][unit_amount]=10 \
  --tiers[1][up_to]=inf \
  --tiers[1][unit_amount]=5
```

### **3. Configure Webhooks**

In Stripe Dashboard → Developers → Webhooks, add endpoint:
```
https://your-project.supabase.co/functions/v1/stripe-webhook
```

Select events:
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`
- `checkout.session.completed`
- `customer.created`
- `customer.updated`

---

## 🚀 Implementation

### **Edge Function: Create Checkout Session**

```typescript
// supabase/functions/create-checkout-session/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.0.0'
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
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('No authorization header')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) throw new Error('User not found')

    const { priceId, tier } = await req.json()

    // Get or create Stripe customer
    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('email, full_name')
      .eq('id', user.id)
      .single()

    const { data: subscription } = await supabaseClient
      .from('subscription_settings')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .single()

    let customerId = subscription?.stripe_customer_id

    if (!customerId) {
      // Create Stripe customer
      const customer = await stripe.customers.create({
        email: profile.email,
        name: profile.full_name,
        metadata: { supabase_user_id: user.id }
      })
      customerId = customer.id

      // Update database
      await supabaseClient
        .from('subscription_settings')
        .update({ stripe_customer_id: customerId })
        .eq('user_id', user.id)
    }

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1
        }
      ],
      success_url: `${Deno.env.get('APP_URL')}/dashboard?checkout=success`,
      cancel_url: `${Deno.env.get('APP_URL')}/pricing?checkout=canceled`,
      metadata: {
        supabase_user_id: user.id,
        tier
      },
      subscription_data: {
        metadata: {
          supabase_user_id: user.id,
          tier
        }
      }
    })

    return new Response(
      JSON.stringify({ sessionId: session.id, url: session.url }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Checkout error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

---

### **Edge Function: Stripe Webhook Handler**

```typescript
// supabase/functions/stripe-webhook/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.0.0'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient()
})

const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')!

serve(async (req) => {
  const signature = req.headers.get('stripe-signature')
  if (!signature) {
    return new Response('No signature', { status: 400 })
  }

  try {
    const body = await req.text()
    const event = stripe.webhooks.constructEvent(body, signature, webhookSecret)

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Check for duplicate events (idempotency)
    const { data: existingEvent } = await supabaseClient
      .from('stripe_webhook_events')
      .select('id')
      .eq('stripe_event_id', event.id)
      .single()

    if (existingEvent) {
      console.log('Duplicate event, skipping:', event.id)
      return new Response(JSON.stringify({ received: true }), { status: 200 })
    }

    // Log webhook event
    await supabaseClient.from('stripe_webhook_events').insert({
      stripe_event_id: event.id,
      event_type: event.type,
      event_data: event.data
    })

    // Handle specific events
    switch (event.type) {
      case 'checkout.session.completed': {
        await handleCheckoutComplete(event.data.object, supabaseClient)
        break
      }

      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        await handleSubscriptionUpdate(event.data.object, supabaseClient)
        break
      }

      case 'customer.subscription.deleted': {
        await handleSubscriptionCanceled(event.data.object, supabaseClient)
        break
      }

      case 'invoice.payment_succeeded': {
        await handlePaymentSucceeded(event.data.object, supabaseClient)
        break
      }

      case 'invoice.payment_failed': {
        await handlePaymentFailed(event.data.object, supabaseClient)
        break
      }

      default:
        console.log('Unhandled event type:', event.type)
    }

    // Mark as processed
    await supabaseClient
      .from('stripe_webhook_events')
      .update({ processed: true, processed_at: new Date().toISOString() })
      .eq('stripe_event_id', event.id)

    return new Response(JSON.stringify({ received: true }), { status: 200 })

  } catch (error) {
    console.error('Webhook error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400 }
    )
  }
})

// ============================================================================
// EVENT HANDLERS
// ============================================================================

async function handleCheckoutComplete(session: any, supabase: any) {
  const userId = session.metadata?.supabase_user_id
  const tier = session.metadata?.tier

  if (!userId) {
    console.error('No user ID in checkout session metadata')
    return
  }

  const subscription = await stripe.subscriptions.retrieve(session.subscription)

  // Get quota limits based on tier
  const quotas = getQuotaLimits(tier)

  // Update subscription settings
  await supabase
    .from('subscription_settings')
    .update({
      tier,
      stripe_subscription_id: subscription.id,
      stripe_customer_id: session.customer,
      billing_cycle_start: new Date(subscription.current_period_start * 1000),
      billing_cycle_end: new Date(subscription.current_period_end * 1000),
      ...quotas,
      // Reset usage counts on new subscription
      current_syncs_count: 0,
      current_ai_count: 0,
      current_indexing_count: 0
    })
    .eq('user_id', userId)

  // Store subscription items for metered billing
  const subscriptionItems = subscription.items.data
  await supabase
    .from('subscription_settings')
    .update({
      stripe_subscription_item_syncs: subscriptionItems.find((i: any) => 
        i.price.metadata?.usage_type === 'syncs'
      )?.id,
      stripe_subscription_item_ai: subscriptionItems.find((i: any) => 
        i.price.metadata?.usage_type === 'ai_enhancement'
      )?.id,
      stripe_subscription_item_indexing: subscriptionItems.find((i: any) => 
        i.price.metadata?.usage_type === 'indexing'
      )?.id
    })
    .eq('user_id', userId)

  console.log('Checkout completed for user:', userId)
}

async function handleSubscriptionUpdate(subscription: any, supabase: any) {
  const userId = subscription.metadata?.supabase_user_id

  if (!userId) {
    console.error('No user ID in subscription metadata')
    return
  }

  const tier = subscription.metadata?.tier || 'basic'
  const quotas = getQuotaLimits(tier)

  await supabase
    .from('subscription_settings')
    .update({
      tier,
      stripe_subscription_id: subscription.id,
      billing_cycle_start: new Date(subscription.current_period_start * 1000),
      billing_cycle_end: new Date(subscription.current_period_end * 1000),
      ...quotas
    })
    .eq('user_id', userId)

  console.log('Subscription updated for user:', userId)
}

async function handleSubscriptionCanceled(subscription: any, supabase: any) {
  const userId = subscription.metadata?.supabase_user_id

  if (!userId) {
    console.error('No user ID in subscription metadata')
    return
  }

  await supabase
    .from('subscription_settings')
    .update({
      tier: 'free',
      canceled_at: new Date().toISOString(),
      ...getQuotaLimits('free')
    })
    .eq('user_id', userId)

  console.log('Subscription canceled for user:', userId)
}

async function handlePaymentSucceeded(invoice: any, supabase: any) {
  const userId = invoice.subscription_object?.metadata?.supabase_user_id

  if (!userId) return

  // Reset usage counts at start of new billing period
  const { data: subscription } = await supabase
    .from('subscription_settings')
    .select('*')
    .eq('user_id', userId)
    .single()

  if (subscription) {
    await supabase
      .from('subscription_settings')
      .update({
        current_syncs_count: 0,
        current_ai_count: 0,
        current_indexing_count: 0,
        billing_cycle_start: new Date(invoice.period_start * 1000),
        billing_cycle_end: new Date(invoice.period_end * 1000)
      })
      .eq('user_id', userId)

    // Log payment
    await supabase.from('payment_history').insert({
      user_id: userId,
      stripe_invoice_id: invoice.id,
      stripe_payment_intent_id: invoice.payment_intent,
      amount: invoice.amount_paid,
      currency: invoice.currency,
      status: 'succeeded',
      description: invoice.description,
      invoice_pdf_url: invoice.invoice_pdf
    })
  }

  console.log('Payment succeeded for user:', userId)
}

async function handlePaymentFailed(invoice: any, supabase: any) {
  const userId = invoice.subscription_object?.metadata?.supabase_user_id

  if (!userId) return

  // Log failed payment
  await supabase.from('payment_history').insert({
    user_id: userId,
    stripe_invoice_id: invoice.id,
    stripe_payment_intent_id: invoice.payment_intent,
    amount: invoice.amount_due,
    currency: invoice.currency,
    status: 'failed',
    description: invoice.description
  })

  // Optionally notify user
  await supabase.from('notifications').insert({
    user_id: userId,
    type: 'error',
    title: 'Payment Failed',
    message: 'Your payment could not be processed. Please update your payment method.',
    action_url: '/billing'
  })

  console.log('Payment failed for user:', userId)
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getQuotaLimits(tier: string) {
  switch (tier) {
    case 'free':
      return {
        max_handles: 1,
        max_syncs: 10,
        max_ai_enhancements: 25,
        max_indexing_submissions: 0
      }
    case 'basic':
      return {
        max_handles: 5,
        max_syncs: 500,
        max_ai_enhancements: 500,
        max_indexing_submissions: 100
      }
    case 'premium':
      return {
        max_handles: 20,
        max_syncs: 2000,
        max_ai_enhancements: 2000,
        max_indexing_submissions: 1000
      }
    default:
      return getQuotaLimits('free')
  }
}
```

---

### **Edge Function: Report Usage to Stripe**

```typescript
// supabase/functions/report-stripe-usage/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.0.0'
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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Get all users with active subscriptions who have usage to report
    const { data: usersWithUsage } = await supabaseClient
      .from('subscription_settings')
      .select('*')
      .neq('tier', 'free')
      .not('stripe_subscription_id', 'is', null)

    for (const user of usersWithUsage || []) {
      // Report sync usage
      if (user.current_syncs_count > user.max_syncs && user.stripe_subscription_item_syncs) {
        const overageQuantity = user.current_syncs_count - user.max_syncs
        
        await stripe.subscriptionItems.createUsageRecord(
          user.stripe_subscription_item_syncs,
          {
            quantity: Math.ceil(overageQuantity / 10), // Bill in increments of 10
            timestamp: Math.floor(Date.now() / 1000),
            action: 'increment'
          }
        )

        // Log usage record
        await supabaseClient.from('stripe_usage_records').insert({
          user_id: user.user_id,
          stripe_subscription_item_id: user.stripe_subscription_item_syncs,
          usage_type: 'sync',
          quantity: Math.ceil(overageQuantity / 10),
          submitted_at: new Date().toISOString()
        })
      }

      // Report AI enhancement usage
      if (user.current_ai_count > user.max_ai_enhancements && user.stripe_subscription_item_ai) {
        const overageQuantity = user.current_ai_count - user.max_ai_enhancements
        
        await stripe.subscriptionItems.createUsageRecord(
          user.stripe_subscription_item_ai,
          {
            quantity: overageQuantity,
            timestamp: Math.floor(Date.now() / 1000),
            action: 'increment'
          }
        )

        await supabaseClient.from('stripe_usage_records').insert({
          user_id: user.user_id,
          stripe_subscription_item_id: user.stripe_subscription_item_ai,
          usage_type: 'ai_enhancement',
          quantity: overageQuantity,
          submitted_at: new Date().toISOString()
        })
      }

      // Report indexing usage
      if (user.current_indexing_count > user.max_indexing_submissions && user.stripe_subscription_item_indexing) {
        const overageQuantity = user.current_indexing_count - user.max_indexing_submissions
        
        await stripe.subscriptionItems.createUsageRecord(
          user.stripe_subscription_item_indexing,
          {
            quantity: overageQuantity,
            timestamp: Math.floor(Date.now() / 1000),
            action: 'increment'
          }
        )

        await supabaseClient.from('stripe_usage_records').insert({
          user_id: user.user_id,
          stripe_subscription_item_id: user.stripe_subscription_item_indexing,
          usage_type: 'indexing',
          quantity: overageQuantity,
          submitted_at: new Date().toISOString()
        })
      }
    }

    return new Response(
      JSON.stringify({ success: true, processed: usersWithUsage?.length || 0 }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Usage reporting error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

**Schedule this function to run hourly:**
```sql
-- In Supabase SQL Editor
SELECT cron.schedule(
  'report-stripe-usage',
  '0 * * * *', -- Every hour
  $$
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/report-stripe-usage',
    headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
  )
  $$
);
```

---

### **Frontend: Pricing Page with Checkout**

```typescript
// src/components/pricing/PricingPage.tsx
import { useState } from 'react'
import { createClient } from '@supabase/supabase-js'
import { loadStripe } from '@stripe/stripe-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)

export default function PricingPage() {
  const [loading, setLoading] = useState<string | null>(null)

  async function handleSubscribe(priceId: string, tier: string) {
    setLoading(tier)

    try {
      // Create checkout session
      const { data, error } = await supabase.functions.invoke('create-checkout-session', {
        body: { priceId, tier }
      })

      if (error) throw error

      // Redirect to Stripe Checkout
      const stripe = await stripePromise
      await stripe?.redirectToCheckout({ sessionId: data.sessionId })

    } catch (error) {
      console.error('Checkout error:', error)
      alert('Failed to start checkout. Please try again.')
    } finally {
      setLoading(null)
    }
  }

  return (
    <div className="pricing-container">
      <h1>Choose Your Plan</h1>

      <div className="pricing-grid">
        {/* Free Tier */}
        <div className="pricing-card">
          <h2>Free</h2>
          <div className="price">$0<span>/month</span></div>
          <ul className="features">
            <li>✓ 1 Social Account</li>
            <li>✓ 10 Syncs/month</li>
            <li>✓ 25 AI Enhancements/month</li>
            <li>✗ SEO Indexing</li>
          </ul>
          <button className="btn-secondary">Current Plan</button>
        </div>

        {/* Basic Tier */}
        <div className="pricing-card featured">
          <div className="badge">POPULAR</div>
          <h2>Basic</h2>
          <div className="price">$19<span>/month</span></div>
          <ul className="features">
            <li>✓ 5 Social Accounts</li>
            <li>✓ 500 Syncs/month</li>
            <li>✓ 500 AI Enhancements/month</li>
            <li>✓ 100 SEO Submissions/month</li>
            <li>✓ Priority Support</li>
          </ul>
          <button
            className="btn-primary"
            onClick={() => handleSubscribe('price_basic_monthly', 'basic')}
            disabled={loading === 'basic'}
          >
            {loading === 'basic' ? 'Loading...' : 'Subscribe'}
          </button>
        </div>

        {/* Premium Tier */}
        <div className="pricing-card">
          <h2>Premium</h2>
          <div className="price">$49<span>/month</span></div>
          <ul className="features">
            <li>✓ 20 Social Accounts</li>
            <li>✓ 2,000 Syncs/month</li>
            <li>✓ 2,000 AI Enhancements/month</li>
            <li>✓ 1,000 SEO Submissions/month</li>
            <li>✓ Advanced Analytics</li>
            <li>✓ API Access</li>
          </ul>
          <button
            className="btn-primary"
            onClick={() => handleSubscribe('price_premium_monthly', 'premium')}
            disabled={loading === 'premium'}
          >
            {loading === 'premium' ? 'Loading...' : 'Subscribe'}
          </button>
        </div>
      </div>

      <div className="usage-based-notice">
        <p>💡 <strong>Usage-Based Billing:</strong> If you exceed your quota:</p>
        <ul>
          <li>Extra syncs: $0.10 per 10 syncs</li>
          <li>Extra AI enhancements: $0.05 each</li>
          <li>Extra SEO submissions: $0.20 each</li>
        </ul>
      </div>
    </div>
  )
}
```

---

### **Frontend: Usage Dashboard**

```typescript
// src/components/dashboard/UsageWidget.tsx
import { useEffect, useState } from 'react'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export default function UsageWidget() {
  const [usage, setUsage] = useState<any>(null)

  useEffect(() => {
    loadUsage()
  }, [])

  async function loadUsage() {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const { data } = await supabase
      .from('subscription_settings')
      .select('*')
      .eq('user_id', user.id)
      .single()

    setUsage(data)
  }

  if (!usage) return <div>Loading...</div>

  const syncPercent = (usage.current_syncs_count / usage.max_syncs) * 100
  const aiPercent = (usage.current_ai_count / usage.max_ai_enhancements) * 100
  const indexPercent = (usage.current_indexing_count / usage.max_indexing_submissions) * 100

  return (
    <div className="usage-widget">
      <h3>Your Usage This Month</h3>

      <div className="usage-item">
        <div className="usage-header">
          <span>Content Syncs</span>
          <span>{usage.current_syncs_count} / {usage.max_syncs}</span>
        </div>
        <div className="progress-bar">
          <div className="progress" style={{ width: `${syncPercent}%` }} />
        </div>
        {usage.current_syncs_count > usage.max_syncs && (
          <p className="overage">
            ⚠️ Over quota by {usage.current_syncs_count - usage.max_syncs} syncs
          </p>
        )}
      </div>

      <div className="usage-item">
        <div className="usage-header">
          <span>AI Enhancements</span>
          <span>{usage.current_ai_count} / {usage.max_ai_enhancements}</span>
        </div>
        <div className="progress-bar">
          <div className="progress" style={{ width: `${aiPercent}%` }} />
        </div>
      </div>

      <div className="usage-item">
        <div className="usage-header">
          <span>SEO Submissions</span>
          <span>{usage.current_indexing_count} / {usage.max_indexing_submissions}</span>
        </div>
        <div className="progress-bar">
          <div className="progress" style={{ width: `${indexPercent}%` }} />
        </div>
      </div>

      <div className="billing-info">
        <p>
          Current Plan: <strong>{usage.tier.toUpperCase()}</strong>
        </p>
        <p>
          Resets: {new Date(usage.billing_cycle_end).toLocaleDateString()}
        </p>
        <button className="btn-link" onClick={() => window.location.href = '/billing'}>
          Manage Billing →
        </button>
      </div>
    </div>
  )
}
```

---

## 🔄 Usage Tracking Integration

### **Update Existing Functions to Track Usage**

```typescript
// In sync-platform-content Edge Function
// After successful sync, increment quota:

const { data: settings } = await supabaseClient
  .from('subscription_settings')
  .select('*')
  .eq('user_id', userId)
  .single()

// Check if user has quota
if (settings.current_syncs_count >= settings.max_syncs) {
  // Allow overage but will be billed
  console.log('User exceeding sync quota - will be charged')
}

// Increment usage
await supabaseClient.rpc('increment_quota', {
  _user_id: userId,
  _quota_type: 'syncs'
})

// Log to usage history
await supabaseClient.from('quota_usage_history').insert({
  user_id: userId,
  quota_type: 'syncs',
  amount: 1,
  action: 'sync_content',
  resource_id: handleId
})
```

---

## 📊 Complete Flow Summary

```
┌─────────────────────────────────────────────────────────────┐
│              STRIPE BILLING FLOW                            │
└─────────────────────────────────────────────────────────────┘

1. USER SUBSCRIBES
   User → Pricing Page → Checkout → Stripe Payment → Success
   
2. STRIPE WEBHOOK
   Stripe → checkout.session.completed → Update subscription_settings
   
3. USER PERFORMS ACTION
   Sync Content → Check quota → Increment usage → Log history
   
4. USAGE REPORTING (Hourly)
   Cron Job → Calculate overage → Report to Stripe via API
   
5. STRIPE GENERATES INVOICE
   End of billing period → Invoice created → Usage charges included
   
6. PAYMENT PROCESSED
   Stripe → invoice.payment_succeeded → Reset usage counters
```

---

## 🎯 Key Features

✅ **Subscription Management** - Stripe handles all payment processing  
✅ **Usage-Based Billing** - Metered billing for overages  
✅ **Webhook Integration** - Real-time updates from Stripe  
✅ **Idempotent Processing** - Prevents duplicate webhook handling  
✅ **Customer Portal** - Self-service billing management  
✅ **Usage Tracking** - Detailed history of all quota consumption  
✅ **Automated Reporting** - Hourly sync of usage to Stripe  
✅ **Payment History** - Complete audit trail  

This implementation seamlessly integrates Stripe with your existing quota system! 🚀
