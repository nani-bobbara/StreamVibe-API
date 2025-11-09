-- =================================================================================
-- MODULE 005: DISCOVERY PLATFORM
-- =================================================================================
-- Purpose: Public discovery features - categories, tags, trending, creator profiles
-- Dependencies:
--   - 000_base_core.sql (requires users table)
--   - 002_content_management.sql (requires content_item table)
-- Testing: Browse content, search creators, trending algorithms
-- Date: November 8, 2025
-- 
-- Tables Created:
--   - Lookup: content_category
--   - Core: content_tag, content_click, content_media, trending_content, featured_creator
-- 
-- Key Features:
--   - Category-based content discovery
--   - AI and platform-generated tags
--   - Click tracking and analytics
--   - Multi-media support (carousels)
--   - Trending algorithm
--   - Featured creators curation
-- =================================================================================

-- =================================================================================
-- SECTION 1: CONTENT CATEGORIES
-- =================================================================================

CREATE TABLE public.content_category (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    parent_category TEXT REFERENCES public.content_category(code),
    icon_name TEXT,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.content_category IS 'Content categorization for discovery';

INSERT INTO public.content_category (code, name, description, sort_order) VALUES
('music', 'Music', 'Songs, music videos, covers, live performances', 1),
('gaming', 'Gaming', 'Gameplay, reviews, walkthroughs, esports', 2),
('education', 'Education', 'Tutorials, courses, how-tos, lectures', 3),
('lifestyle', 'Lifestyle', 'Vlogs, daily life, travel, personal stories', 4),
('comedy', 'Comedy', 'Sketches, standup, funny videos, memes', 5),
('tech', 'Technology', 'Reviews, news, coding tutorials, gadgets', 6),
('beauty', 'Beauty & Fashion', 'Makeup, skincare, fashion, styling', 7),
('fitness', 'Fitness & Health', 'Workouts, nutrition, wellness, sports', 8),
('food', 'Food & Cooking', 'Recipes, cooking shows, food reviews', 9),
('business', 'Business & Finance', 'Entrepreneurship, investing, marketing', 10),
('art', 'Arts & Crafts', 'Drawing, painting, DIY, creative projects', 11),
('entertainment', 'Entertainment', 'Movies, TV shows, celebrity news', 12),
('news', 'News & Politics', 'Current events, commentary, journalism', 13),
('science', 'Science', 'Research, experiments, documentaries', 14),
('other', 'Other', 'Miscellaneous content', 99)
ON CONFLICT (code) DO NOTHING;

-- Add category reference to content_item (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'content_item' AND column_name = 'category_code'
    ) THEN
        ALTER TABLE public.content_item 
        ADD COLUMN category_code TEXT REFERENCES public.content_category(code);
        
        CREATE INDEX idx_content_category ON public.content_item(category_code) WHERE category_code IS NOT NULL;
    END IF;
END $$;

-- =================================================================================
-- SECTION 2: CONTENT TAGS
-- =================================================================================

CREATE TABLE public.content_tag (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES public.content_item(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('ai_generated', 'platform_original', 'user_added')),
    confidence_score DECIMAL(3,2),
    tag_type TEXT CHECK (tag_type IN ('keyword', 'topic', 'entity', 'emotion', 'trend', 'hashtag')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES public.users(id)
);

COMMENT ON TABLE public.content_tag IS 'AI-generated and platform tags for content discoverability';

CREATE INDEX idx_content_tag_content ON public.content_tag(content_id);
CREATE INDEX idx_content_tag_search ON public.content_tag(tag) WHERE source = 'ai_generated';
CREATE INDEX idx_content_tag_type ON public.content_tag(tag_type, tag);
CREATE UNIQUE INDEX idx_content_tag_unique ON public.content_tag(content_id, tag, source);

-- =================================================================================
-- SECTION 3: CLICK TRACKING
-- =================================================================================

CREATE TABLE public.content_click (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES public.content_item(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id),
    clicked_at TIMESTAMPTZ DEFAULT NOW(),
    referrer TEXT,
    user_agent TEXT,
    ip_address INET,
    country_code TEXT,
    city TEXT
);

COMMENT ON TABLE public.content_click IS 'Track clicks from StreamVibe to original platform';

CREATE INDEX idx_content_click_content ON public.content_click(content_id, clicked_at DESC);
CREATE INDEX idx_content_click_date ON public.content_click(clicked_at DESC);
CREATE INDEX idx_content_click_user ON public.content_click(user_id, clicked_at DESC) WHERE user_id IS NOT NULL;

-- Function to increment click counters
CREATE OR REPLACE FUNCTION public.increment_content_clicks(p_content_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.content_item
    SET 
        total_clicks = total_clicks + 1,
        clicks_last_7_days = (
            SELECT COUNT(*) FROM public.content_click 
            WHERE content_id = p_content_id 
            AND clicked_at > NOW() - INTERVAL '7 days'
        ),
        clicks_last_30_days = (
            SELECT COUNT(*) FROM public.content_click 
            WHERE content_id = p_content_id 
            AND clicked_at > NOW() - INTERVAL '30 days'
        )
    WHERE id = p_content_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================================
-- SECTION 4: MULTI-MEDIA SUPPORT
-- =================================================================================

CREATE TABLE public.content_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES public.content_item(id) ON DELETE CASCADE,
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video', 'audio')),
    display_order INT NOT NULL DEFAULT 1,
    width INT,
    height INT,
    duration_seconds INT,
    thumbnail_url TEXT,
    file_size_bytes BIGINT,
    mime_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.content_media IS 'Multiple media items per content (Instagram carousels, albums)';

CREATE INDEX idx_content_media_content ON public.content_media(content_id, display_order);
CREATE INDEX idx_content_media_type ON public.content_media(media_type);

-- =================================================================================
-- SECTION 5: TRENDING CONTENT
-- =================================================================================

CREATE TABLE public.trending_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES public.content_item(id) ON DELETE CASCADE,
    trend_score DECIMAL(10,2) NOT NULL,
    trend_category TEXT NOT NULL CHECK (trend_category IN ('today', 'week', 'month', 'all_time')),
    rank_position INT,
    started_trending_at TIMESTAMPTZ DEFAULT NOW(),
    last_updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(content_id, trend_category)
);

COMMENT ON TABLE public.trending_content IS 'Algorithm-based trending content for homepage discovery';

CREATE INDEX idx_trending_category ON public.trending_content(trend_category, rank_position);
CREATE INDEX idx_trending_score ON public.trending_content(trend_score DESC);

-- Function to calculate trending score
CREATE OR REPLACE FUNCTION public.calculate_trend_score(
    p_clicks INT,
    p_views INT,
    p_created_at TIMESTAMPTZ
)
RETURNS DECIMAL AS $$
DECLARE
    v_click_score DECIMAL;
    v_view_score DECIMAL;
    v_recency_score DECIMAL;
    v_days_old INT;
BEGIN
    v_click_score := LEAST(p_clicks / 1000.0, 1.0) * 0.4;
    v_view_score := LEAST(p_views / 100000.0, 1.0) * 0.3;
    v_days_old := EXTRACT(EPOCH FROM (NOW() - p_created_at)) / 86400;
    v_recency_score := GREATEST(1.0 - (v_days_old / 30.0), 0) * 0.3;
    
    RETURN v_click_score + v_view_score + v_recency_score;
END;
$$ LANGUAGE plpgsql;

-- =================================================================================
-- SECTION 6: FEATURED CREATORS
-- =================================================================================

CREATE TABLE public.featured_creator (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    featured_reason TEXT,
    featured_until TIMESTAMPTZ,
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES public.users(id)
);

COMMENT ON TABLE public.featured_creator IS 'Manually curated featured creators';

-- Index for active featured creators - removed NOW() from predicate (not IMMUTABLE)
-- Queries should filter by date at runtime: WHERE featured_until > NOW()
CREATE INDEX idx_featured_active ON public.featured_creator(featured_until, display_order) WHERE featured_until IS NOT NULL;

-- =================================================================================
-- SECTION 7: HELPER FUNCTIONS
-- =================================================================================

-- Generate unique profile slug
CREATE OR REPLACE FUNCTION public.generate_profile_slug(p_display_name TEXT, p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_slug TEXT;
    v_counter INT := 0;
    v_temp_slug TEXT;
BEGIN
    v_slug := lower(regexp_replace(p_display_name, '[^a-zA-Z0-9\s-]', '', 'g'));
    v_slug := regexp_replace(v_slug, '\s+', '-', 'g');
    v_slug := regexp_replace(v_slug, '-+', '-', 'g');
    v_slug := trim(both '-' from v_slug);
    v_slug := substring(v_slug from 1 for 50);
    
    v_temp_slug := v_slug;
    
    WHILE EXISTS (SELECT 1 FROM public.users WHERE profile_slug = v_temp_slug AND id != p_user_id) LOOP
        v_counter := v_counter + 1;
        v_temp_slug := v_slug || '-' || v_counter;
    END LOOP;
    
    RETURN v_temp_slug;
END;
$$ LANGUAGE plpgsql;

-- Update total followers from connected platforms
CREATE OR REPLACE FUNCTION public.update_total_followers(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.users
    SET total_followers_count = (
        SELECT COALESCE(SUM(follower_count), 0)
        FROM public.social_account
        WHERE user_id = p_user_id
    )
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================================
-- SECTION 8: ROW LEVEL SECURITY
-- =================================================================================

ALTER TABLE public.content_tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_click ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trending_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.featured_creator ENABLE ROW LEVEL SECURITY;

-- Public read access
CREATE POLICY content_tag_select_public ON public.content_tag FOR SELECT USING (true);
CREATE POLICY content_media_select_public ON public.content_media FOR SELECT USING (true);
CREATE POLICY trending_content_select_public ON public.trending_content FOR SELECT USING (true);
CREATE POLICY featured_creator_select_public ON public.featured_creator FOR SELECT USING (true);

-- Users can add tags to their content
CREATE POLICY content_tag_insert_own ON public.content_tag 
FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.content_item 
        JOIN public.social_account ON content_item.social_account_id = social_account.id
        WHERE content_item.id = content_tag.content_id 
        AND social_account.user_id = auth.uid()
    )
);

-- Anyone can track clicks
CREATE POLICY content_click_insert_public ON public.content_click FOR INSERT WITH CHECK (true);

-- Only admins manage trending/featured
CREATE POLICY trending_content_admin_all ON public.trending_content FOR ALL USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY featured_creator_admin_all ON public.featured_creator FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- =================================================================================
-- SECTION 9: GRANTS & PERMISSIONS
-- =================================================================================

GRANT SELECT ON public.content_category TO authenticated, anon;
GRANT SELECT, INSERT ON public.content_tag TO authenticated;
GRANT SELECT ON public.content_media TO authenticated, anon;
GRANT INSERT ON public.content_click TO authenticated, anon;
GRANT SELECT ON public.trending_content TO authenticated, anon;
GRANT SELECT ON public.featured_creator TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.generate_profile_slug TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_total_followers TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_content_clicks TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.calculate_trend_score TO authenticated;

-- =================================================================================
-- MODULE VERIFICATION
-- =================================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Module 005: Discovery Platform - COMPLETE';
    RAISE NOTICE '   Tables: 6 (content_category, content_tag, content_click, content_media, trending_content, featured_creator)';
    RAISE NOTICE '   Categories: 15 (music, gaming, education, etc.)';
    RAISE NOTICE '   Functions: 4 (generate_profile_slug, update_total_followers, increment_content_clicks, calculate_trend_score)';
    RAISE NOTICE '   RLS Policies: 7';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test this module:';
    RAISE NOTICE '   1. Deploy browse-content Edge Function';
    RAISE NOTICE '   2. Browse by category: GET /functions/v1/browse-content?category=gaming';
    RAISE NOTICE '   3. Search creators: GET /functions/v1/search-creators?q=tech';
    RAISE NOTICE '   4. Track click: POST /functions/v1/track-click with content_id';
    RAISE NOTICE '   5. View trending: GET /functions/v1/get-trending?period=today';
    RAISE NOTICE '   6. Verify click counters updated in content_item';
    RAISE NOTICE '';
    RAISE NOTICE '🔥 Trending Algorithm:';
    RAISE NOTICE '   - Score = (clicks * 0.4) + (views * 0.3) + (recency * 0.3)';
    RAISE NOTICE '   - Updated daily via pg_cron';
    RAISE NOTICE '   - Categories: today, week, month, all_time';
    RAISE NOTICE '';
    RAISE NOTICE '➡️  Next: Apply 006_async_infrastructure.sql (FINAL MODULE)';
END $$;
