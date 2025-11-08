-- =====================================================
-- ROLLBACK: 001_phase1_discovery_platform
-- Description: Rollback all Phase 1 schema changes
-- Author: StreamVibe Team
-- Date: 2025-11-07
-- =====================================================

-- Drop scheduled jobs
SELECT cron.unschedule('update-trending-content');
SELECT cron.unschedule('cleanup-old-clicks');
SELECT cron.unschedule('update-follower-counts');

-- Drop functions
DROP FUNCTION IF EXISTS calculate_trend_score(INT, INT, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS update_total_followers(UUID);
DROP FUNCTION IF EXISTS generate_profile_slug(TEXT, UUID);
DROP FUNCTION IF EXISTS increment_content_clicks(UUID);

-- Drop new tables
DROP TABLE IF EXISTS featured_creator CASCADE;
DROP TABLE IF EXISTS trending_content CASCADE;
DROP TABLE IF EXISTS content_media CASCADE;
DROP TABLE IF EXISTS content_click CASCADE;
DROP TABLE IF EXISTS content_tag CASCADE;
DROP TABLE IF EXISTS content_category CASCADE;

-- Remove columns from content_item
ALTER TABLE content_item
  DROP COLUMN IF EXISTS search_vector,
  DROP COLUMN IF EXISTS seo_title,
  DROP COLUMN IF EXISTS seo_description,
  DROP COLUMN IF EXISTS canonical_url,
  DROP COLUMN IF EXISTS total_clicks,
  DROP COLUMN IF EXISTS clicks_last_7_days,
  DROP COLUMN IF EXISTS clicks_last_30_days,
  DROP COLUMN IF EXISTS category_code,
  DROP COLUMN IF EXISTS episode_number,
  DROP COLUMN IF EXISTS season_number,
  DROP COLUMN IF EXISTS podcast_show_name,
  DROP COLUMN IF EXISTS podcast_show_id,
  DROP COLUMN IF EXISTS isbn,
  DROP COLUMN IF EXISTS book_author,
  DROP COLUMN IF EXISTS book_publisher,
  DROP COLUMN IF EXISTS publication_date,
  DROP COLUMN IF EXISTS page_count,
  DROP COLUMN IF EXISTS amazon_rating,
  DROP COLUMN IF EXISTS amazon_reviews_count,
  DROP COLUMN IF EXISTS embed_html,
  DROP COLUMN IF EXISTS embed_cached_at;

-- Remove columns from users
ALTER TABLE users
  DROP COLUMN IF EXISTS search_vector,
  DROP COLUMN IF EXISTS display_name,
  DROP COLUMN IF EXISTS bio,
  DROP COLUMN IF EXISTS avatar_url,
  DROP COLUMN IF EXISTS website_url,
  DROP COLUMN IF EXISTS location,
  DROP COLUMN IF EXISTS is_verified,
  DROP COLUMN IF EXISTS profile_slug,
  DROP COLUMN IF EXISTS primary_category,
  DROP COLUMN IF EXISTS total_followers_count,
  DROP COLUMN IF EXISTS profile_views_count,
  DROP COLUMN IF EXISTS profile_clicks_count,
  DROP COLUMN IF EXISTS is_public,
  DROP COLUMN IF EXISTS seo_title,
  DROP COLUMN IF EXISTS seo_description;

-- Drop indexes
DROP INDEX IF EXISTS idx_users_slug;
DROP INDEX IF EXISTS idx_users_category;
DROP INDEX IF EXISTS idx_users_verified;
DROP INDEX IF EXISTS idx_users_public;
DROP INDEX IF EXISTS idx_users_search;
DROP INDEX IF EXISTS idx_users_followers;
DROP INDEX IF EXISTS idx_content_category;
DROP INDEX IF EXISTS idx_content_search;

-- Rollback complete
DO $$
BEGIN
  RAISE NOTICE 'Rollback 001_phase1_discovery_platform completed successfully!';
END $$;
