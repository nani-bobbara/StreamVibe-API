-- =================================================================================
-- MODULE 001: PLATFORM CONNECTIONS & SOCIAL ACCOUNTS
-- =================================================================================
-- Purpose: OAuth connections to social media platforms (YouTube, Instagram, TikTok)
-- Dependencies: 000_base_core.sql (requires users table)
-- Testing: OAuth flow, token storage in Vault, account linking
-- Date: November 8, 2025
-- 
-- Tables Created:
--   - Lookup: platform, account_status
--   - Core: platform_connection, social_account
-- 
-- Key Features:
--   - Vault-based credential storage (NOT in database!)
--   - OAuth token expiry tracking
--   - Multi-account support per platform
--   - Auto-sync scheduling
-- =================================================================================

-- =================================================================================
-- SECTION 1: LOOKUP TABLES
-- =================================================================================

-- Platforms
CREATE TABLE public.platform (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT,
    website_url TEXT,
    logo_url TEXT,
    api_docs_url TEXT,
    is_oauth_required BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INT DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.platform IS 'Supported social media platforms';

-- Account Statuses
CREATE TABLE public.account_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.account_status IS 'Social account connection statuses';

INSERT INTO public.account_status (slug, display_name) VALUES
('active', 'Active'),
('inactive', 'Inactive'),
('suspended', 'Suspended'),
('disconnected', 'Disconnected');

-- =================================================================================
-- SECTION 2: PLATFORM CONNECTIONS (OAuth Credentials)
-- =================================================================================

CREATE TABLE public.platform_connection (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES public.platform(id),
    
    -- Vault secret reference (NOT actual credentials!)
    vault_secret_name TEXT NOT NULL,
    
    -- OAuth details
    scopes TEXT[],
    token_expires_at TIMESTAMPTZ,
    
    -- Platform account info
    platform_user_id TEXT NOT NULL,
    platform_username TEXT,
    platform_display_name TEXT,
    platform_avatar_url TEXT,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    last_verified_at TIMESTAMPTZ,
    last_error TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(user_id, platform_id)
);

COMMENT ON TABLE public.platform_connection IS 'User platform OAuth connections with Vault-stored credentials';
COMMENT ON COLUMN public.platform_connection.vault_secret_name IS 'Supabase Vault secret key (e.g., user_123_youtube_token)';

CREATE INDEX idx_platform_connection_user_platform ON public.platform_connection(user_id, platform_id) WHERE is_active = true;
-- Index for expiring tokens - removed NOW() from predicate (not IMMUTABLE)
-- Queries should filter by date at runtime: WHERE token_expires_at < NOW() + INTERVAL '7 days'
CREATE INDEX idx_platform_connection_expiring ON public.platform_connection(token_expires_at) WHERE is_active = true AND token_expires_at IS NOT NULL;

-- =================================================================================
-- SECTION 3: SOCIAL ACCOUNTS (User's channels/profiles)
-- =================================================================================

CREATE TABLE public.social_account (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    connection_id UUID NOT NULL REFERENCES public.platform_connection(id) ON DELETE CASCADE,
    platform_id UUID NOT NULL REFERENCES public.platform(id),
    status_id UUID NOT NULL REFERENCES public.account_status(id),
    
    -- Account details
    account_name TEXT NOT NULL,
    account_url TEXT,
    description TEXT,
    follower_count INT DEFAULT 0,
    following_count INT DEFAULT 0,
    post_count INT DEFAULT 0,
    
    -- Sync settings
    sync_mode public.action_mode_enum DEFAULT 'manual',
    last_synced_at TIMESTAMPTZ,
    last_sync_status TEXT,
    next_sync_at TIMESTAMPTZ,
    
    -- Visibility
    visibility public.visibility_enum DEFAULT 'public',
    is_primary BOOLEAN DEFAULT false,
    
    -- Soft delete
    deleted_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.social_account IS 'Connected social media accounts/channels';

CREATE INDEX idx_social_account_user ON public.social_account(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_social_account_connection ON public.social_account(connection_id);
CREATE INDEX idx_social_account_platform ON public.social_account(platform_id);
CREATE INDEX idx_social_account_user_platform_active ON public.social_account(user_id, platform_id, is_primary) WHERE deleted_at IS NULL;
CREATE INDEX idx_social_account_next_sync ON public.social_account(next_sync_at) WHERE sync_mode = 'auto' AND deleted_at IS NULL;

-- =================================================================================
-- SECTION 4: TRIGGERS
-- =================================================================================

CREATE TRIGGER trg_platform_connection_updated_at BEFORE UPDATE ON public.platform_connection FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_social_account_updated_at BEFORE UPDATE ON public.social_account FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =================================================================================
-- SECTION 5: ROW LEVEL SECURITY
-- =================================================================================

ALTER TABLE public.platform_connection ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_account ENABLE ROW LEVEL SECURITY;

-- Users can manage their own connections
CREATE POLICY platform_connection_all_own ON public.platform_connection FOR ALL USING (auth.uid() = user_id);

-- Users can manage their own social accounts
CREATE POLICY social_account_all_own ON public.social_account FOR ALL USING (auth.uid() = user_id);

-- =================================================================================
-- SECTION 6: INITIAL DATA
-- =================================================================================

INSERT INTO public.platform (slug, display_name, description, is_oauth_required, sort_order)
VALUES
('youtube', 'YouTube', 'Video sharing platform', true, 1),
('instagram', 'Instagram', 'Photo and video sharing', true, 2),
('tiktok', 'TikTok', 'Short-form video platform', true, 3),
('facebook', 'Facebook', 'Social networking platform', true, 4),
('twitter', 'Twitter/X', 'Microblogging platform', true, 5);

-- =================================================================================
-- SECTION 7: GRANTS & PERMISSIONS
-- =================================================================================

GRANT SELECT ON public.platform TO authenticated, anon;
GRANT SELECT ON public.account_status TO authenticated, anon;
GRANT ALL ON public.platform_connection TO authenticated;
GRANT ALL ON public.social_account TO authenticated;

-- =================================================================================
-- MODULE VERIFICATION
-- =================================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Module 001: Platform Connections - COMPLETE';
    RAISE NOTICE '   Tables: 4 (platform, account_status, platform_connection, social_account)';
    RAISE NOTICE '   Platforms: 5 (YouTube, Instagram, TikTok, Facebook, Twitter)';
    RAISE NOTICE '   RLS Policies: 2';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test this module:';
    RAISE NOTICE '   1. Deploy oauth-youtube-init Edge Function';
    RAISE NOTICE '   2. Test OAuth flow: GET /functions/v1/oauth-youtube-init';
    RAISE NOTICE '   3. Verify platform_connection created with vault_secret_name';
    RAISE NOTICE '   4. Check credentials stored in Supabase Vault (NOT in database!)';
    RAISE NOTICE '   5. Verify social_account auto-created with channel info';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Critical: Credentials NEVER stored in database - only Vault references!';
    RAISE NOTICE '➡️  Next: Apply 002_content_management.sql';
END $$;
