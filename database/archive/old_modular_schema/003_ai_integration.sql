-- =================================================================================
-- MODULE 003: AI INTEGRATION
-- =================================================================================
-- Purpose: AI-powered content analysis, tag generation, and optimization suggestions
-- Dependencies:
--   - 000_base_core.sql (requires users table)
--   - 002_content_management.sql (requires content_item table)
-- Testing: AI tag generation, trend analysis, cost tracking
-- Date: November 8, 2025
-- 
-- Tables Created:
--   - Lookup: ai_provider, search_engine
--   - Core: ai_model, user_ai_setting, ai_suggestion, ai_suggestion_application, ai_usage, trending_keyword
-- 
-- Key Features:
--   - Multi-provider support (OpenAI, Anthropic, Google, Local)
--   - Token usage and cost tracking
--   - Suggestion versioning
--   - Trending keyword caching
-- =================================================================================

-- =================================================================================
-- SECTION 1: AI PROVIDERS & MODELS
-- =================================================================================

CREATE TABLE public.ai_provider (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    base_url TEXT,
    is_api_key_required BOOLEAN DEFAULT true,
    is_streaming_supported BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.ai_provider IS 'Supported AI providers';

CREATE TABLE public.ai_model (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES public.ai_provider(id),
    model_name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    capabilities TEXT[],
    max_context_tokens INT DEFAULT 8192,
    input_cost_per_1k_tokens DECIMAL(10,4),
    output_cost_per_1k_tokens DECIMAL(10,4),
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(provider_id, model_name)
);

COMMENT ON TABLE public.ai_model IS 'AI models with pricing information';

-- =================================================================================
-- SECTION 2: USER AI SETTINGS
-- =================================================================================

CREATE TABLE public.user_ai_setting (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    preferred_provider_id UUID REFERENCES public.ai_provider(id),
    preferred_model_id UUID REFERENCES public.ai_model(id),
    tone TEXT DEFAULT 'professional',
    language TEXT DEFAULT 'en',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.user_ai_setting IS 'User AI preferences';

-- =================================================================================
-- SECTION 3: AI SUGGESTIONS
-- =================================================================================

CREATE TABLE public.ai_suggestion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_item_id UUID NOT NULL REFERENCES public.content_item(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.ai_provider(id),
    model_id UUID REFERENCES public.ai_model(id),
    
    -- Suggestions
    suggested_titles TEXT[],
    suggested_description TEXT,
    suggested_tags TEXT[],
    suggested_category TEXT,
    trending_keywords TEXT[],
    trending_hashtags TEXT[],
    related_topics TEXT[],
    
    -- Scores (0.00 to 1.00)
    trending_score DECIMAL(3,2),
    seo_score DECIMAL(3,2),
    readability_score DECIMAL(3,2),
    confidence_score DECIMAL(3,2),
    
    -- Analysis
    sentiment TEXT,
    target_audience TEXT[],
    
    -- API usage
    prompt_tokens INT,
    completion_tokens INT,
    total_cost_cents DECIMAL(10,2),
    processing_time_ms INT,
    
    -- Application status
    is_applied BOOLEAN DEFAULT false,
    applied_at TIMESTAMPTZ,
    
    -- Versioning
    version INT DEFAULT 1,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.ai_suggestion IS 'AI-generated content optimization suggestions';

CREATE INDEX idx_ai_suggestion_content ON public.ai_suggestion(content_item_id, created_at DESC);
CREATE INDEX idx_ai_suggestion_pending ON public.ai_suggestion(content_item_id, is_applied, created_at DESC) WHERE is_applied = false;
CREATE INDEX idx_ai_suggestion_trending ON public.ai_suggestion(trending_score DESC, created_at DESC) WHERE trending_score IS NOT NULL;
CREATE INDEX idx_ai_suggestion_keywords ON public.ai_suggestion USING GIN(trending_keywords) WHERE trending_keywords IS NOT NULL;

-- AI Suggestion Applications
CREATE TABLE public.ai_suggestion_application (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    suggestion_id UUID NOT NULL REFERENCES public.ai_suggestion(id) ON DELETE CASCADE,
    field_name TEXT NOT NULL,
    applied_value TEXT,
    applied_by_user_id UUID NOT NULL REFERENCES public.users(id),
    
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.ai_suggestion_application IS 'Track which AI suggestion fields were applied';

CREATE INDEX idx_ai_suggestion_application_suggestion ON public.ai_suggestion_application(suggestion_id);

-- =================================================================================
-- SECTION 4: AI USAGE TRACKING
-- =================================================================================

CREATE TABLE public.ai_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.ai_provider(id),
    model_id UUID NOT NULL REFERENCES public.ai_model(id),
    content_item_id UUID REFERENCES public.content_item(id) ON DELETE SET NULL,
    
    operation_type TEXT NOT NULL,
    prompt_tokens INT NOT NULL,
    completion_tokens INT NOT NULL,
    total_tokens INT NOT NULL,
    cost_cents DECIMAL(10,2) NOT NULL,
    processing_time_ms INT,
    
    -- Billing period
    billing_cycle_start TIMESTAMPTZ NOT NULL,
    billing_cycle_end TIMESTAMPTZ NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.ai_usage IS 'AI API usage tracking for billing';

CREATE INDEX idx_ai_usage_user_billing ON public.ai_usage(user_id, billing_cycle_start, billing_cycle_end);
CREATE INDEX idx_ai_usage_provider_model ON public.ai_usage(provider_id, model_id, created_at DESC);

-- =================================================================================
-- SECTION 5: TRENDING KEYWORDS CACHE
-- =================================================================================

CREATE TABLE public.trending_keyword (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform_id UUID NOT NULL REFERENCES public.platform(id),
    keyword TEXT NOT NULL,
    category TEXT,
    trending_score DECIMAL(5,2) NOT NULL,
    search_volume INT,
    competition_level TEXT,
    source TEXT,
    region TEXT DEFAULT 'US',
    language TEXT DEFAULT 'en',
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(platform_id, keyword, region, language, valid_from)
);

COMMENT ON TABLE public.trending_keyword IS 'Cached trending keywords from various sources';

-- Indexes for trending keywords - removed NOW() from predicates (not IMMUTABLE)
-- Queries should filter by date at runtime: WHERE valid_until > NOW()
CREATE INDEX idx_trending_keyword_platform ON public.trending_keyword(platform_id, trending_score DESC) WHERE valid_until IS NOT NULL;
CREATE INDEX idx_trending_keyword_valid ON public.trending_keyword(valid_until) WHERE valid_until IS NOT NULL;

-- =================================================================================
-- SECTION 6: TRIGGERS
-- =================================================================================

CREATE TRIGGER trg_ai_suggestion_updated_at BEFORE UPDATE ON public.ai_suggestion FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =================================================================================
-- SECTION 7: ROW LEVEL SECURITY
-- =================================================================================

ALTER TABLE public.user_ai_setting ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_suggestion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_suggestion_application ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

-- Users can manage their AI settings
CREATE POLICY user_ai_setting_all_own ON public.user_ai_setting FOR ALL USING (auth.uid() = user_id);

-- Users can view suggestions for their content
CREATE POLICY ai_suggestion_all_own ON public.ai_suggestion
FOR ALL USING (
    auth.uid() IN (
        SELECT sa.user_id
        FROM public.content_item ci
        JOIN public.social_account sa ON ci.social_account_id = sa.id
        WHERE ci.id = ai_suggestion.content_item_id
    )
);

-- Users can view their AI usage
CREATE POLICY ai_usage_select_own ON public.ai_usage FOR SELECT USING (auth.uid() = user_id);

-- =================================================================================
-- SECTION 8: INITIAL DATA
-- =================================================================================

INSERT INTO public.ai_provider (slug, display_name, base_url, is_api_key_required, is_streaming_supported)
VALUES
('openai', 'OpenAI', 'https://api.openai.com/v1', true, true),
('anthropic', 'Anthropic', 'https://api.anthropic.com/v1', true, true),
('google', 'Google AI', 'https://generativelanguage.googleapis.com/v1', true, false),
('local', 'Local Model', 'http://localhost:11434', false, true);

INSERT INTO public.ai_model (provider_id, model_name, display_name, capabilities, max_context_tokens, input_cost_per_1k_tokens, output_cost_per_1k_tokens)
SELECT 
    p.id,
    m.model_name,
    m.display_name,
    m.capabilities,
    m.max_context_tokens,
    m.input_cost,
    m.output_cost
FROM public.ai_provider p
CROSS JOIN (VALUES
    ('openai', 'gpt-4o', 'GPT-4o', ARRAY['text_generation', 'vision'], 128000, 2.50, 10.00),
    ('openai', 'gpt-4o-mini', 'GPT-4o Mini', ARRAY['text_generation', 'vision'], 128000, 0.15, 0.60),
    ('anthropic', 'claude-3-5-sonnet-20241022', 'Claude 3.5 Sonnet', ARRAY['text_generation', 'vision'], 200000, 3.00, 15.00),
    ('google', 'gemini-1.5-pro', 'Gemini 1.5 Pro', ARRAY['text_generation', 'vision'], 2000000, 1.25, 5.00),
    ('local', 'llama3.2', 'Llama 3.2', ARRAY['text_generation'], 8192, 0.00, 0.00)
) AS m(provider_slug, model_name, display_name, capabilities, max_context_tokens, input_cost, output_cost)
WHERE p.slug = m.provider_slug;

-- =================================================================================
-- SECTION 9: GRANTS & PERMISSIONS
-- =================================================================================

GRANT SELECT ON public.ai_provider TO authenticated, anon;
GRANT SELECT ON public.ai_model TO authenticated, anon;
GRANT ALL ON public.user_ai_setting TO authenticated;
GRANT ALL ON public.ai_suggestion TO authenticated;
GRANT ALL ON public.ai_suggestion_application TO authenticated;
GRANT ALL ON public.ai_usage TO authenticated;
GRANT ALL ON public.trending_keyword TO authenticated;

-- =================================================================================
-- MODULE VERIFICATION
-- =================================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Module 003: AI Integration - COMPLETE';
    RAISE NOTICE '   Tables: 7 (ai_provider, ai_model, user_ai_setting, ai_suggestion, ai_suggestion_application, ai_usage, trending_keyword)';
    RAISE NOTICE '   AI Providers: 4 (OpenAI, Anthropic, Google AI, Local)';
    RAISE NOTICE '   AI Models: 5 (GPT-4o, GPT-4o Mini, Claude 3.5, Gemini 1.5 Pro, Llama 3.2)';
    RAISE NOTICE '   RLS Policies: 4';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test this module:';
    RAISE NOTICE '   1. Deploy ai-generate-tags Edge Function';
    RAISE NOTICE '   2. Set OPENAI_API_KEY in Supabase secrets';
    RAISE NOTICE '   3. Generate tags: POST /functions/v1/ai-generate-tags with content_item_id';
    RAISE NOTICE '   4. Verify ai_suggestion created with suggested_titles, suggested_tags, trending_keywords';
    RAISE NOTICE '   5. Check ai_usage table for cost tracking';
    RAISE NOTICE '   6. Test quota: Ensure ai_analyses_used incremented in subscription table';
    RAISE NOTICE '';
    RAISE NOTICE '💰 Cost Tracking:';
    RAISE NOTICE '   - Token usage logged per request';
    RAISE NOTICE '   - Cost calculated from model pricing';
    RAISE NOTICE '   - Billing cycle tracking';
    RAISE NOTICE '';
    RAISE NOTICE '➡️  Next: Apply 004_seo_integration.sql';
END $$;
