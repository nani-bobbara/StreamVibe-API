-- =================================================================================
-- STREAMVIBE - IMPROVED SCHEMA V2
-- =================================================================================
-- Purpose: Production-ready schema with performance and security improvements
-- Generated: October 31, 2025
-- Changes from v1:
--   1. Removed job_queue table → Use Supabase Edge Functions + pg_net
--   2. Renamed video_content → handle_content with RESTRICT on handle_id
--   3. Added platform_credentials for secure API token storage
--   4. Added quota management functions
--   5. Added composite indexes for performance
--   6. Added content_edit_history for audit trail
--   7. Added full-text search support
--   8. Enhanced audit_log for job tracking
-- =================================================================================

-- =================================================================================
-- SECTION 1: ENUMS
-- =================================================================================

-- Core business types
CREATE TYPE public.visibility_type AS ENUM ('public', 'private', 'unlisted');
CREATE TYPE public.app_role AS ENUM ('user', 'admin');
CREATE TYPE public.subscription_tier AS ENUM ('free', 'basic', 'premium');
CREATE TYPE public.account_handle_status AS ENUM ('active', 'inactive', 'suspended');
CREATE TYPE public.subscription_status AS ENUM ('active', 'canceled', 'past_due', 'trialing');

-- Workflow types (used in audit_log for job tracking)
CREATE TYPE public.job_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'cancelled');
CREATE TYPE public.action_mode AS ENUM ('auto', 'manual', 'disabled');

-- Notification types
CREATE TYPE public.notification_type AS ENUM ('info', 'success', 'warning', 'error');
CREATE TYPE public.notification_status AS ENUM ('unread', 'read', 'archived', 'dismissed');

-- Job types enum (for audit_log tracking)
CREATE TYPE public.job_type AS ENUM (
    'platform_sync',
    'ai_enhancement',
    'seo_indexing',
    'batch_sync',
    'batch_ai',
    'batch_indexing',
    'handle_sync'
);

-- =================================================================================
-- SECTION 2: SYSTEM TABLES (Lookup/Reference Tables)
-- =================================================================================

-- Supported Job Types (kept for reference, but jobs are not queued)
CREATE TABLE public.supported_job_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.supported_job_types IS 'System table for managing job types (reference only - jobs executed via Edge Functions)';

-- Supported Platform Types
CREATE TABLE public.supported_platform_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    platform_url TEXT,
    logo_url TEXT,
    api_documentation_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    requires_oauth BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.supported_platform_types IS 'System table for managing social media platforms (e.g., YouTube, Instagram, TikTok, Facebook)';

-- Supported Content Types
CREATE TABLE public.supported_content_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.supported_content_types IS 'System table for managing content types (e.g., long_video, short_video, account_handle)';

-- =================================================================================
-- SECTION 3: USER & AUTH TABLES
-- =================================================================================

-- User Profiles
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS 'User profiles with basic information';

-- User Roles (RBAC)
CREATE TABLE public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role public.app_role NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, role)
);

COMMENT ON TABLE public.user_roles IS 'Role-based access control for users';

-- User Preferences
CREATE TABLE public.user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    
    -- Stage 1: Platform Sync Settings
    sync_mode public.action_mode NOT NULL DEFAULT 'manual',
    sync_frequency_hours INT NOT NULL DEFAULT 24,
    
    -- Stage 2: AI Enhancement Settings
    ai_mode public.action_mode NOT NULL DEFAULT 'manual',
    ai_frequency_hours INT NOT NULL DEFAULT 24,
    
    -- Stage 3: SEO Indexing Settings
    indexing_mode public.action_mode NOT NULL DEFAULT 'disabled',
    indexing_frequency_hours INT NOT NULL DEFAULT 24,
    indexing_engines TEXT[] NOT NULL DEFAULT ARRAY['google', 'bing'],
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.user_preferences IS 'User automation preferences for sync, AI, and indexing workflows';

-- Subscription Settings
CREATE TABLE public.subscription_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    tier public.subscription_tier NOT NULL DEFAULT 'free',
    
    -- Quota limits
    max_handles INT NOT NULL DEFAULT 1,
    max_syncs INT NOT NULL DEFAULT 10,
    max_ai_enhancements INT NOT NULL DEFAULT 25,
    max_indexing_submissions INT NOT NULL DEFAULT 0,
    
    -- Current usage
    current_handles_count INT NOT NULL DEFAULT 0,
    current_syncs_count INT NOT NULL DEFAULT 0,
    current_ai_count INT NOT NULL DEFAULT 0,
    current_indexing_count INT NOT NULL DEFAULT 0,
    
    -- Billing integration
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,
    billing_cycle_start DATE,
    billing_cycle_end DATE,
    auto_renew BOOLEAN DEFAULT true,
    canceled_at TIMESTAMPTZ,
    
    -- Reset schedule
    sync_frequency TEXT NOT NULL DEFAULT 'manual',
    resets_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.subscription_settings IS 'User subscription tier and quota management';

CREATE INDEX idx_subscription_settings_stripe_customer ON public.subscription_settings(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;

-- Platform Credentials (NEW - Reference to Supabase Vault Secrets)
CREATE TABLE public.platform_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES public.supported_platform_types(id),
    
    -- Supabase Vault secret references (NOT the actual tokens!)
    vault_secret_name TEXT NOT NULL, -- Reference to vault secret (e.g., 'platform_token_user123_youtube')
    token_expires_at TIMESTAMPTZ,
    
    -- OAuth scopes
    scopes TEXT[],
    
    -- Status tracking
    is_active BOOLEAN DEFAULT true,
    last_verified_at TIMESTAMPTZ,
    verification_error TEXT,
    
    -- Metadata
    platform_account_id TEXT, -- External platform's account ID
    platform_username TEXT,   -- Platform username/handle
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, platform_id)
);

COMMENT ON TABLE public.platform_credentials IS 'Reference to platform API credentials stored in Supabase Vault (secrets never stored in database)';
COMMENT ON COLUMN public.platform_credentials.vault_secret_name IS 'Supabase Vault secret name - retrieve with vault.decrypted_secrets view';

CREATE INDEX idx_platform_credentials_user ON public.platform_credentials(user_id);
CREATE INDEX idx_platform_credentials_active ON public.platform_credentials(user_id, is_active) WHERE is_active = true;
CREATE INDEX idx_platform_credentials_vault_name ON public.platform_credentials(vault_secret_name);

-- =================================================================================
-- SECTION 4: CONTENT TABLES
-- =================================================================================

-- Account Handles (Social Media Accounts)
CREATE TABLE public.account_handles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES public.supported_platform_types(id),
    
    -- Platform identity
    handle TEXT NOT NULL,
    platform_account_id TEXT, -- External platform's account ID
    name TEXT,
    description TEXT,
    
    -- Media
    avatar_url TEXT,
    banner_url TEXT,
    
    -- Settings (IMPROVED: use 'unlisted' instead of deleting)
    visibility public.visibility_type NOT NULL DEFAULT 'public',
    active_status public.account_handle_status NOT NULL DEFAULT 'active',
    
    -- Stats (cached from platform)
    subscribers_count INT NOT NULL DEFAULT 0,
    total_videos INT NOT NULL DEFAULT 0,
    total_views BIGINT NOT NULL DEFAULT 0,
    
    -- Sync tracking
    last_synced_at TIMESTAMPTZ,
    last_sync_status TEXT, -- 'success', 'failed', 'partial'
    last_sync_error TEXT,
    manual_sync_requested_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(user_id, platform_id, handle)
);

COMMENT ON TABLE public.account_handles IS 'Social media account handles - use visibility=unlisted instead of deleting';

CREATE INDEX idx_account_handles_user_platform ON public.account_handles(user_id, platform_id);
CREATE INDEX idx_account_handles_handle ON public.account_handles(handle);
CREATE INDEX idx_account_handles_platform_account ON public.account_handles(platform_id, platform_account_id) WHERE platform_account_id IS NOT NULL;
CREATE INDEX idx_account_handles_visibility ON public.account_handles(visibility) WHERE visibility IN ('public', 'unlisted');

-- Handle Content (RENAMED from video_content - More Generic)
CREATE TABLE public.handle_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- IMPROVED: ON DELETE RESTRICT prevents accidental handle deletion
    handle_id UUID NOT NULL REFERENCES public.account_handles(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES public.supported_platform_types(id),
    content_type_id UUID NOT NULL REFERENCES public.supported_content_types(id),
    
    -- Platform identity
    platform_content_id TEXT NOT NULL,
    
    -- Content details
    title TEXT NOT NULL,
    description TEXT,
    category TEXT,
    tags TEXT[],
    
    -- Video metadata
    aspect_ratio TEXT,
    orientation TEXT,
    duration_seconds INT,
    
    -- Media URLs
    thumbnail_url TEXT,
    content_url TEXT, -- Renamed from video_url for flexibility
    
    -- Settings
    visibility public.visibility_type NOT NULL DEFAULT 'public',
    published_at TIMESTAMPTZ,
    
    -- Stats
    views BIGINT NOT NULL DEFAULT 0,
    likes INT NOT NULL DEFAULT 0,
    comments INT NOT NULL DEFAULT 0,
    shares INT NOT NULL DEFAULT 0,
    
    -- Soft delete
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id),
    
    -- Full-text search (NEW)
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
        setweight(to_tsvector('english', array_to_string(tags, ' ')), 'C')
    ) STORED,
    
    -- Metadata
    metadata JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(platform_id, platform_content_id)
);

COMMENT ON TABLE public.handle_content IS 'All content (videos, posts) from account handles - handle_id has RESTRICT to prevent accidental deletion';

CREATE INDEX idx_handle_content_handle ON public.handle_content(handle_id);
CREATE INDEX idx_handle_content_user ON public.handle_content(user_id);
CREATE INDEX idx_handle_content_platform ON public.handle_content(platform_id, platform_content_id);
CREATE INDEX idx_handle_content_published ON public.handle_content(published_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_handle_content_visibility ON public.handle_content(visibility) WHERE deleted_at IS NULL;
CREATE INDEX idx_handle_content_search ON public.handle_content USING GIN(search_vector);

-- IMPROVED: Composite indexes for common query patterns
CREATE INDEX idx_handle_content_user_platform_published ON public.handle_content(user_id, platform_id, published_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_handle_content_handle_published ON public.handle_content(handle_id, published_at DESC) WHERE deleted_at IS NULL;

-- Content Edit History (NEW - Audit Trail)
CREATE TABLE public.content_edit_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES public.handle_content(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id),
    
    -- Change tracking
    field_name TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    changed_by TEXT NOT NULL DEFAULT 'user', -- 'user', 'ai', 'sync', 'system'
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.content_edit_history IS 'Audit trail for content modifications';

CREATE INDEX idx_content_edit_history_content ON public.content_edit_history(content_id, created_at DESC);
CREATE INDEX idx_content_edit_history_user ON public.content_edit_history(user_id, created_at DESC);

-- =================================================================================
-- SECTION 5: AI & SEO TABLES
-- =================================================================================

-- AI Content Suggestions
CREATE TABLE public.ai_content_suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content_id UUID NOT NULL REFERENCES public.handle_content(id) ON DELETE CASCADE,
    content_type_id UUID NOT NULL REFERENCES public.supported_content_types(id),
    
    -- Suggestions
    suggested_title TEXT,
    suggested_description TEXT,
    suggested_tags TEXT[],
    suggested_category TEXT,
    keywords TEXT[],
    
    -- Application tracking (IMPROVED)
    version INT DEFAULT 1,
    fully_applied BOOLEAN NOT NULL DEFAULT false,
    applied_at TIMESTAMPTZ,
    applied_fields TEXT[], -- Track which fields were accepted
    
    -- AI metadata
    ai_model TEXT,
    confidence_score DECIMAL(3,2),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.ai_content_suggestions IS 'AI-generated content optimization suggestions with version tracking';

CREATE INDEX idx_ai_suggestions_user ON public.ai_content_suggestions(user_id);
CREATE INDEX idx_ai_suggestions_content ON public.ai_content_suggestions(content_id);
CREATE INDEX idx_ai_suggestions_pending ON public.ai_content_suggestions(user_id, created_at DESC) WHERE fully_applied = false;
CREATE INDEX idx_ai_suggestions_content_applied ON public.ai_content_suggestions(content_id, fully_applied, created_at DESC);

-- SEO Payloads (Indexing Submissions)
CREATE TABLE public.seo_payloads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES public.handle_content(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    
    -- Batch tracking
    batch_id UUID,
    submission_item_id TEXT,
    
    -- Submission details
    payload_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    search_engine TEXT NOT NULL,
    
    -- Status tracking
    status public.job_status NOT NULL DEFAULT 'pending',
    response_data JSONB,
    error_message TEXT,
    
    -- Retry logic
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 3,
    next_retry_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.seo_payloads IS 'SEO indexing submission payloads for search engines';

CREATE INDEX idx_seo_payloads_content ON public.seo_payloads(content_id);
CREATE INDEX idx_seo_payloads_user ON public.seo_payloads(user_id);
CREATE INDEX idx_seo_payloads_status ON public.seo_payloads(status);
CREATE INDEX idx_seo_payloads_engine ON public.seo_payloads(search_engine);
CREATE INDEX idx_seo_payloads_retry ON public.seo_payloads(next_retry_at) WHERE status = 'failed' AND retry_count < max_retries;

-- =================================================================================
-- SECTION 6: NOTIFICATIONS & AUDIT
-- =================================================================================

-- Notifications
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    
    -- Notification details
    type public.notification_type NOT NULL,
    status public.notification_status NOT NULL DEFAULT 'unread',
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    action_url TEXT,
    metadata JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.notifications IS 'User notifications';

CREATE INDEX idx_notifications_user ON public.notifications(user_id);
CREATE INDEX idx_notifications_status ON public.notifications(user_id, status, created_at DESC) WHERE status = 'unread';

-- Audit Log (IMPROVED - Now handles job tracking)
CREATE TABLE public.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    
    -- Action details
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id UUID,
    
    -- Job tracking (NEW - replaces job_queue)
    job_type public.job_type,
    job_status public.job_status,
    job_payload JSONB,
    job_result JSONB,
    job_error TEXT,
    job_started_at TIMESTAMPTZ,
    job_completed_at TIMESTAMPTZ,
    job_duration_ms INT GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (job_completed_at - job_started_at)) * 1000
    ) STORED,
    
    -- Metadata
    metadata JSONB,
    
    -- Context
    ip_address TEXT,
    user_agent TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.audit_log IS 'Audit trail for compliance, security, and job execution tracking';

CREATE INDEX idx_audit_log_user ON public.audit_log(user_id, created_at DESC);
CREATE INDEX idx_audit_log_resource ON public.audit_log(resource_type, resource_id);
CREATE INDEX idx_audit_log_created ON public.audit_log(created_at DESC);
CREATE INDEX idx_audit_log_job_type ON public.audit_log(job_type, job_status) WHERE job_type IS NOT NULL;
CREATE INDEX idx_audit_log_job_status ON public.audit_log(job_status, created_at DESC) WHERE job_status IS NOT NULL;

-- Quota Usage History (NEW - Detailed tracking)
CREATE TABLE public.quota_usage_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    quota_type TEXT NOT NULL, -- 'handles', 'syncs', 'ai', 'indexing'
    amount INT NOT NULL,
    operation TEXT, -- 'increment', 'decrement', 'reset'
    billing_period DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.quota_usage_history IS 'Historical tracking of quota consumption';

CREATE INDEX idx_quota_usage_user_period ON public.quota_usage_history(user_id, billing_period, quota_type);
CREATE INDEX idx_quota_usage_created ON public.quota_usage_history(created_at DESC);

-- =================================================================================
-- SECTION 7: FUNCTIONS
-- =================================================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.update_updated_at_column IS 'Automatically updates the updated_at column on row updates';

-- Check user role function
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = _user_id AND role = _role
    )
$$;

COMMENT ON FUNCTION public.has_role IS 'Check if a user has a specific role';

GRANT EXECUTE ON FUNCTION public.has_role TO authenticated;

-- Check quota availability (NEW)
CREATE OR REPLACE FUNCTION public.check_quota(
    _user_id UUID,
    _quota_type TEXT,
    _amount INT DEFAULT 1
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_current INT;
    v_max INT;
BEGIN
    SELECT 
        CASE _quota_type
            WHEN 'handles' THEN current_handles_count
            WHEN 'syncs' THEN current_syncs_count
            WHEN 'ai' THEN current_ai_count
            WHEN 'indexing' THEN current_indexing_count
            ELSE 0
        END,
        CASE _quota_type
            WHEN 'handles' THEN max_handles
            WHEN 'syncs' THEN max_syncs
            WHEN 'ai' THEN max_ai_enhancements
            WHEN 'indexing' THEN max_indexing_submissions
            ELSE 0
        END
    INTO v_current, v_max
    FROM public.subscription_settings
    WHERE user_id = _user_id;
    
    RETURN (v_current + _amount) <= v_max;
END;
$$;

COMMENT ON FUNCTION public.check_quota IS 'Check if user has available quota for an operation';

GRANT EXECUTE ON FUNCTION public.check_quota TO authenticated;

-- Increment quota usage (NEW)
CREATE OR REPLACE FUNCTION public.increment_quota(
    _user_id UUID,
    _quota_type TEXT,
    _amount INT DEFAULT 1
)
RETURNS BOOLEAN
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_billing_period DATE;
BEGIN
    -- Get current billing period
    SELECT billing_cycle_start INTO v_billing_period
    FROM public.subscription_settings
    WHERE user_id = _user_id;
    
    -- Update quota counter
    UPDATE public.subscription_settings
    SET 
        current_handles_count = CASE WHEN _quota_type = 'handles' THEN current_handles_count + _amount ELSE current_handles_count END,
        current_syncs_count = CASE WHEN _quota_type = 'syncs' THEN current_syncs_count + _amount ELSE current_syncs_count END,
        current_ai_count = CASE WHEN _quota_type = 'ai' THEN current_ai_count + _amount ELSE current_ai_count END,
        current_indexing_count = CASE WHEN _quota_type = 'indexing' THEN current_indexing_count + _amount ELSE current_indexing_count END,
        updated_at = NOW()
    WHERE user_id = _user_id;
    
    -- Log to history
    INSERT INTO public.quota_usage_history (user_id, quota_type, amount, operation, billing_period)
    VALUES (_user_id, _quota_type, _amount, 'increment', v_billing_period);
    
    RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.increment_quota IS 'Increment quota usage and log to history';

GRANT EXECUTE ON FUNCTION public.increment_quota TO authenticated;

-- Decrement quota usage (NEW)
CREATE OR REPLACE FUNCTION public.decrement_quota(
    _user_id UUID,
    _quota_type TEXT,
    _amount INT DEFAULT 1
)
RETURNS BOOLEAN
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_billing_period DATE;
BEGIN
    SELECT billing_cycle_start INTO v_billing_period
    FROM public.subscription_settings
    WHERE user_id = _user_id;
    
    UPDATE public.subscription_settings
    SET 
        current_handles_count = CASE WHEN _quota_type = 'handles' THEN GREATEST(0, current_handles_count - _amount) ELSE current_handles_count END,
        current_syncs_count = CASE WHEN _quota_type = 'syncs' THEN GREATEST(0, current_syncs_count - _amount) ELSE current_syncs_count END,
        current_ai_count = CASE WHEN _quota_type = 'ai' THEN GREATEST(0, current_ai_count - _amount) ELSE current_ai_count END,
        current_indexing_count = CASE WHEN _quota_type = 'indexing' THEN GREATEST(0, current_indexing_count - _amount) ELSE current_indexing_count END,
        updated_at = NOW()
    WHERE user_id = _user_id;
    
    INSERT INTO public.quota_usage_history (user_id, quota_type, amount, operation, billing_period)
    VALUES (_user_id, _quota_type, _amount, 'decrement', v_billing_period);
    
    RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.decrement_quota IS 'Decrement quota usage (e.g., when deleting content)';

GRANT EXECUTE ON FUNCTION public.decrement_quota TO authenticated;

-- Handle new user signup function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    -- 1. Create profile
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', '')
    );
    
    -- 2. Assign default user role
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'user');
    
    -- 3. Create default subscription settings
    INSERT INTO public.subscription_settings (
        user_id, 
        tier,
        billing_cycle_start,
        billing_cycle_end
    )
    VALUES (
        NEW.id, 
        'free',
        CURRENT_DATE,
        CURRENT_DATE + INTERVAL '30 days'
    );
    
    -- 4. Create default user preferences
    INSERT INTO public.user_preferences (user_id)
    VALUES (NEW.id);
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user IS 'Automatically initializes profile, role, subscription, and preferences for new users';

-- Trigger on new user creation
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Prevent accidental handle deletion function (NEW)
CREATE OR REPLACE FUNCTION public.prevent_handle_deletion_with_content()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_content_count INT;
BEGIN
    -- Check if handle has content
    SELECT COUNT(*) INTO v_content_count
    FROM public.handle_content
    WHERE handle_id = OLD.id AND deleted_at IS NULL;
    
    IF v_content_count > 0 THEN
        RAISE EXCEPTION 'Cannot delete handle with % active content items. Set visibility to unlisted instead.', v_content_count;
    END IF;
    
    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.prevent_handle_deletion_with_content IS 'Prevents deletion of handles that have active content';

CREATE TRIGGER prevent_handle_deletion
    BEFORE DELETE ON public.account_handles
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_handle_deletion_with_content();

-- =================================================================================
-- SECTION 8: UPDATE TRIGGERS
-- =================================================================================

-- Profiles
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Supported tables
CREATE TRIGGER update_supported_platform_types_updated_at
    BEFORE UPDATE ON public.supported_platform_types
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_supported_content_types_updated_at
    BEFORE UPDATE ON public.supported_content_types
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_supported_job_types_updated_at
    BEFORE UPDATE ON public.supported_job_types
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- User tables
CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON public.user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_subscription_settings_updated_at
    BEFORE UPDATE ON public.subscription_settings
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_platform_credentials_updated_at
    BEFORE UPDATE ON public.platform_credentials
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Content tables
CREATE TRIGGER update_account_handles_updated_at
    BEFORE UPDATE ON public.account_handles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_handle_content_updated_at
    BEFORE UPDATE ON public.handle_content
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- AI & SEO tables
CREATE TRIGGER update_ai_content_suggestions_updated_at
    BEFORE UPDATE ON public.ai_content_suggestions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_seo_payloads_updated_at
    BEFORE UPDATE ON public.seo_payloads
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Notification tables
CREATE TRIGGER update_notifications_updated_at
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- =================================================================================
-- SECTION 9: ROW LEVEL SECURITY (RLS)
-- =================================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_handles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.handle_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_edit_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_content_suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seo_payloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quota_usage_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supported_platform_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supported_content_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supported_job_types ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

-- User roles policies
CREATE POLICY "Users can view own roles"
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- User preferences policies
CREATE POLICY "Users can view own preferences"
    ON public.user_preferences
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
    ON public.user_preferences
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- Subscription settings policies
CREATE POLICY "Users can view own subscription"
    ON public.subscription_settings
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own subscription"
    ON public.subscription_settings
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- Platform credentials policies
CREATE POLICY "Users can manage own credentials"
    ON public.platform_credentials
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id);

-- Account handles policies
CREATE POLICY "Users can manage own handles"
    ON public.account_handles
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Public handles are viewable"
    ON public.account_handles
    FOR SELECT
    TO public
    USING (visibility = 'public');

CREATE POLICY "Unlisted handles viewable by owner"
    ON public.account_handles
    FOR SELECT
    TO authenticated
    USING (visibility = 'unlisted' AND auth.uid() = user_id);

-- Handle content policies (UPDATED table name)
CREATE POLICY "Users can manage own content"
    ON public.handle_content
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Public content is viewable"
    ON public.handle_content
    FOR SELECT
    TO public
    USING (visibility = 'public' AND deleted_at IS NULL);

CREATE POLICY "Unlisted content viewable by owner"
    ON public.handle_content
    FOR SELECT
    TO authenticated
    USING (visibility = 'unlisted' AND deleted_at IS NULL AND auth.uid() = user_id);

-- Content edit history policies
CREATE POLICY "Users can view own content history"
    ON public.content_edit_history
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert content history"
    ON public.content_edit_history
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- AI suggestions policies
CREATE POLICY "Users can manage own AI suggestions"
    ON public.ai_content_suggestions
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id);

-- SEO payloads policies
CREATE POLICY "Users can manage own SEO payloads"
    ON public.seo_payloads
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id);

-- Notifications policies
CREATE POLICY "Users can manage own notifications"
    ON public.notifications
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id);

-- Audit log policies
CREATE POLICY "Users can view own audit logs"
    ON public.audit_log
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all audit logs"
    ON public.audit_log
    FOR SELECT
    TO authenticated
    USING (has_role(auth.uid(), 'admin'));

-- Quota usage history policies
CREATE POLICY "Users can view own quota history"
    ON public.quota_usage_history
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- System tables policies (read-only for authenticated users, admin can modify)
CREATE POLICY "Authenticated users can select supported_platform_types"
    ON public.supported_platform_types
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can manage supported_platform_types"
    ON public.supported_platform_types
    FOR ALL
    TO authenticated
    USING (has_role(auth.uid(), 'admin'));

CREATE POLICY "Authenticated users can select supported_content_types"
    ON public.supported_content_types
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can manage supported_content_types"
    ON public.supported_content_types
    FOR ALL
    TO authenticated
    USING (has_role(auth.uid(), 'admin'));

CREATE POLICY "Authenticated users can select supported_job_types"
    ON public.supported_job_types
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can manage supported_job_types"
    ON public.supported_job_types
    FOR ALL
    TO authenticated
    USING (has_role(auth.uid(), 'admin'));

-- =================================================================================
-- SECTION 10: INITIAL DATA (Seed Data)
-- =================================================================================

-- Seed supported platform types
INSERT INTO public.supported_platform_types (name, description, platform_url, requires_oauth) VALUES
    ('youtube', 'YouTube video platform', 'https://youtube.com', true),
    ('instagram', 'Instagram social media platform', 'https://instagram.com', true),
    ('tiktok', 'TikTok short video platform', 'https://tiktok.com', true),
    ('facebook', 'Facebook social media platform', 'https://facebook.com', true)
ON CONFLICT (name) DO NOTHING;

-- Seed supported content types
INSERT INTO public.supported_content_types (name, description) VALUES
    ('long_video', 'Long-form video content (typically >60 seconds)'),
    ('short_video', 'Short-form video content (typically ≤60 seconds)'),
    ('reel', 'Instagram Reels / Short vertical videos'),
    ('post', 'Social media post with media'),
    ('story', 'Temporary story content')
ON CONFLICT (name) DO NOTHING;

-- Seed supported job types
INSERT INTO public.supported_job_types (name, description) VALUES
    ('platform_sync', 'Sync content from social media platform'),
    ('ai_enhancement', 'Generate AI content suggestions'),
    ('seo_indexing', 'Submit content to search engines'),
    ('batch_sync', 'Batch sync multiple handles'),
    ('batch_ai', 'Batch AI enhancement for multiple content'),
    ('batch_indexing', 'Batch SEO indexing submission'),
    ('handle_sync', 'Sync specific account handle')
ON CONFLICT (name) DO NOTHING;

-- =================================================================================
-- END OF IMPROVED SCHEMA V2
-- =================================================================================

-- MIGRATION NOTES:
-- ================
-- 1. JOB QUEUE REMOVED: Use Supabase Edge Functions with pg_net for async operations
--    - Jobs are tracked in audit_log with job_type, job_status, job_payload, job_result
--    - No persistent queue → Better performance, jobs execute and vanish
--    - Example: Call Edge Function → It logs to audit_log → Returns immediately
--
-- 2. VIDEO_CONTENT → HANDLE_CONTENT:
--    - Table renamed for better semantics
--    - handle_id now has ON DELETE RESTRICT (prevents accidental deletion)
--    - Use visibility='unlisted' instead of deleting account_handles
--    - All indexes and policies updated
--
-- 3. NEW FEATURES:
--    - platform_credentials: Secure OAuth token storage
--    - content_edit_history: Track all content changes
--    - quota_usage_history: Detailed quota consumption logs
--    - Full-text search: search_vector column in handle_content
--    - Quota functions: check_quota(), increment_quota(), decrement_quota()
--    - Handle deletion protection: Trigger prevents deletion if content exists
--
-- 4. PERFORMANCE IMPROVEMENTS:
--    - Composite indexes for common query patterns
--    - GIN index for full-text search
--    - Materialized view support (add as needed)
--
-- 5. EDGE FUNCTION USAGE PATTERN:
--    ```typescript
--    // Edge Function example
--    const { data, error } = await supabase.functions.invoke('sync-platform', {
--      body: { handleId: 'uuid', userId: 'uuid' }
--    })
--    
--    // Function logs to audit_log:
--    INSERT INTO audit_log (
--      user_id, action, resource_type, resource_id,
--      job_type, job_status, job_payload, job_result, job_started_at, job_completed_at
--    ) VALUES (...)
--    ```
--
-- 6. USAGE INSTRUCTIONS:
--    - Create new Supabase project
--    - Run this script in SQL Editor
--    - Configure Supabase Vault for encrypted tokens
--    - Set up Edge Functions for async operations
--    - Enable Realtime for job status updates (via audit_log)
