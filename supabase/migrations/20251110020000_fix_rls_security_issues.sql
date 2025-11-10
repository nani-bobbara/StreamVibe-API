-- Migration: Fix RLS Security Issues
-- Description: Enable RLS on lookup/enum tables flagged by Supabase linter
-- Date: 2024-11-10

-- =====================================================================================
-- ENABLE RLS ON ALL FLAGGED TABLES
-- =====================================================================================

-- Subscription related lookup tables
ALTER TABLE public.subscription_tier ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_status ENABLE ROW LEVEL SECURITY;

-- Platform and content lookup tables
ALTER TABLE public.platform ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_category ENABLE ROW LEVEL SECURITY;

-- Account and user related lookup tables
ALTER TABLE public.account_status ENABLE ROW LEVEL SECURITY;

-- AI related lookup tables
ALTER TABLE public.ai_provider ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_model ENABLE ROW LEVEL SECURITY;

-- SEO and discovery lookup tables
ALTER TABLE public.search_engine ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trending_keyword ENABLE ROW LEVEL SECURITY;

-- Job queue lookup tables
ALTER TABLE public.job_type ENABLE ROW LEVEL SECURITY;

-- Cache store (system table)
ALTER TABLE public.cache_store ENABLE ROW LEVEL SECURITY;

-- =====================================================================================
-- CREATE PUBLIC READ POLICIES FOR LOOKUP TABLES
-- =====================================================================================
-- These are lookup/enum tables that should be readable by all authenticated users
-- but only writable by service role

-- Subscription tier (Free, Pro, Enterprise)
CREATE POLICY "subscription_tier_read_all" ON public.subscription_tier
    FOR SELECT
    TO authenticated
    USING (true);

-- Subscription status (active, cancelled, etc.)
CREATE POLICY "subscription_status_read_all" ON public.subscription_status
    FOR SELECT
    TO authenticated
    USING (true);

-- Platform (YouTube, Instagram, TikTok)
CREATE POLICY "platform_read_all" ON public.platform
    FOR SELECT
    TO authenticated
    USING (true);

-- Content type (video, image, etc.)
CREATE POLICY "content_type_read_all" ON public.content_type
    FOR SELECT
    TO authenticated
    USING (true);

-- Content category (entertainment, education, etc.)
CREATE POLICY "content_category_read_all" ON public.content_category
    FOR SELECT
    TO authenticated
    USING (true);

-- Account status (active, suspended, etc.)
CREATE POLICY "account_status_read_all" ON public.account_status
    FOR SELECT
    TO authenticated
    USING (true);

-- AI provider (OpenAI, Claude, etc.)
CREATE POLICY "ai_provider_read_all" ON public.ai_provider
    FOR SELECT
    TO authenticated
    USING (true);

-- AI model (GPT-4, Claude-3, etc.)
CREATE POLICY "ai_model_read_all" ON public.ai_model
    FOR SELECT
    TO authenticated
    USING (true);

-- Search engine (Google, Bing)
CREATE POLICY "search_engine_read_all" ON public.search_engine
    FOR SELECT
    TO authenticated
    USING (true);

-- Trending keyword (public read for discovery)
CREATE POLICY "trending_keyword_read_all" ON public.trending_keyword
    FOR SELECT
    TO authenticated
    USING (true);

-- Job type (sync, ai_tag, seo_submit)
CREATE POLICY "job_type_read_all" ON public.job_type
    FOR SELECT
    TO authenticated
    USING (true);

-- Cache store (system-only access)
-- Allow service role full access
CREATE POLICY "cache_store_service_role_all" ON public.cache_store
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Allow authenticated users to read their own cache entries
CREATE POLICY "cache_store_read_own" ON public.cache_store
    FOR SELECT
    TO authenticated
    USING (key LIKE 'user:%' AND key LIKE 'user:' || auth.uid()::text || '%');

-- =====================================================================================
-- COMMENTS
-- =====================================================================================

COMMENT ON POLICY "subscription_tier_read_all" ON public.subscription_tier IS 
'Allow all authenticated users to read subscription tiers';

COMMENT ON POLICY "subscription_status_read_all" ON public.subscription_status IS 
'Allow all authenticated users to read subscription statuses';

COMMENT ON POLICY "platform_read_all" ON public.platform IS 
'Allow all authenticated users to read available platforms';

COMMENT ON POLICY "content_type_read_all" ON public.content_type IS 
'Allow all authenticated users to read content types';

COMMENT ON POLICY "content_category_read_all" ON public.content_category IS 
'Allow all authenticated users to read content categories';

COMMENT ON POLICY "account_status_read_all" ON public.account_status IS 
'Allow all authenticated users to read account statuses';

COMMENT ON POLICY "ai_provider_read_all" ON public.ai_provider IS 
'Allow all authenticated users to read AI providers';

COMMENT ON POLICY "ai_model_read_all" ON public.ai_model IS 
'Allow all authenticated users to read AI models';

COMMENT ON POLICY "search_engine_read_all" ON public.search_engine IS 
'Allow all authenticated users to read search engines';

COMMENT ON POLICY "trending_keyword_read_all" ON public.trending_keyword IS 
'Allow all authenticated users to read trending keywords';

COMMENT ON POLICY "job_type_read_all" ON public.job_type IS 
'Allow all authenticated users to read job types';

COMMENT ON POLICY "cache_store_service_role_all" ON public.cache_store IS 
'Allow service role full access to cache store';

COMMENT ON POLICY "cache_store_read_own" ON public.cache_store IS 
'Allow users to read their own cache entries';
