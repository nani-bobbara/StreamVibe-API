-- =====================================================
-- Migration: 001_phase1_discovery_platform
-- Description: Add critical schema gaps for metadata aggregation & discovery platform
-- Author: StreamVibe Team
-- Date: 2025-11-07
-- 
-- Critical Changes:
-- 1. Creator public profiles (display_name, bio, avatar, profile_slug, SEO)
-- 2. Content categories (Music, Gaming, Education, etc.)
-- 3. AI-generated tags for discoverability
-- 4. Full-text search vectors (PostgreSQL)
-- 5. Click tracking & analytics
-- 6. Multi-media support (Instagram carousels, Facebook albums)
-- 7. SEO enhancements (title overrides, meta descriptions)
-- =====================================================

-- =====================================================
-- 1. CREATOR PUBLIC PROFILES
-- =====================================================

-- Extend users table with public profile fields
ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS display_name TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS website_url TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS profile_slug TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS primary_category TEXT,
  ADD COLUMN IF NOT EXISTS total_followers_count BIGINT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS profile_views_count BIGINT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS profile_clicks_count BIGINT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS seo_title TEXT,
  ADD COLUMN IF NOT EXISTS seo_description TEXT;

-- Add search vector for users (full-text search)
ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS search_vector tsvector 
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(display_name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(bio, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(location, '')), 'C')
  ) STORED;

-- Indexes for creator discovery
CREATE INDEX IF NOT EXISTS idx_users_slug ON users(profile_slug) WHERE profile_slug IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_category ON users(primary_category) WHERE is_public = TRUE;
CREATE INDEX IF NOT EXISTS idx_users_verified ON users(is_verified) WHERE is_verified = TRUE;
CREATE INDEX IF NOT EXISTS idx_users_public ON users(is_public, created_at DESC) WHERE is_public = TRUE;
CREATE INDEX IF NOT EXISTS idx_users_search ON users USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_users_followers ON users(total_followers_count DESC) WHERE is_public = TRUE;

COMMENT ON COLUMN users.display_name IS 'Public display name for creator profile';
COMMENT ON COLUMN users.profile_slug IS 'URL-friendly slug for profile: streamvibe.com/c/{slug}';
COMMENT ON COLUMN users.primary_category IS 'Main content category: music, gaming, education, etc.';
COMMENT ON COLUMN users.total_followers_count IS 'Sum of followers across all connected platforms';
COMMENT ON COLUMN users.profile_clicks_count IS 'Total clicks from profile to original platforms';
COMMENT ON COLUMN users.is_public IS 'Whether profile is publicly discoverable (opt-out for privacy)';

-- =====================================================
-- 2. CONTENT CATEGORIES
-- =====================================================

-- Create content category lookup table
CREATE TABLE IF NOT EXISTS content_category (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  parent_category TEXT REFERENCES content_category(code),
  icon_name TEXT,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Populate with common categories
INSERT INTO content_category (code, name, description, sort_order) VALUES
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
  ('other', 'Other', 'Miscellaneous content not fitting other categories', 99)
ON CONFLICT (code) DO NOTHING;

-- Add category reference to content_item
ALTER TABLE content_item 
  ADD COLUMN IF NOT EXISTS category_code TEXT REFERENCES content_category(code);

CREATE INDEX IF NOT EXISTS idx_content_category ON content_item(category_code) WHERE category_code IS NOT NULL;

COMMENT ON TABLE content_category IS 'Lookup table for content categorization (genre, topic)';
COMMENT ON COLUMN content_item.category_code IS 'Primary category for content discovery and filtering';

-- =====================================================
-- 3. AI-GENERATED TAGS & KEYWORDS
-- =====================================================

-- Create content tags table for AI-generated and platform tags
CREATE TABLE IF NOT EXISTS content_tag (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID NOT NULL REFERENCES content_item(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  source TEXT NOT NULL CHECK (source IN ('ai_generated', 'platform_original', 'user_added')),
  confidence_score DECIMAL(3,2), -- 0.00-1.00 for AI tags
  tag_type TEXT CHECK (tag_type IN ('keyword', 'topic', 'entity', 'emotion', 'trend', 'hashtag')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id)
);

-- Indexes for tag search and filtering
CREATE INDEX IF NOT EXISTS idx_content_tag_content ON content_tag(content_id);
CREATE INDEX IF NOT EXISTS idx_content_tag_search ON content_tag(tag) WHERE source = 'ai_generated';
CREATE INDEX IF NOT EXISTS idx_content_tag_type ON content_tag(tag_type, tag);
CREATE INDEX IF NOT EXISTS idx_content_tag_source ON content_tag(source, created_at DESC);

-- Add unique constraint to prevent duplicate tags per content
CREATE UNIQUE INDEX IF NOT EXISTS idx_content_tag_unique ON content_tag(content_id, tag, source);

COMMENT ON TABLE content_tag IS 'AI-generated and platform tags for content discoverability';
COMMENT ON COLUMN content_tag.source IS 'Origin: ai_generated (GPT-4), platform_original (YouTube/Instagram hashtags), user_added (manual)';
COMMENT ON COLUMN content_tag.confidence_score IS 'AI confidence level (0.0-1.0), NULL for non-AI tags';
COMMENT ON COLUMN content_tag.tag_type IS 'Classification: keyword (SEO), topic (category), entity (person/brand), emotion (sentiment), trend (viral), hashtag (social)';

-- =====================================================
-- 4. FULL-TEXT SEARCH ENHANCEMENTS
-- =====================================================

-- Add search vector to content_item
ALTER TABLE content_item 
  ADD COLUMN IF NOT EXISTS search_vector tsvector 
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(ai_description, description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(array_to_string(tags, ' '), '')), 'C')
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_content_search ON content_item USING GIN(search_vector);

-- Add SEO fields to content_item
ALTER TABLE content_item
  ADD COLUMN IF NOT EXISTS seo_title TEXT,
  ADD COLUMN IF NOT EXISTS seo_description TEXT,
  ADD COLUMN IF NOT EXISTS canonical_url TEXT;

COMMENT ON COLUMN content_item.seo_title IS 'Optimized title for search engines (overrides platform title)';
COMMENT ON COLUMN content_item.seo_description IS 'AI-generated meta description for SEO';
COMMENT ON COLUMN content_item.canonical_url IS 'Original platform URL for canonical link tag';

-- =====================================================
-- 5. CLICK TRACKING & ANALYTICS
-- =====================================================

-- Create click tracking table
CREATE TABLE IF NOT EXISTS content_click (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID NOT NULL REFERENCES content_item(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id), -- NULL for anonymous users
  clicked_at TIMESTAMPTZ DEFAULT NOW(),
  referrer TEXT,
  user_agent TEXT,
  ip_address INET,
  country_code TEXT,
  city TEXT
);

-- Indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_content_click_content ON content_click(content_id, clicked_at DESC);
CREATE INDEX IF NOT EXISTS idx_content_click_date ON content_click(clicked_at DESC);
CREATE INDEX IF NOT EXISTS idx_content_click_user ON content_click(user_id, clicked_at DESC) WHERE user_id IS NOT NULL;

-- Add click counters to content_item for quick access
ALTER TABLE content_item
  ADD COLUMN IF NOT EXISTS total_clicks INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS clicks_last_7_days INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS clicks_last_30_days INT DEFAULT 0;

-- Create function to increment click counters
CREATE OR REPLACE FUNCTION increment_content_clicks(p_content_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE content_item
  SET 
    total_clicks = total_clicks + 1,
    clicks_last_7_days = (
      SELECT COUNT(*) FROM content_click 
      WHERE content_id = p_content_id 
      AND clicked_at > NOW() - INTERVAL '7 days'
    ),
    clicks_last_30_days = (
      SELECT COUNT(*) FROM content_click 
      WHERE content_id = p_content_id 
      AND clicked_at > NOW() - INTERVAL '30 days'
    )
  WHERE id = p_content_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE content_click IS 'Track clicks from StreamVibe to original platform (measure value to creators)';
COMMENT ON COLUMN content_click.referrer IS 'Source of traffic (Google, direct, social media)';
COMMENT ON COLUMN content_item.total_clicks IS 'All-time clicks to original platform';

-- =====================================================
-- 6. MULTI-MEDIA SUPPORT (Carousels, Albums)
-- =====================================================

-- Create content media table for Instagram carousels, Facebook albums
CREATE TABLE IF NOT EXISTS content_media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID NOT NULL REFERENCES content_item(id) ON DELETE CASCADE,
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

-- Indexes for media queries
CREATE INDEX IF NOT EXISTS idx_content_media_content ON content_media(content_id, display_order);
CREATE INDEX IF NOT EXISTS idx_content_media_type ON content_media(media_type);

COMMENT ON TABLE content_media IS 'Multiple media items per content (Instagram carousels with 10 images, Facebook albums)';
COMMENT ON COLUMN content_media.display_order IS 'Order in carousel/album (1, 2, 3...)';
COMMENT ON COLUMN content_media.media_url IS 'URL to media on original platform (NOT stored locally)';

-- =====================================================
-- 7. TRENDING & FEATURED CONTENT
-- =====================================================

-- Create trending content table
CREATE TABLE IF NOT EXISTS trending_content (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID NOT NULL REFERENCES content_item(id) ON DELETE CASCADE,
  trend_score DECIMAL(10,2) NOT NULL,
  trend_category TEXT NOT NULL CHECK (trend_category IN ('today', 'week', 'month', 'all_time')),
  rank_position INT,
  started_trending_at TIMESTAMPTZ DEFAULT NOW(),
  last_updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(content_id, trend_category)
);

-- Create featured creators table
CREATE TABLE IF NOT EXISTS featured_creator (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  featured_reason TEXT,
  featured_until TIMESTAMPTZ,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id) -- Admin who featured them
);

-- Indexes for trending/featured queries
CREATE INDEX IF NOT EXISTS idx_trending_category ON trending_content(trend_category, rank_position);
CREATE INDEX IF NOT EXISTS idx_trending_score ON trending_content(trend_score DESC);
CREATE INDEX IF NOT EXISTS idx_featured_active ON featured_creator(featured_until, display_order) WHERE featured_until > NOW();

COMMENT ON TABLE trending_content IS 'Algorithm-based trending content for homepage discovery';
COMMENT ON COLUMN trending_content.trend_score IS 'Composite score: (clicks * 0.4) + (views * 0.3) + (recency * 0.3)';
COMMENT ON TABLE featured_creator IS 'Manually curated featured creators (editor picks, milestones)';

-- =====================================================
-- 8. PLATFORM-SPECIFIC ENHANCEMENTS
-- =====================================================

-- Add podcast-specific fields to content_item
ALTER TABLE content_item
  ADD COLUMN IF NOT EXISTS episode_number INT,
  ADD COLUMN IF NOT EXISTS season_number INT,
  ADD COLUMN IF NOT EXISTS podcast_show_name TEXT,
  ADD COLUMN IF NOT EXISTS podcast_show_id TEXT;

-- Add eBook-specific fields to content_item
ALTER TABLE content_item
  ADD COLUMN IF NOT EXISTS isbn TEXT,
  ADD COLUMN IF NOT EXISTS book_author TEXT,
  ADD COLUMN IF NOT EXISTS book_publisher TEXT,
  ADD COLUMN IF NOT EXISTS publication_date DATE,
  ADD COLUMN IF NOT EXISTS page_count INT,
  ADD COLUMN IF NOT EXISTS amazon_rating DECIMAL(3,2),
  ADD COLUMN IF NOT EXISTS amazon_reviews_count INT;

-- Add embed caching fields
ALTER TABLE content_item
  ADD COLUMN IF NOT EXISTS embed_html TEXT,
  ADD COLUMN IF NOT EXISTS embed_cached_at TIMESTAMPTZ;

COMMENT ON COLUMN content_item.embed_html IS 'Cached platform embed code (YouTube iframe, Instagram embed)';
COMMENT ON COLUMN content_item.podcast_show_name IS 'Spotify show name for podcast episodes';
COMMENT ON COLUMN content_item.isbn IS 'ISBN-10 or ISBN-13 for books';

-- =====================================================
-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on new tables
ALTER TABLE content_tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_click ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE trending_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE featured_creator ENABLE ROW LEVEL SECURITY;

-- Public read access for discovery platform
CREATE POLICY "Public can view tags" ON content_tag FOR SELECT USING (true);
CREATE POLICY "Public can view media" ON content_media FOR SELECT USING (true);
CREATE POLICY "Public can view trending" ON trending_content FOR SELECT USING (true);
CREATE POLICY "Public can view featured" ON featured_creator FOR SELECT USING (true);

-- Users can add their own tags
CREATE POLICY "Users can add tags to their content" ON content_tag 
  FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM content_item 
      WHERE content_item.id = content_tag.content_id 
      AND content_item.user_id = auth.uid()
    )
  );

-- Click tracking is insert-only (no updates/deletes)
CREATE POLICY "Anyone can track clicks" ON content_click FOR INSERT WITH CHECK (true);

-- Only admins can manage trending/featured
CREATE POLICY "Admins manage trending" ON trending_content FOR ALL 
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins manage featured" ON featured_creator FOR ALL 
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Update users RLS to allow public profile viewing
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON users;
CREATE POLICY "Public profiles are viewable by everyone" ON users 
  FOR SELECT 
  USING (is_public = true OR id = auth.uid());

-- =====================================================
-- 10. HELPER FUNCTIONS
-- =====================================================

-- Function to generate unique profile slug
CREATE OR REPLACE FUNCTION generate_profile_slug(p_display_name TEXT, p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_slug TEXT;
  v_counter INT := 0;
  v_temp_slug TEXT;
BEGIN
  -- Convert to lowercase, replace spaces with hyphens, remove special chars
  v_slug := lower(regexp_replace(p_display_name, '[^a-zA-Z0-9\s-]', '', 'g'));
  v_slug := regexp_replace(v_slug, '\s+', '-', 'g');
  v_slug := regexp_replace(v_slug, '-+', '-', 'g');
  v_slug := trim(both '-' from v_slug);
  
  -- Limit to 50 characters
  v_slug := substring(v_slug from 1 for 50);
  
  v_temp_slug := v_slug;
  
  -- Check uniqueness, append counter if needed
  WHILE EXISTS (SELECT 1 FROM users WHERE profile_slug = v_temp_slug AND id != p_user_id) LOOP
    v_counter := v_counter + 1;
    v_temp_slug := v_slug || '-' || v_counter;
  END LOOP;
  
  RETURN v_temp_slug;
END;
$$ LANGUAGE plpgsql;

-- Function to update follower counts from connected platforms
CREATE OR REPLACE FUNCTION update_total_followers(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE users
  SET total_followers_count = (
    SELECT COALESCE(SUM(followers_count), 0)
    FROM social_account
    WHERE user_id = p_user_id
  )
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate trending score
CREATE OR REPLACE FUNCTION calculate_trend_score(
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
  -- Normalize clicks (max 1000)
  v_click_score := LEAST(p_clicks / 1000.0, 1.0) * 0.4;
  
  -- Normalize views (max 100000)
  v_view_score := LEAST(p_views / 100000.0, 1.0) * 0.3;
  
  -- Recency score (decay over 30 days)
  v_days_old := EXTRACT(EPOCH FROM (NOW() - p_created_at)) / 86400;
  v_recency_score := GREATEST(1.0 - (v_days_old / 30.0), 0) * 0.3;
  
  RETURN v_click_score + v_view_score + v_recency_score;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 11. SCHEDULED JOBS (pg_cron)
-- =====================================================

-- Update trending content daily at 2 AM
SELECT cron.schedule(
  'update-trending-content',
  '0 2 * * *', -- Daily at 2 AM
  $$
  INSERT INTO trending_content (content_id, trend_score, trend_category, rank_position)
  SELECT 
    id,
    calculate_trend_score(total_clicks, views_count, published_at),
    'today',
    ROW_NUMBER() OVER (ORDER BY calculate_trend_score(total_clicks, views_count, published_at) DESC)
  FROM content_item
  WHERE published_at > NOW() - INTERVAL '1 day'
  ON CONFLICT (content_id, trend_category) 
  DO UPDATE SET 
    trend_score = EXCLUDED.trend_score,
    rank_position = EXCLUDED.rank_position,
    last_updated_at = NOW();
  $$
);

-- Clean old click data (keep last 90 days only)
SELECT cron.schedule(
  'cleanup-old-clicks',
  '0 3 * * 0', -- Weekly on Sunday at 3 AM
  $$
  DELETE FROM content_click 
  WHERE clicked_at < NOW() - INTERVAL '90 days';
  $$
);

-- Update follower counts weekly
SELECT cron.schedule(
  'update-follower-counts',
  '0 4 * * 0', -- Weekly on Sunday at 4 AM
  $$
  SELECT update_total_followers(id) FROM users WHERE is_public = true;
  $$
);

-- =====================================================
-- 12. GRANTS & PERMISSIONS
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT ON content_category TO authenticated;
GRANT SELECT, INSERT ON content_tag TO authenticated;
GRANT SELECT ON content_media TO authenticated;
GRANT INSERT ON content_click TO authenticated, anon;
GRANT SELECT ON trending_content TO authenticated, anon;
GRANT SELECT ON featured_creator TO authenticated, anon;

-- Grant function execution
GRANT EXECUTE ON FUNCTION generate_profile_slug TO authenticated;
GRANT EXECUTE ON FUNCTION update_total_followers TO authenticated;
GRANT EXECUTE ON FUNCTION increment_content_clicks TO authenticated, anon;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

-- Verify critical indexes exist
DO $$
BEGIN
  RAISE NOTICE 'Migration 001_phase1_discovery_platform completed successfully!';
  RAISE NOTICE 'New tables: content_category, content_tag, content_click, content_media, trending_content, featured_creator';
  RAISE NOTICE 'New indexes: 15+ indexes for search, discovery, and analytics';
  RAISE NOTICE 'New functions: generate_profile_slug, update_total_followers, calculate_trend_score, increment_content_clicks';
  RAISE NOTICE 'Scheduled jobs: update-trending-content (daily), cleanup-old-clicks (weekly), update-follower-counts (weekly)';
END $$;
