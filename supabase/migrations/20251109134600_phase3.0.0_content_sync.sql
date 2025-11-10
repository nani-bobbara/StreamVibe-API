-- =================================================================================
-- MODULE 002: CONTENT MANAGEMENT
-- =================================================================================
-- Purpose: Store and manage synced content from social platforms
-- Dependencies: 
--   - 000_base_core.sql (requires users table)
--   - 001_platform_connections.sql (requires social_account, platform, content_type tables)
-- Testing: Sync content, track edits, search functionality
-- Date: November 8, 2025
-- 
-- Tables Created:
--   - Lookup: content_type
--   - Core: content_item, content_revision
-- 
-- Key Features:
--   - Full-text search with tsvector
--   - Soft delete support
--   - Edit history tracking
--   - Multi-platform content aggregation
-- =================================================================================

-- =================================================================================
-- SECTION 1: LOOKUP TABLES
-- =================================================================================

CREATE TABLE public.content_type (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INT DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.content_type IS 'Types of content (videos, images, posts, etc)';

-- =================================================================================
-- SECTION 2: CONTENT ITEMS
-- =================================================================================

CREATE TABLE public.content_item (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    social_account_id UUID NOT NULL REFERENCES public.social_account(id) ON DELETE RESTRICT,
    platform_id UUID NOT NULL REFERENCES public.platform(id),
    content_type_id UUID NOT NULL REFERENCES public.content_type(id),
    
    -- Platform content reference
    platform_content_id TEXT NOT NULL,
    platform_url TEXT,
    
    -- Content metadata
    title TEXT,
    description TEXT,
    thumbnail_url TEXT,
    media_url TEXT,
    duration_seconds INT,
    
    -- Engagement metrics
    views_count INT DEFAULT 0,
    likes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    shares_count INT DEFAULT 0,
    
    -- SEO & discovery
    tags TEXT[],
    hashtags TEXT[],
    category TEXT,
    language TEXT DEFAULT 'en',
    
    -- AI enhancements (will be populated by AI module)
    ai_description TEXT,
    
    -- Full-text search (populated by trigger)
    search_vector tsvector,
    
    -- Timestamps
    published_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Visibility
    visibility public.visibility_enum DEFAULT 'public',
    
    -- SEO overrides (from discovery module)
    seo_title TEXT,
    seo_description TEXT,
    canonical_url TEXT,
    
    -- Click tracking (from discovery module)
    total_clicks INT DEFAULT 0,
    clicks_last_7_days INT DEFAULT 0,
    clicks_last_30_days INT DEFAULT 0,
    
    -- Podcast/eBook fields (platform-specific)
    episode_number INT,
    season_number INT,
    podcast_show_name TEXT,
    podcast_show_id TEXT,
    isbn TEXT,
    book_author TEXT,
    book_publisher TEXT,
    publication_date DATE,
    page_count INT,
    amazon_rating DECIMAL(3,2),
    amazon_reviews_count INT,
    
    -- Embed caching
    embed_html TEXT,
    embed_cached_at TIMESTAMPTZ,
    
    -- Soft delete
    deleted_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(platform_id, platform_content_id)
);

COMMENT ON TABLE public.content_item IS 'Synced content from social media platforms';

-- Function to update search_vector
CREATE OR REPLACE FUNCTION public.content_item_search_vector_update()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.description, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(array_to_string(NEW.tags, ' '), '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Trigger to populate search_vector
CREATE TRIGGER content_item_search_vector_trigger
    BEFORE INSERT OR UPDATE OF title, description, tags
    ON public.content_item
    FOR EACH ROW
    EXECUTE FUNCTION public.content_item_search_vector_update();

-- Composite indexes for common queries
CREATE INDEX idx_content_item_account ON public.content_item(social_account_id, published_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_content_item_platform ON public.content_item(platform_id, published_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_content_item_published ON public.content_item(published_at DESC) WHERE deleted_at IS NULL AND visibility = 'public';
CREATE INDEX idx_content_item_search ON public.content_item USING GIN(search_vector);
CREATE INDEX idx_content_item_tags ON public.content_item USING GIN(tags) WHERE tags IS NOT NULL;
CREATE INDEX idx_content_item_hashtags ON public.content_item USING GIN(hashtags) WHERE hashtags IS NOT NULL;

-- =================================================================================
-- SECTION 3: CONTENT REVISIONS (Edit History)
-- =================================================================================

CREATE TABLE public.content_revision (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_item_id UUID NOT NULL REFERENCES public.content_item(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
    
    -- Changed fields
    field_name TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    
    -- Metadata
    change_source TEXT,
    change_reason TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.content_revision IS 'Audit trail of content modifications';

CREATE INDEX idx_content_revision_content ON public.content_revision(content_item_id, created_at DESC);
CREATE INDEX idx_content_revision_user ON public.content_revision(user_id, created_at DESC);

-- =================================================================================
-- SECTION 4: HELPER FUNCTIONS
-- =================================================================================

-- Prevent deletion of social accounts with content
CREATE OR REPLACE FUNCTION public.prevent_account_deletion_with_content()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.content_item
        WHERE social_account_id = OLD.id
        AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Cannot delete social account with existing content. Archive content first.';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_account_deletion_with_content
    BEFORE DELETE ON public.social_account
    FOR EACH ROW EXECUTE FUNCTION public.prevent_account_deletion_with_content();

-- =================================================================================
-- SECTION 5: TRIGGERS
-- =================================================================================

CREATE TRIGGER trg_content_item_updated_at BEFORE UPDATE ON public.content_item FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =================================================================================
-- SECTION 6: ROW LEVEL SECURITY
-- =================================================================================

ALTER TABLE public.content_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_revision ENABLE ROW LEVEL SECURITY;

-- Users can manage their own content
CREATE POLICY content_item_all_own ON public.content_item
FOR ALL USING (
    auth.uid() IN (
        SELECT user_id FROM public.social_account
        WHERE id = content_item.social_account_id
    )
);

-- Public content viewable by anyone
CREATE POLICY content_item_select_public ON public.content_item
FOR SELECT USING (
    visibility = 'public' AND deleted_at IS NULL
);

-- Content revisions viewable by owner
CREATE POLICY content_revision_select_own ON public.content_revision
FOR SELECT USING (auth.uid() = user_id);

-- =================================================================================
-- SECTION 7: INITIAL DATA
-- =================================================================================

INSERT INTO public.content_type (slug, display_name, description, sort_order)
VALUES
('long_video', 'Long Video', 'Videos longer than 60 seconds', 1),
('short_video', 'Short Video', 'Videos 60 seconds or less', 2),
('image', 'Image', 'Static images and photos', 3),
('carousel', 'Carousel', 'Multiple images in sequence', 4),
('story', 'Story', 'Temporary content (24 hours)', 5),
('reel', 'Reel', 'Short vertical video', 6),
('post', 'Post', 'Text-based post', 7);

-- =================================================================================
-- SECTION 8: GRANTS & PERMISSIONS
-- =================================================================================

GRANT SELECT ON public.content_type TO authenticated, anon;
GRANT ALL ON public.content_item TO authenticated;
GRANT ALL ON public.content_revision TO authenticated;

-- =================================================================================
-- MODULE VERIFICATION
-- =================================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Module 002: Content Management - COMPLETE';
    RAISE NOTICE '   Tables: 3 (content_type, content_item, content_revision)';
    RAISE NOTICE '   Content Types: 7 (long_video, short_video, image, carousel, story, reel, post)';
    RAISE NOTICE '   Indexes: 8 (including GIN for full-text search)';
    RAISE NOTICE '   RLS Policies: 3';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test this module:';
    RAISE NOTICE '   1. Deploy sync-youtube Edge Function';
    RAISE NOTICE '   2. Sync content: POST /functions/v1/sync-youtube with social_account_id';
    RAISE NOTICE '   3. Verify content_item rows created with platform metadata';
    RAISE NOTICE '   4. Test search: SELECT * FROM content_item WHERE search_vector @@ plainto_tsquery(''gaming'')';
    RAISE NOTICE '   5. Test soft delete protection on social_account';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Search Features:';
    RAISE NOTICE '   - Full-text search on title, description, tags';
    RAISE NOTICE '   - GIN indexes for array columns (tags, hashtags)';
    RAISE NOTICE '   - Generated tsvector column (auto-updated)';
    RAISE NOTICE '';
    RAISE NOTICE '➡️  Next: Apply 003_ai_integration.sql';
END $$;
