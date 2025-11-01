-- =================================================================================
-- STREAMVIBE - COMPLETE SCHEMA EXPORT
-- =================================================================================
-- Purpose: Complete schema for creating a new Supabase instance
-- Generated: October 31, 2025
-- Description: This script includes all enums, tables, indexes, triggers, 
--              functions, and RLS policies needed for a fresh Supabase instance
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

-- Workflow types
CREATE TYPE public.workflow_status AS ENUM ('idle', 'pending', 'processing', 'completed', 'failed', 'cancelled');
CREATE TYPE public.action_mode AS ENUM ('auto', 'manual', 'disabled');

-- Notification types
CREATE TYPE public.notification_type AS ENUM ('info', 'success', 'warning', 'error');
CREATE TYPE public.notification_status AS ENUM ('unread', 'read', 'archived', 'dismissed');

-- =================================================================================
-- SECTION 2: SYSTEM TABLES (Lookup/Reference Tables)
-- =================================================================================

-- Supported Job Types
CREATE TABLE public.supported_job_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.supported_job_types IS 'System table for managing job types (e.g., platform_sync, ai_enhancement, seo_indexing)';

-- Supported Platform Types
CREATE TABLE public.supported_platform_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    platform_url TEXT,
    logo_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
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
    
    -- Reset schedule
    sync_frequency TEXT NOT NULL DEFAULT 'manual',
    resets_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.subscription_settings IS 'User subscription tier and quota management';

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
    name TEXT,
    description TEXT,
    
    -- Media
    avatar_url TEXT,
    banner_url TEXT,
    
    -- Settings
    visibility public.visibility_type NOT NULL DEFAULT 'public',
    active_status public.account_handle_status NOT NULL DEFAULT 'active',
    
    -- Stats (cached from platform)
    subscribers_count INT NOT NULL DEFAULT 0,
    total_videos INT NOT NULL DEFAULT 0,
    total_views BIGINT NOT NULL DEFAULT 0,
    
    -- Sync tracking
    last_synced_at TIMESTAMPTZ,
    manual_sync_requested_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(user_id, platform_id, handle)
);

COMMENT ON TABLE public.account_handles IS 'Social media account handles managed by users';

CREATE INDEX idx_account_handles_user_platform ON public.account_handles(user_id, platform_id);
CREATE INDEX idx_account_handles_handle ON public.account_handles(handle);

-- Video Content (Long & Short Videos)
CREATE TABLE public.video_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    handle_id UUID NOT NULL REFERENCES public.account_handles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES public.supported_platform_types(id),
    content_type_id UUID NOT NULL REFERENCES public.supported_content_types(id),
    
    -- Platform identity
    platform_video_id TEXT NOT NULL,
    
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
    video_url TEXT,
    
    -- Settings
    visibility public.visibility_type NOT NULL DEFAULT 'public',
    published_at TIMESTAMPTZ,
    
    -- Stats
    views BIGINT NOT NULL DEFAULT 0,
    likes INT NOT NULL DEFAULT 0,
    comments INT NOT NULL DEFAULT 0,
    
    -- Soft delete
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id),
    
    -- Metadata
    metadata JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(platform_id, platform_video_id)
);

COMMENT ON TABLE public.video_content IS 'Unified table for all video content (long and short videos)';

CREATE INDEX idx_video_content_handle ON public.video_content(handle_id);
CREATE INDEX idx_video_content_user ON public.video_content(user_id);
CREATE INDEX idx_video_content_platform ON public.video_content(platform_id, platform_video_id);
CREATE INDEX idx_video_content_published ON public.video_content(published_at DESC);
CREATE INDEX idx_video_content_visibility ON public.video_content(visibility) WHERE deleted_at IS NULL;

-- =================================================================================
-- SECTION 5: AI & SEO TABLES
-- =================================================================================

-- AI Content Suggestions
CREATE TABLE public.ai_content_suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content_id UUID NOT NULL REFERENCES public.video_content(id) ON DELETE CASCADE,
    content_type_id UUID NOT NULL REFERENCES public.supported_content_types(id),
    
    -- Suggestions
    suggested_title TEXT,
    suggested_description TEXT,
    suggested_tags TEXT[],
    suggested_category TEXT,
    keywords TEXT[],
    
    -- Application tracking
    fully_applied BOOLEAN NOT NULL DEFAULT false,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.ai_content_suggestions IS 'AI-generated content optimization suggestions';

CREATE INDEX idx_ai_suggestions_user ON public.ai_content_suggestions(user_id);
CREATE INDEX idx_ai_suggestions_content ON public.ai_content_suggestions(content_id);
CREATE INDEX idx_ai_suggestions_pending ON public.ai_content_suggestions(user_id) WHERE fully_applied = false;

-- SEO Payloads (Indexing Submissions)
CREATE TABLE public.seo_payloads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id UUID NOT NULL REFERENCES public.video_content(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    
    -- Batch tracking
    batch_id UUID,
    submission_item_id TEXT,
    
    -- Submission details
    payload_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    search_engine TEXT NOT NULL,
    
    -- Status tracking
    status public.workflow_status NOT NULL DEFAULT 'pending',
    response_data JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.seo_payloads IS 'SEO indexing submission payloads for search engines';

CREATE INDEX idx_seo_payloads_video ON public.seo_payloads(video_id);
CREATE INDEX idx_seo_payloads_user ON public.seo_payloads(user_id);
CREATE INDEX idx_seo_payloads_status ON public.seo_payloads(status);
CREATE INDEX idx_seo_payloads_engine ON public.seo_payloads(search_engine);

-- =================================================================================
-- SECTION 6: WORKFLOW & JOBS TABLES
-- =================================================================================

-- Job Queue (Background Jobs)
CREATE TABLE public.job_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    job_type_id UUID NOT NULL REFERENCES public.supported_job_types(id),
    
    -- Job details
    status public.workflow_status NOT NULL DEFAULT 'pending',
    target_id UUID,
    payload JSONB,
    result JSONB,
    
    -- Error handling
    error_message TEXT,
    
    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Optional platform/handle references
    platform_type_id UUID REFERENCES public.supported_platform_types(id),
    handle_id UUID REFERENCES public.account_handles(id)
);

COMMENT ON TABLE public.job_queue IS 'Background job queue for async processing';

CREATE INDEX idx_job_queue_user ON public.job_queue(user_id);
CREATE INDEX idx_job_queue_status ON public.job_queue(status);
CREATE INDEX idx_job_queue_type ON public.job_queue(job_type_id);
CREATE INDEX idx_job_queue_platform ON public.job_queue(platform_type_id) WHERE platform_type_id IS NOT NULL;

-- =================================================================================
-- SECTION 7: NOTIFICATIONS & AUDIT
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
CREATE INDEX idx_notifications_status ON public.notifications(user_id, status) WHERE status = 'unread';

-- Audit Log
CREATE TABLE public.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    
    -- Action details
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id UUID,
    metadata JSONB,
    
    -- Context
    ip_address TEXT,
    user_agent TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.audit_log IS 'Audit trail for compliance and security';

CREATE INDEX idx_audit_log_user ON public.audit_log(user_id);
CREATE INDEX idx_audit_log_resource ON public.audit_log(resource_type, resource_id);
CREATE INDEX idx_audit_log_created ON public.audit_log(created_at DESC);

-- =================================================================================
-- SECTION 8: FUNCTIONS
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
    INSERT INTO public.subscription_settings (user_id, tier)
    VALUES (NEW.id, 'free');
    
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

-- =================================================================================
-- SECTION 9: UPDATE TRIGGERS
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

-- Content tables
CREATE TRIGGER update_account_handles_updated_at
    BEFORE UPDATE ON public.account_handles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_video_content_updated_at
    BEFORE UPDATE ON public.video_content
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

-- Job & Notification tables
CREATE TRIGGER update_job_queue_updated_at
    BEFORE UPDATE ON public.job_queue
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_notifications_updated_at
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- =================================================================================
-- SECTION 10: ROW LEVEL SECURITY (RLS)
-- =================================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_handles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_content_suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seo_payloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supported_platform_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supported_content_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supported_job_types ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile"
    ON public.profiles
    FOR SELECT
    TO public
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    TO public
    USING (auth.uid() = id);

-- User roles policies
CREATE POLICY "Users can view own roles"
    ON public.user_roles
    FOR SELECT
    TO public
    USING (auth.uid() = user_id);

-- User preferences policies
CREATE POLICY "Users can view own preferences"
    ON public.user_preferences
    FOR SELECT
    TO public
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
    ON public.user_preferences
    FOR UPDATE
    TO public
    USING (auth.uid() = user_id);

-- Subscription settings policies
CREATE POLICY "Users can view own subscription"
    ON public.subscription_settings
    FOR SELECT
    TO public
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own subscription"
    ON public.subscription_settings
    FOR UPDATE
    TO public
    USING (auth.uid() = user_id);

-- Account handles policies
CREATE POLICY "Users can manage own handles"
    ON public.account_handles
    FOR ALL
    TO public
    USING (auth.uid() = user_id);

CREATE POLICY "Public handles are viewable"
    ON public.account_handles
    FOR SELECT
    TO public
    USING (visibility = 'public');

-- Video content policies
CREATE POLICY "Users can manage own videos"
    ON public.video_content
    FOR ALL
    TO public
    USING (auth.uid() = user_id);

CREATE POLICY "Public videos are viewable"
    ON public.video_content
    FOR SELECT
    TO public
    USING (visibility = 'public' AND deleted_at IS NULL);

-- AI suggestions policies
CREATE POLICY "Users can manage own AI suggestions"
    ON public.ai_content_suggestions
    FOR ALL
    TO public
    USING (auth.uid() = user_id);

-- SEO payloads policies
CREATE POLICY "Users can manage own SEO payloads"
    ON public.seo_payloads
    FOR ALL
    TO public
    USING (auth.uid() = user_id);

-- Job queue policies
CREATE POLICY "Users can view own jobs"
    ON public.job_queue
    FOR SELECT
    TO public
    USING (auth.uid() = user_id);

-- Notifications policies
CREATE POLICY "Users can manage own notifications"
    ON public.notifications
    FOR ALL
    TO public
    USING (auth.uid() = user_id);

-- Audit log policies
CREATE POLICY "Admins can view audit logs"
    ON public.audit_log
    FOR SELECT
    TO public
    USING (has_role(auth.uid(), 'admin'));

-- System tables policies (read-only for authenticated users, admin can modify)
CREATE POLICY "Authenticated users can select supported_platform_types"
    ON public.supported_platform_types
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can manage supported_platform_types"
    ON public.supported_platform_types
    FOR ALL
    TO public
    USING (has_role(auth.uid(), 'admin'));

CREATE POLICY "Authenticated users can select supported_content_types"
    ON public.supported_content_types
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can manage supported_content_types"
    ON public.supported_content_types
    FOR ALL
    TO public
    USING (has_role(auth.uid(), 'admin'));

CREATE POLICY "Authenticated users can select supported_job_types"
    ON public.supported_job_types
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can manage supported_job_types"
    ON public.supported_job_types
    FOR ALL
    TO public
    USING (has_role(auth.uid(), 'admin'));

-- =================================================================================
-- SECTION 11: INITIAL DATA (Optional - Seed Data)
-- =================================================================================

-- Seed supported platform types
INSERT INTO public.supported_platform_types (name, description, platform_url) VALUES
    ('youtube', 'YouTube video platform', 'https://youtube.com'),
    ('instagram', 'Instagram social media platform', 'https://instagram.com'),
    ('tiktok', 'TikTok short video platform', 'https://tiktok.com'),
    ('facebook', 'Facebook social media platform', 'https://facebook.com')
ON CONFLICT (name) DO NOTHING;

-- Seed supported content types
INSERT INTO public.supported_content_types (name, description) VALUES
    ('long_video', 'Long-form video content (typically >60 seconds)'),
    ('short_video', 'Short-form video content (typically ≤60 seconds)'),
    ('account_handle', 'Social media account/channel')
ON CONFLICT (name) DO NOTHING;

-- Seed supported job types
INSERT INTO public.supported_job_types (name) VALUES
    ('platform_sync'),
    ('ai_enhancement'),
    ('seo_indexing'),
    ('batch_sync'),
    ('batch_ai'),
    ('batch_indexing'),
    ('handle_sync')
ON CONFLICT (name) DO NOTHING;

-- =================================================================================
-- END OF SCHEMA EXPORT
-- =================================================================================

-- Usage Instructions:
-- 1. Create a new Supabase project via the Supabase dashboard
-- 2. Go to SQL Editor in your new project
-- 3. Copy and paste this entire script
-- 4. Execute the script to create all schema elements
-- 5. Verify that all tables, functions, and policies are created successfully
--
-- Note: This script assumes you're starting with a fresh Supabase instance.
-- If running on an existing instance, review for potential conflicts.
