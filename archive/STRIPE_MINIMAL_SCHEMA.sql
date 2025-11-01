-- =================================================================================
-- STRIPE INTEGRATION - MINIMAL TABLES
-- =================================================================================
-- Only store what's necessary for app functionality
-- Stripe manages: products, prices, subscriptions, customers, invoices
-- We store: webhook idempotency, usage tracking, subscription references
-- We cache: products, prices (using generic cache_store table)
-- =================================================================================

-- Generic Cache Store (for Stripe API responses and other external APIs)
CREATE TABLE public.cache_store (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.cache_store IS 'Generic key-value cache for external API responses (Stripe products, prices, etc)';

CREATE INDEX idx_cache_store_expires ON public.cache_store(expires_at);

-- Auto-delete expired cache entries
CREATE OR REPLACE FUNCTION delete_expired_cache()
RETURNS void AS $$
BEGIN
    DELETE FROM public.cache_store
    WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup every hour (requires pg_cron extension)
-- Uncomment after enabling pg_cron:
-- SELECT cron.schedule(
--   'cleanup-expired-cache',
--   '0 * * * *',
--   $$ SELECT delete_expired_cache(); $$
-- );

-- Stripe Webhook Events (REQUIRED for idempotency)
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

COMMENT ON TABLE public.stripe_webhook_events IS 'Webhook event log for idempotency - prevents duplicate processing';

CREATE INDEX idx_stripe_webhook_type ON public.stripe_webhook_events(event_type);
CREATE INDEX idx_stripe_webhook_processed ON public.stripe_webhook_events(processed, created_at);
CREATE INDEX idx_stripe_webhook_unprocessed ON public.stripe_webhook_events(processed, retry_count) WHERE processed = false;

-- Stripe Usage Records (REQUIRED for metered billing tracking)
CREATE TABLE public.stripe_usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    stripe_subscription_item_id TEXT NOT NULL,
    usage_type TEXT NOT NULL, -- 'sync', 'ai_enhancement', 'indexing'
    quantity INT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    stripe_usage_record_id TEXT, -- Returned by Stripe after submission
    submitted_at TIMESTAMPTZ,
    billing_cycle_start TIMESTAMPTZ NOT NULL,
    billing_cycle_end TIMESTAMPTZ NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.stripe_usage_records IS 'Tracks metered usage reported to Stripe for billing reconciliation';

CREATE INDEX idx_stripe_usage_user_type ON public.stripe_usage_records(user_id, usage_type);
CREATE INDEX idx_stripe_usage_submitted ON public.stripe_usage_records(submitted_at) WHERE submitted_at IS NOT NULL;
CREATE INDEX idx_stripe_usage_billing_cycle ON public.stripe_usage_records(user_id, billing_cycle_start, billing_cycle_end);

-- Payment History (OPTIONAL - can query Stripe API instead)
-- Keep this if you want fast dashboard access without API calls
CREATE TABLE public.payment_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    stripe_invoice_id TEXT UNIQUE,
    stripe_payment_intent_id TEXT,
    amount INT NOT NULL, -- in cents
    currency TEXT NOT NULL DEFAULT 'usd',
    status TEXT NOT NULL, -- 'succeeded', 'failed', 'pending'
    description TEXT,
    invoice_pdf_url TEXT,
    period_start TIMESTAMPTZ,
    period_end TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.payment_history IS 'Cached payment history for fast dashboard access (alternative: query Stripe API)';

CREATE INDEX idx_payment_history_user ON public.payment_history(user_id, created_at DESC);
CREATE INDEX idx_payment_history_invoice ON public.payment_history(stripe_invoice_id) WHERE stripe_invoice_id IS NOT NULL;

-- =================================================================================
-- UPDATE subscription_settings (EXISTING TABLE)
-- =================================================================================
-- Add only Stripe references needed for webhooks and metered billing

ALTER TABLE public.subscription_settings
ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT,
ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT,
ADD COLUMN IF NOT EXISTS stripe_subscription_item_syncs TEXT,
ADD COLUMN IF NOT EXISTS stripe_subscription_item_ai TEXT,
ADD COLUMN IF NOT EXISTS stripe_subscription_item_indexing TEXT,
ADD COLUMN IF NOT EXISTS stripe_price_id TEXT,
ADD COLUMN IF NOT EXISTS billing_cycle_start TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS billing_cycle_end TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS canceled_at TIMESTAMPTZ;

COMMENT ON COLUMN public.subscription_settings.stripe_customer_id IS 'Stripe customer ID (from webhook)';
COMMENT ON COLUMN public.subscription_settings.stripe_subscription_id IS 'Stripe subscription ID (from webhook)';
COMMENT ON COLUMN public.subscription_settings.stripe_subscription_item_syncs IS 'Subscription item ID for metered sync billing';
COMMENT ON COLUMN public.subscription_settings.stripe_subscription_item_ai IS 'Subscription item ID for metered AI billing';
COMMENT ON COLUMN public.subscription_settings.stripe_subscription_item_indexing IS 'Subscription item ID for metered indexing billing';
COMMENT ON COLUMN public.subscription_settings.stripe_price_id IS 'Current Stripe price ID';

CREATE INDEX IF NOT EXISTS idx_subscription_settings_stripe_customer 
ON public.subscription_settings(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_subscription_settings_stripe_subscription 
ON public.subscription_settings(stripe_subscription_id) WHERE stripe_subscription_id IS NOT NULL;

-- =================================================================================
-- SUMMARY
-- =================================================================================
-- What Stripe Manages:
--   ✓ Products (Free, Basic, Premium)
--   ✓ Prices ($0, $19, $49)
--   ✓ Customers
--   ✓ Subscriptions
--   ✓ Invoices
--   ✓ Payment Methods
--   ✓ Payment Intents
--
-- What We Store:
--   ✓ Webhook events (idempotency)
--   ✓ Usage records (billing reconciliation)
--   ✓ Payment history (optional - for UX)
--   ✓ Subscription references (in subscription_settings)
--
-- Why This is Minimal:
--   - No duplication of Stripe data
--   - Query Stripe API when needed
--   - Only cache what's critical for performance/UX
-- =================================================================================
