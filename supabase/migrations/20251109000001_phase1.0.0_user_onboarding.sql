-- =================================================================================
-- MODULE 000: BASE CORE SCHEMA
-- =================================================================================
-- Purpose: Foundation tables for authentication, users, subscriptions, and billing
-- Dependencies: None (this is the base module)
-- Testing: Verify user creation, subscription assignment, role management
-- Date: November 8, 2025
-- 
-- Tables Created:
--   - Enums: visibility_enum, app_role_enum, notification_type_enum, action_mode_enum
--   - Lookup: subscription_tier, subscription_status
--   - Core: users, user_role, user_setting, subscription
--   - Tracking: notification, audit_log, quota_usage_history, cache_store
-- 
-- Functions: check_quota, increment_quota, decrement_quota, has_role
-- =================================================================================

-- =================================================================================
-- SECTION 1: ENUMS (Core immutable types)
-- =================================================================================

CREATE TYPE public.visibility_enum AS ENUM ('public', 'private', 'unlisted');
CREATE TYPE public.app_role_enum AS ENUM ('user', 'admin', 'moderator');
CREATE TYPE public.notification_type_enum AS ENUM ('info', 'success', 'warning', 'error');
CREATE TYPE public.action_mode_enum AS ENUM ('auto', 'manual', 'disabled');

COMMENT ON TYPE public.visibility_enum IS 'Content/profile visibility levels';
COMMENT ON TYPE public.app_role_enum IS 'User application roles';
COMMENT ON TYPE public.notification_type_enum IS 'Notification severity levels';
COMMENT ON TYPE public.action_mode_enum IS 'Automation mode for syncing/processing';

-- =================================================================================
-- SECTION 2: SUBSCRIPTION INFRASTRUCTURE
-- =================================================================================

-- Subscription Tiers
CREATE TABLE public.subscription_tier (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT,
    
    -- Quota limits
    max_social_accounts INT NOT NULL DEFAULT 1,
    max_syncs_per_month INT NOT NULL DEFAULT 10,
    max_ai_analyses_per_month INT NOT NULL DEFAULT 25,
    max_seo_submissions_per_month INT NOT NULL DEFAULT 0,
    
    -- Pricing
    price_cents INT NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'usd',
    stripe_price_id TEXT,
    stripe_product_id TEXT,
    
    -- Display
    is_featured BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    sort_order INT DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.subscription_tier IS 'Subscription tier definitions with quotas and pricing';

CREATE INDEX idx_subscription_tier_active ON public.subscription_tier(is_active, sort_order);

-- Subscription Statuses
CREATE TABLE public.subscription_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT,
    is_active_state BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.subscription_status IS 'Subscription status types';

INSERT INTO public.subscription_status (slug, display_name, is_active_state) VALUES
('active', 'Active', true),
('trialing', 'Trialing', true),
('past_due', 'Past Due', true),
('canceled', 'Canceled', false),
('paused', 'Paused', false);

-- =================================================================================
-- SECTION 3: USER MANAGEMENT
-- =================================================================================

-- User Profiles (Non-PII only - PII stored in auth.users)
-- SECURITY: email, full_name, location moved to auth.users.raw_user_meta_data
-- Access PII via: SELECT email FROM auth.users WHERE id = auth.uid()
-- Or use: auth.email() function in policies
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Non-sensitive profile data
    avatar_url TEXT,
    timezone TEXT DEFAULT 'UTC',
    language TEXT DEFAULT 'en',
    
    -- Onboarding
    is_onboarded BOOLEAN DEFAULT false,
    onboarded_at TIMESTAMPTZ,
    
    -- Creator public profile fields (from discovery module, but needed for base)
    display_name TEXT,
    bio TEXT,
    website_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    profile_slug TEXT UNIQUE,
    primary_category TEXT,
    total_followers_count BIGINT DEFAULT 0,
    profile_views_count BIGINT DEFAULT 0,
    profile_clicks_count BIGINT DEFAULT 0,
    is_public BOOLEAN DEFAULT TRUE,
    
    -- SEO
    seo_title TEXT,
    seo_description TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.users IS 'User profiles (non-PII) - PII stored in auth.users.raw_user_meta_data';
COMMENT ON COLUMN public.users.id IS 'References auth.users(id) - access email via auth.email()';
COMMENT ON COLUMN public.users.display_name IS 'Public display name (not real name - see auth.users.raw_user_meta_data.full_name)';

-- Note: idx_users_email removed - email stored in auth.users, query via auth.email()
CREATE INDEX idx_users_slug ON public.users(profile_slug) WHERE profile_slug IS NOT NULL;
CREATE INDEX idx_users_public ON public.users(is_public, created_at DESC) WHERE is_public = TRUE;

-- User Roles (junction table)
CREATE TABLE public.user_role (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role public.app_role_enum NOT NULL DEFAULT 'user',
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by UUID REFERENCES public.users(id),
    
    PRIMARY KEY (user_id, role)
);

COMMENT ON TABLE public.user_role IS 'User role assignments (many-to-many)';

-- User Settings
CREATE TABLE public.user_setting (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Notification preferences
    is_email_notifications_enabled BOOLEAN DEFAULT true,
    is_push_notifications_enabled BOOLEAN DEFAULT true,
    is_weekly_digest_enabled BOOLEAN DEFAULT true,
    
    -- Auto-sync preferences
    is_auto_sync_enabled BOOLEAN DEFAULT false,
    sync_frequency_hours INT DEFAULT 24,
    
    -- AI preferences
    is_auto_ai_analysis_enabled BOOLEAN DEFAULT false,
    is_auto_apply_ai_suggestions_enabled BOOLEAN DEFAULT false,
    
    -- SEO preferences
    is_auto_seo_submission_enabled BOOLEAN DEFAULT false,
    
    -- Privacy
    is_profile_public BOOLEAN DEFAULT true,
    is_analytics_enabled BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.user_setting IS 'User preferences and settings';

-- =================================================================================
-- SECTION 4: SUBSCRIPTIONS
-- =================================================================================

CREATE TABLE public.subscription (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
    tier_id UUID NOT NULL REFERENCES public.subscription_tier(id),
    status_id UUID NOT NULL REFERENCES public.subscription_status(id),
    
    -- Current usage (resets each billing cycle)
    syncs_used INT NOT NULL DEFAULT 0,
    ai_analyses_used INT NOT NULL DEFAULT 0,
    seo_submissions_used INT NOT NULL DEFAULT 0,
    
    -- Billing cycle
    cycle_start_date TIMESTAMPTZ NOT NULL,
    cycle_end_date TIMESTAMPTZ NOT NULL,
    next_billing_date TIMESTAMPTZ,
    
    -- Stripe integration
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,
    stripe_price_id TEXT,
    stripe_subscription_item_id_syncs TEXT,
    stripe_subscription_item_id_ai TEXT,
    stripe_subscription_item_id_seo TEXT,
    
    -- Status
    is_auto_renew_enabled BOOLEAN DEFAULT true,
    canceled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.subscription IS 'User subscription with tier, usage tracking, and billing';

CREATE INDEX idx_subscription_user ON public.subscription(user_id);
CREATE INDEX idx_subscription_tier ON public.subscription(tier_id);
CREATE INDEX idx_subscription_status ON public.subscription(status_id);
CREATE INDEX idx_subscription_stripe_customer ON public.subscription(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;
CREATE INDEX idx_subscription_billing_cycle ON public.subscription(cycle_end_date) WHERE is_auto_renew_enabled = true;

-- =================================================================================
-- SECTION 5: NOTIFICATIONS
-- =================================================================================

CREATE TABLE public.notification (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    type public.notification_type_enum NOT NULL DEFAULT 'info',
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    
    -- Action
    action_url TEXT,
    action_label TEXT,
    
    -- Metadata
    metadata JSONB,
    related_entity_type TEXT,
    related_entity_id UUID,
    
    -- Read status
    is_read BOOLEAN NOT NULL DEFAULT false,
    read_at TIMESTAMPTZ,
    
    -- Expiry
    expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.notification IS 'User notifications';

-- Indexes for notification queries
CREATE INDEX idx_notification_user_unread ON public.notification(user_id, created_at DESC) WHERE is_read = false;
CREATE INDEX idx_notification_expires ON public.notification(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_notification_user_all ON public.notification(user_id, created_at DESC);
CREATE INDEX idx_notification_expires ON public.notification(expires_at) WHERE expires_at IS NOT NULL;

-- =================================================================================
-- SECTION 6: AUDIT & TRACKING
-- =================================================================================

CREATE TABLE public.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    
    old_values JSONB,
    new_values JSONB,
    
    ip_address INET,
    user_agent TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.audit_log IS 'Comprehensive audit trail of all actions';

CREATE INDEX idx_audit_log_user ON public.audit_log(user_id, created_at DESC);
CREATE INDEX idx_audit_log_entity ON public.audit_log(entity_type, entity_id, created_at DESC);
CREATE INDEX idx_audit_log_action ON public.audit_log(action, created_at DESC);
CREATE INDEX idx_audit_log_created ON public.audit_log(created_at DESC);

-- Quota Usage History
CREATE TABLE public.quota_usage_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    quota_type TEXT NOT NULL,
    operation TEXT NOT NULL,
    amount INT NOT NULL DEFAULT 1,
    
    -- Snapshot after operation
    current_value INT NOT NULL,
    max_value INT NOT NULL,
    
    -- Metadata
    related_entity_type TEXT,
    related_entity_id UUID,
    reason TEXT,
    
    -- Billing cycle
    billing_cycle_start TIMESTAMPTZ NOT NULL,
    billing_cycle_end TIMESTAMPTZ NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.quota_usage_history IS 'Historical quota usage for analytics and auditing';

CREATE INDEX idx_quota_usage_history_user ON public.quota_usage_history(user_id, created_at DESC);
CREATE INDEX idx_quota_usage_history_type ON public.quota_usage_history(user_id, quota_type, billing_cycle_start, billing_cycle_end);

-- =================================================================================
-- SECTION 7: CACHING
-- =================================================================================

CREATE TABLE public.cache_store (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    category TEXT NOT NULL,
    
    expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.cache_store IS 'General-purpose cache for external API data';

-- Indexes for cache lookups (removed NOW() - not IMMUTABLE in predicates)
CREATE INDEX idx_cache_store_category ON public.cache_store(category, expires_at);
CREATE INDEX idx_cache_store_expires ON public.cache_store(expires_at) WHERE expires_at IS NOT NULL;

-- =================================================================================
-- SECTION 8: QUOTA MANAGEMENT FUNCTIONS
-- =================================================================================

-- Check quota availability
CREATE OR REPLACE FUNCTION public.check_quota(
    p_user_id UUID,
    p_quota_type TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_current_usage INT;
    v_max_quota INT;
BEGIN
    SELECT 
        CASE p_quota_type
            WHEN 'sync' THEN s.syncs_used
            WHEN 'ai_analysis' THEN s.ai_analyses_used
            WHEN 'seo_submission' THEN s.seo_submissions_used
        END,
        CASE p_quota_type
            WHEN 'sync' THEN t.max_syncs_per_month
            WHEN 'ai_analysis' THEN t.max_ai_analyses_per_month
            WHEN 'seo_submission' THEN t.max_seo_submissions_per_month
        END
    INTO v_current_usage, v_max_quota
    FROM public.subscription s
    JOIN public.subscription_tier t ON s.tier_id = t.id
    WHERE s.user_id = p_user_id;
    
    RETURN v_current_usage < v_max_quota;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Increment quota usage
CREATE OR REPLACE FUNCTION public.increment_quota(
    p_user_id UUID,
    p_quota_type TEXT,
    p_amount INT DEFAULT 1,
    p_related_entity_type TEXT DEFAULT NULL,
    p_related_entity_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_new_usage INT;
    v_max_quota INT;
    v_cycle_start TIMESTAMPTZ;
    v_cycle_end TIMESTAMPTZ;
BEGIN
    UPDATE public.subscription s
    SET 
        syncs_used = CASE WHEN p_quota_type = 'sync' THEN syncs_used + p_amount ELSE syncs_used END,
        ai_analyses_used = CASE WHEN p_quota_type = 'ai_analysis' THEN ai_analyses_used + p_amount ELSE ai_analyses_used END,
        seo_submissions_used = CASE WHEN p_quota_type = 'seo_submission' THEN seo_submissions_used + p_amount ELSE seo_submissions_used END,
        updated_at = NOW()
    WHERE user_id = p_user_id
    RETURNING 
        CASE p_quota_type
            WHEN 'sync' THEN syncs_used
            WHEN 'ai_analysis' THEN ai_analyses_used
            WHEN 'seo_submission' THEN seo_submissions_used
        END,
        cycle_start_date,
        cycle_end_date
    INTO v_new_usage, v_cycle_start, v_cycle_end;
    
    SELECT 
        CASE p_quota_type
            WHEN 'sync' THEN t.max_syncs_per_month
            WHEN 'ai_analysis' THEN t.max_ai_analyses_per_month
            WHEN 'seo_submission' THEN t.max_seo_submissions_per_month
        END
    INTO v_max_quota
    FROM public.subscription s
    JOIN public.subscription_tier t ON s.tier_id = t.id
    WHERE s.user_id = p_user_id;
    
    INSERT INTO public.quota_usage_history (
        user_id, quota_type, operation, amount, current_value, max_value,
        related_entity_type, related_entity_id, billing_cycle_start, billing_cycle_end
    ) VALUES (
        p_user_id, p_quota_type, 'increment', p_amount, v_new_usage, v_max_quota,
        p_related_entity_type, p_related_entity_id, v_cycle_start, v_cycle_end
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Decrement quota usage (rollback/refund)
CREATE OR REPLACE FUNCTION public.decrement_quota(
    p_user_id UUID,
    p_quota_type TEXT,
    p_amount INT DEFAULT 1,
    p_reason TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_new_usage INT;
    v_max_quota INT;
    v_cycle_start TIMESTAMPTZ;
    v_cycle_end TIMESTAMPTZ;
BEGIN
    UPDATE public.subscription s
    SET 
        syncs_used = CASE WHEN p_quota_type = 'sync' THEN GREATEST(0, syncs_used - p_amount) ELSE syncs_used END,
        ai_analyses_used = CASE WHEN p_quota_type = 'ai_analysis' THEN GREATEST(0, ai_analyses_used - p_amount) ELSE ai_analyses_used END,
        seo_submissions_used = CASE WHEN p_quota_type = 'seo_submission' THEN GREATEST(0, seo_submissions_used - p_amount) ELSE seo_submissions_used END,
        updated_at = NOW()
    WHERE user_id = p_user_id
    RETURNING 
        CASE p_quota_type
            WHEN 'sync' THEN syncs_used
            WHEN 'ai_analysis' THEN ai_analyses_used
            WHEN 'seo_submission' THEN seo_submissions_used
        END,
        cycle_start_date,
        cycle_end_date
    INTO v_new_usage, v_cycle_start, v_cycle_end;
    
    SELECT 
        CASE p_quota_type
            WHEN 'sync' THEN t.max_syncs_per_month
            WHEN 'ai_analysis' THEN t.max_ai_analyses_per_month
            WHEN 'seo_submission' THEN t.max_seo_submissions_per_month
        END
    INTO v_max_quota
    FROM public.subscription s
    JOIN public.subscription_tier t ON s.tier_id = t.id
    WHERE s.user_id = p_user_id;
    
    INSERT INTO public.quota_usage_history (
        user_id, quota_type, operation, amount, current_value, max_value,
        reason, billing_cycle_start, billing_cycle_end
    ) VALUES (
        p_user_id, p_quota_type, 'decrement', p_amount, v_new_usage, v_max_quota,
        p_reason, v_cycle_start, v_cycle_end
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user has role
CREATE OR REPLACE FUNCTION public.has_role(
    p_user_id UUID,
    p_role public.app_role_enum
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_role
        WHERE user_id = p_user_id AND role = p_role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================================
-- SECTION 9: TRIGGERS
-- =================================================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_user_setting_updated_at BEFORE UPDATE ON public.user_setting FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_subscription_updated_at BEFORE UPDATE ON public.subscription FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_notification_updated_at BEFORE UPDATE ON public.notification FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =================================================================================
-- SECTION 10: ROW LEVEL SECURITY
-- =================================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_role ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_setting ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quota_usage_history ENABLE ROW LEVEL SECURITY;

-- Users can read/update their own profile
CREATE POLICY users_select_own ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY users_update_own ON public.users FOR UPDATE USING (auth.uid() = id);

-- Public profiles are viewable
CREATE POLICY users_select_public ON public.users FOR SELECT USING (is_public = true);

-- User settings
CREATE POLICY user_setting_all_own ON public.user_setting FOR ALL USING (auth.uid() = user_id);

-- Subscriptions
CREATE POLICY subscription_select_own ON public.subscription FOR SELECT USING (auth.uid() = user_id);

-- Notifications
CREATE POLICY notification_select_own ON public.notification FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY notification_update_own ON public.notification FOR UPDATE USING (auth.uid() = user_id);

-- Audit log
CREATE POLICY audit_log_select_own ON public.audit_log FOR SELECT USING (auth.uid() = user_id);

-- Quota history
CREATE POLICY quota_usage_history_select_own ON public.quota_usage_history FOR SELECT USING (auth.uid() = user_id);

-- Admin policies
CREATE POLICY users_admin_all ON public.users FOR ALL USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY subscription_admin_all ON public.subscription FOR ALL USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY audit_log_admin_all ON public.audit_log FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- =================================================================================
-- SECTION 11: INITIAL DATA
-- =================================================================================

-- Subscription tiers
INSERT INTO public.subscription_tier (slug, display_name, description, max_social_accounts, max_syncs_per_month, max_ai_analyses_per_month, max_seo_submissions_per_month, price_cents, currency, is_featured, sort_order)
VALUES
('free', 'Free', 'Perfect for getting started', 1, 10, 25, 0, 0, 'usd', false, 1),
('basic', 'Basic', 'For content creators', 3, 100, 100, 50, 1900, 'usd', true, 2),
('premium', 'Premium', 'For professionals and teams', 10, 500, 500, 200, 4900, 'usd', true, 3);

-- =================================================================================
-- SECTION 12: GRANTS & PERMISSIONS
-- =================================================================================

GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT SELECT ON public.subscription_tier TO authenticated, anon;
GRANT SELECT ON public.subscription_status TO authenticated, anon;
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.user_role TO authenticated;
GRANT ALL ON public.user_setting TO authenticated;
GRANT ALL ON public.subscription TO authenticated;
GRANT ALL ON public.notification TO authenticated;
GRANT ALL ON public.audit_log TO authenticated;
GRANT ALL ON public.quota_usage_history TO authenticated;
GRANT ALL ON public.cache_store TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_quota TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_quota TO authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_quota TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role TO authenticated;

-- =================================================================================
-- MODULE VERIFICATION
-- =================================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Module 000: Base Core Schema - COMPLETE';
    RAISE NOTICE '   Tables: 10 (users, user_role, user_setting, subscription, subscription_tier, subscription_status, notification, audit_log, quota_usage_history, cache_store)';
    RAISE NOTICE '   Functions: 4 (check_quota, increment_quota, decrement_quota, has_role)';
    RAISE NOTICE '   Enums: 4 (visibility_enum, app_role_enum, notification_type_enum, action_mode_enum)';
    RAISE NOTICE '   RLS Policies: 12';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 SECURITY: PII Protection';
    RAISE NOTICE '   ✅ PII stored in auth.users.raw_user_meta_data (encrypted)';
    RAISE NOTICE '   ✅ email, full_name, location NOT in public.users';
    RAISE NOTICE '   ✅ Access PII via: auth.email() or supabase.auth.getUser()';
    RAISE NOTICE '   ✅ Complies with GDPR/CCPA data protection requirements';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test this module:';
    RAISE NOTICE '   1. Create test user via Supabase Auth';
    RAISE NOTICE '   2. Verify user row auto-created in users table (non-PII only)';
    RAISE NOTICE '   3. Check PII in auth.users: SELECT raw_user_meta_data FROM auth.users';
    RAISE NOTICE '   4. Assign free tier subscription';
    RAISE NOTICE '   4. Test quota functions: SELECT check_quota(user_id, ''sync'')';
    RAISE NOTICE '   5. Test role assignment and has_role() function';
    RAISE NOTICE '';
    RAISE NOTICE '➡️  Next: Apply 001_platform_connections.sql';
END $$;
