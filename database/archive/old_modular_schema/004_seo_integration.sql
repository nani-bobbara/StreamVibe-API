-- =================================================================================
-- MODULE 004: SEO INTEGRATION
-- =================================================================================
-- Purpose: Search engine indexing integration (Google, Bing, Yandex, IndexNow)
-- Dependencies:
--   - 000_base_core.sql (requires users table)
--   - 002_content_management.sql (requires content_item table)
-- Testing: SEO submission, indexing status tracking
-- Date: November 8, 2025
-- 
-- Tables Created:
--   - Lookup: search_engine
--   - Core: seo_connection, seo_submission, seo_usage
-- 
-- Key Features:
--   - Multi-search engine support
--   - Vault-based API credential storage
--   - Submission status tracking
--   - Auto-retry failed submissions
-- =================================================================================

-- =================================================================================
-- SECTION 1: SEARCH ENGINES
-- =================================================================================

CREATE TABLE public.search_engine (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    api_endpoint TEXT,
    api_docs_url TEXT,
    supports_indexnow BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.search_engine IS 'Supported search engines for SEO indexing';

INSERT INTO public.search_engine (slug, display_name, api_endpoint, supports_indexnow) VALUES
('google', 'Google Search Console', 'https://indexing.googleapis.com/v3', false),
('bing', 'Bing Webmaster Tools', 'https://ssl.bing.com/webmaster/api.svc/json', true),
('yandex', 'Yandex Webmaster', 'https://api.webmaster.yandex.net/v4', false),
('indexnow', 'IndexNow Protocol', 'https://api.indexnow.org', true);

-- =================================================================================
-- SECTION 2: SEO CONNECTIONS
-- =================================================================================

CREATE TABLE public.seo_connection (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    search_engine_id UUID NOT NULL REFERENCES public.search_engine(id),
    
    -- Credentials stored in Vault
    vault_secret_name TEXT NOT NULL,
    site_url TEXT NOT NULL,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    last_verified_at TIMESTAMPTZ,
    last_error TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(user_id, search_engine_id, site_url)
);

COMMENT ON TABLE public.seo_connection IS 'User search engine connections with Vault-stored credentials';

CREATE INDEX idx_seo_connection_user_engine ON public.seo_connection(user_id, search_engine_id) WHERE is_active = true;

-- =================================================================================
-- SECTION 3: SEO SUBMISSIONS
-- =================================================================================

CREATE TABLE public.seo_submission (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_item_id UUID NOT NULL REFERENCES public.content_item(id) ON DELETE CASCADE,
    connection_id UUID NOT NULL REFERENCES public.seo_connection(id),
    search_engine_id UUID NOT NULL REFERENCES public.search_engine(id),
    
    -- Submission details
    submitted_url TEXT NOT NULL,
    submission_type TEXT NOT NULL,
    submission_method TEXT,
    
    -- Request/Response
    request_payload JSONB,
    response_status INT,
    response_body JSONB,
    
    -- Indexing status
    status TEXT NOT NULL DEFAULT 'pending',
    status_checked_at TIMESTAMPTZ,
    index_status_url TEXT,
    coverage_state TEXT,
    
    -- Error handling
    error_message TEXT,
    retry_count INT DEFAULT 0,
    next_retry_at TIMESTAMPTZ,
    
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    indexed_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.seo_submission IS 'SEO URL submissions to search engines';

CREATE INDEX idx_seo_submission_content ON public.seo_submission(content_item_id, created_at DESC);
CREATE INDEX idx_seo_submission_connection ON public.seo_submission(connection_id, submitted_at DESC);
CREATE INDEX idx_seo_submission_status ON public.seo_submission(status, next_retry_at) WHERE status IN ('pending', 'failed');
CREATE INDEX idx_seo_submission_engine ON public.seo_submission(search_engine_id, submitted_at DESC);

-- =================================================================================
-- SECTION 4: SEO USAGE TRACKING
-- =================================================================================

CREATE TABLE public.seo_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    search_engine_id UUID NOT NULL REFERENCES public.search_engine(id),
    content_item_id UUID REFERENCES public.content_item(id) ON DELETE SET NULL,
    
    operation_type TEXT NOT NULL,
    urls_count INT DEFAULT 1,
    
    -- Billing period
    billing_cycle_start TIMESTAMPTZ NOT NULL,
    billing_cycle_end TIMESTAMPTZ NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.seo_usage IS 'SEO API usage tracking for billing';

CREATE INDEX idx_seo_usage_user_billing ON public.seo_usage(user_id, billing_cycle_start, billing_cycle_end);
CREATE INDEX idx_seo_usage_engine ON public.seo_usage(search_engine_id, created_at DESC);

-- =================================================================================
-- SECTION 5: TRIGGERS
-- =================================================================================

CREATE TRIGGER trg_seo_submission_updated_at BEFORE UPDATE ON public.seo_submission FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =================================================================================
-- SECTION 6: ROW LEVEL SECURITY
-- =================================================================================

ALTER TABLE public.seo_connection ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seo_submission ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seo_usage ENABLE ROW LEVEL SECURITY;

-- Users can manage their SEO connections
CREATE POLICY seo_connection_all_own ON public.seo_connection FOR ALL USING (auth.uid() = user_id);

-- Users can manage their SEO submissions
CREATE POLICY seo_submission_all_own ON public.seo_submission
FOR ALL USING (
    auth.uid() IN (
        SELECT user_id FROM public.seo_connection
        WHERE id = seo_submission.connection_id
    )
);

-- Users can view their SEO usage
CREATE POLICY seo_usage_select_own ON public.seo_usage FOR SELECT USING (auth.uid() = user_id);

-- =================================================================================
-- SECTION 7: GRANTS & PERMISSIONS
-- =================================================================================

GRANT SELECT ON public.search_engine TO authenticated, anon;
GRANT ALL ON public.seo_connection TO authenticated;
GRANT ALL ON public.seo_submission TO authenticated;
GRANT ALL ON public.seo_usage TO authenticated;

-- =================================================================================
-- MODULE VERIFICATION
-- =================================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Module 004: SEO Integration - COMPLETE';
    RAISE NOTICE '   Tables: 4 (search_engine, seo_connection, seo_submission, seo_usage)';
    RAISE NOTICE '   Search Engines: 4 (Google, Bing, Yandex, IndexNow)';
    RAISE NOTICE '   RLS Policies: 3';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test this module:';
    RAISE NOTICE '   1. Set up Google Search Console API credentials';
    RAISE NOTICE '   2. Store credentials in Vault via Supabase dashboard';
    RAISE NOTICE '   3. Create seo_connection with vault_secret_name';
    RAISE NOTICE '   4. Submit URL: Use Google Indexing API to submit content_item URL';
    RAISE NOTICE '   5. Check seo_submission table for status';
    RAISE NOTICE '   6. Verify seo_submissions_used incremented in subscription table';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 Security:';
    RAISE NOTICE '   - API keys stored in Vault (NOT database)';
    RAISE NOTICE '   - RLS policies enforce user ownership';
    RAISE NOTICE '   - Retry logic for failed submissions';
    RAISE NOTICE '';
    RAISE NOTICE '➡️  Next: Apply 005_discovery_platform.sql';
END $$;
