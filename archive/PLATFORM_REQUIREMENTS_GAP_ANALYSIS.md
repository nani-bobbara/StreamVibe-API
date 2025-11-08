# StreamVibe Schema vs Platform Requirements Analysis

> **🎯 TL;DR**: StreamVibe is a **metadata aggregation & discovery platform** - NOT storing content files, only syncing metadata from social platforms to make creators more discoverable via SEO. Think "Linktree meets IMDb for content creators".

---

## 🎯 UPDATED: Platform Vision & Purpose

**StreamVibe is a Content Creator Discovery & Metadata Aggregation Platform**

### Core Value Proposition:
- **For Creators**: Centralized portfolio that syncs metadata from all platforms, increasing discoverability and reach beyond original platforms
- **For Discoverers**: Search engine optimized directory to find creators and their content across platforms
- **For Search Engines**: SEO-optimized metadata makes creator content discoverable on Google/Bing

### How It Works:
1. ✅ **Creators connect** their social media accounts (OAuth)
2. ✅ **Platform syncs metadata** (titles, descriptions, thumbnails, stats) - NOT the actual content files
3. ✅ **AI enhances** metadata with better descriptions, tags, keywords
4. ✅ **SEO indexing** makes content discoverable on Google/Bing
5. ✅ **Users discover** content → Click → **Redirected to original platform** (YouTube, Instagram, etc.)

### Key Technical Points:
- ❌ **NOT storing**: Video files, images, audio files (copyright/storage nightmare)
- ✅ **ONLY storing**: Metadata, thumbnails URLs, embed codes, stats
- ✅ **Content lives on**: YouTube, Instagram, TikTok, etc. (original platforms)
- ✅ **Platform provides**: Discovery layer + SEO boost + unified portfolio

### Content Types to Support:
- 📹 YouTube Videos & Shorts (metadata + embed code)
- 📸 Instagram Reels, Posts, Stories (metadata + embed code)
- 🎵 TikTok Videos (metadata + embed code)
- 📱 Facebook Videos (metadata + embed code)
- 🎙️ Spotify Podcasts (metadata + Spotify player embed)
- 📚 Kindle eBooks (metadata + Amazon link)
- 🎬 Other video platforms

---

## 🔄 REVISED: Platform Focus Changes Everything

### What Changes with "Metadata Aggregation" Model:

| Aspect | Content Hosting Platform | **Metadata Aggregation (StreamVibe)** |
|--------|-------------------------|---------------------------------------|
| **Content Storage** | Store actual files | **Store only metadata + URLs** |
| **Data Flow** | User uploads content | **Sync metadata from platforms** |
| **Content Delivery** | Stream from own servers | **Embed or redirect to source** |
| **Storage Costs** | High (video, audio, images) | **Low (text, JSON, thumbnails)** |
| **Copyright** | Must handle DMCA, licensing | **No liability (content on source)** |
| **Bandwidth** | High (streaming) | **Low (metadata only)** |
| **Update Frequency** | Real-time | **Periodic sync (nightly)** |
| **Content Hosting** | Platform responsibility | **Creator's platform handles it** |

### Critical Schema Implications:

#### ✅ **CURRENT SCHEMA IS PERFECT FOR THIS!**
1. ✅ **content_item.media_url** - Store YouTube video URL, Instagram post URL
2. ✅ **content_item.thumbnail_url** - Cache thumbnail for fast display
3. ✅ **content_item.embed_code** - Store iframe/embed HTML from platforms
4. ✅ **No actual file storage** - Already designed this way!
5. ✅ **Metadata sync model** - schema.content_synced_at already tracks this

#### 🆕 **MUST ADD (Discovery-Specific)**
1. **Creator Public Profiles** - Display name, bio, avatar, profile URL slug
2. **Content Categories/Genres** - Music, Gaming, Education, etc.
3. **AI-Generated Tags** - Searchable keywords beyond platform hashtags
4. **Full-Text Search** - PostgreSQL search vectors for discoverability
5. **SEO Metadata** - Title overrides, meta descriptions, canonical URLs
6. **Click Tracking** - Track when users click through to original platform
7. **Trending/Popular Rankings** - Algorithm to surface best content

#### ⚠️ **REMOVE/SIMPLIFY (Not Needed Anymore)**
1. ❌ ~~Real-time metrics~~ - Periodic snapshots are fine
2. ❌ ~~Posting/Scheduling~~ - Not building this
3. ❌ ~~Deep platform analytics~~ - Just basic stats for display
4. ❌ ~~Complex quota management~~ - Simple sync is lighter on APIs
5. ❌ ~~Engagement breakdown~~ - Don't need LIKE/LOVE/HAHA details

---

## 📋 Gap Analysis (UPDATED FOR DISCOVERY PLATFORM)

### 🚨 **CRITICAL GAPS** (MVP Blockers)

#### 1. **Creator Public Profile** ⭐⭐⭐
**Problem**: Current `users` table is auth-focused, missing public profile fields
**Impact**: Can't build public creator pages (e.g., `streamvibe.com/c/username`)
**Why Critical**: This IS the product - without profiles, there's nothing to discover
**Solution**:
```sql
-- Add to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS website_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_slug TEXT UNIQUE; -- streamvibe.com/c/slug
ALTER TABLE users ADD COLUMN IF NOT EXISTS primary_category TEXT; -- Music, Gaming, etc.
ALTER TABLE users ADD COLUMN IF NOT EXISTS total_followers_count BIGINT DEFAULT 0; -- Sum across all platforms
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_views_count BIGINT DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_clicks_count BIGINT DEFAULT 0; -- Clicks to original platforms
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS seo_title TEXT; -- Custom SEO title
ALTER TABLE users ADD COLUMN IF NOT EXISTS seo_description TEXT; -- Meta description

CREATE INDEX idx_users_slug ON users(profile_slug) WHERE profile_slug IS NOT NULL;
CREATE INDEX idx_users_category ON users(primary_category) WHERE is_public = TRUE;
CREATE INDEX idx_users_verified ON users(is_verified) WHERE is_verified = TRUE;
CREATE INDEX idx_users_public ON users(is_public, created_at DESC) WHERE is_public = TRUE;
```

#### 2. **Content Categories & Discovery** ⭐⭐⭐
**Problem**: No way to categorize/filter content by genre, topic
**Impact**: Users can't browse "Gaming creators" or "Music videos" - discovery is broken
**Why Critical**: Discovery requires filtering - can't show "all content" to users
**Solution**:
```sql
CREATE TABLE content_category (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  parent_category TEXT REFERENCES content_category(code),
  icon_name TEXT,
  sort_order INT DEFAULT 0
);

-- Populate with common categories
INSERT INTO content_category (code, name, description) VALUES
  ('music', 'Music', 'Songs, music videos, covers'),
  ('gaming', 'Gaming', 'Gameplay, reviews, esports'),
  ('education', 'Education', 'Tutorials, courses, how-tos'),
  ('lifestyle', 'Lifestyle', 'Vlogs, daily life, travel'),
  ('comedy', 'Comedy', 'Sketches, standup, funny videos'),
  ('tech', 'Technology', 'Reviews, news, tutorials'),
  ('beauty', 'Beauty', 'Makeup, skincare, fashion'),
  ('fitness', 'Fitness', 'Workouts, nutrition, wellness'),
  ('food', 'Food', 'Cooking, recipes, reviews'),
  ('business', 'Business', 'Entrepreneurship, finance, marketing');

-- Add category to content
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS category_code TEXT REFERENCES content_category(code);
CREATE INDEX idx_content_category ON content_item(category_code) WHERE category_code IS NOT NULL;
```

#### 3. **AI-Generated Tags & Keywords** ⭐⭐⭐
**Problem**: No structured way to store AI-generated tags for SEO
**Impact**: Can't leverage AI for discoverability - Google won't find your content
**Why Critical**: AI tags are the core value add (better than platform hashtags)
**Solution**:
```sql
CREATE TABLE content_tag (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID REFERENCES content_item(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  source TEXT CHECK (source IN ('ai_generated', 'platform_original', 'user_added')),
  confidence_score DECIMAL(3,2), -- 0.00-1.00 for AI tags
  tag_type TEXT CHECK (tag_type IN ('keyword', 'topic', 'entity', 'emotion', 'trend')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_content_tag_content ON content_tag(content_id);
CREATE INDEX idx_content_tag_search ON content_tag(tag) WHERE source = 'ai_generated'; -- Full-text search
CREATE INDEX idx_content_tag_type ON content_tag(tag_type, tag);
```

#### 4. **Full-Text Search** ⭐⭐⭐
**Problem**: No search indexes for content discovery
**Impact**: Users can't find creators/content - defeats the purpose
**Why Critical**: Search is THE core feature of a discovery platform
**Solution**:
```sql
-- Add search vectors
ALTER TABLE users ADD COLUMN IF NOT EXISTS search_vector tsvector 
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(display_name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(bio, '')), 'B')
  ) STORED;

ALTER TABLE content_item ADD COLUMN IF NOT EXISTS search_vector tsvector 
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(ai_description, description, '')), 'B')
  ) STORED;

CREATE INDEX idx_users_search ON users USING GIN(search_vector);
CREATE INDEX idx_content_search ON content_item USING GIN(search_vector);
```

#### 5. **Click Tracking & Analytics** ⭐⭐⭐
**Problem**: No way to track when users click through to original platforms
**Impact**: Can't measure success, show creators their value, or rank content
**Why Critical**: Creators need proof that your platform drives traffic
**Solution**:
```sql
CREATE TABLE content_click (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID REFERENCES content_item(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id), -- NULL for anonymous
  clicked_at TIMESTAMPTZ DEFAULT NOW(),
  referrer TEXT, -- Where they came from
  user_agent TEXT, -- Browser info
  ip_address INET -- For geo tracking
);

CREATE INDEX idx_content_click_content ON content_click(content_id, clicked_at DESC);
CREATE INDEX idx_content_click_date ON content_click(clicked_at DESC);

-- Add to content_item for quick access
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS total_clicks INT DEFAULT 0;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS clicks_last_7_days INT DEFAULT 0;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS clicks_last_30_days INT DEFAULT 0;
```

---

### ⚠️ **IMPORTANT GAPS** (Launch Soon After MVP)

#### 6. **Multi-Media Content (Carousels)** ⭐⭐
**Problem**: Instagram carousels (up to 10 images), Facebook albums
**Impact**: Can only show first image of carousel - incomplete preview
**Why Important**: Major content types (Instagram carousels are very popular)
**Solution**:
```sql
CREATE TABLE content_media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID REFERENCES content_item(id) ON DELETE CASCADE,
  media_url TEXT NOT NULL, -- URL to image/video on platform
  media_type TEXT CHECK (media_type IN ('image', 'video', 'audio')),
  display_order INT NOT NULL, -- 1, 2, 3... for carousels
  width INT,
  height INT,
  thumbnail_url TEXT, -- Cached thumbnail
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_content_media_content ON content_media(content_id, display_order);
```

#### 7. **Spotify Podcast Support** ⭐⭐
**Problem**: Current schema assumes video/image, but podcasts are audio
**Impact**: Can't onboard podcast creators
**Solution**:
```sql
-- Already have platform_connection.platform_type enum
-- Add 'spotify' to platform_type if not exists
-- content_item.content_type already has 'audio'

-- Add podcast-specific fields
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS episode_number INT;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS season_number INT;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS podcast_show_name TEXT;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS podcast_show_id TEXT; -- Spotify show ID

CREATE TABLE podcast_show (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  social_account_id UUID REFERENCES social_account(id) ON DELETE CASCADE,
  platform_show_id TEXT NOT NULL, -- Spotify show ID
  show_name TEXT NOT NULL,
  description TEXT,
  cover_image_url TEXT,
  publisher TEXT,
  total_episodes INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_podcast_show_unique ON podcast_show(social_account_id, platform_show_id);
```

#### 8. **Kindle/eBook Support** ⭐⭐
**Problem**: Books are completely different content type
**Impact**: Can't onboard authors
**Solution**:
```sql
-- Add 'amazon_kindle' to platform_type enum
-- Add 'ebook' to content_type enum

ALTER TABLE content_item ADD COLUMN IF NOT EXISTS isbn TEXT;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS book_author TEXT;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS book_publisher TEXT;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS publication_date DATE;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS page_count INT;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS amazon_rating DECIMAL(3,2); -- 0.00-5.00
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS amazon_reviews_count INT;

CREATE INDEX idx_content_ebook ON content_item(content_type) WHERE content_type = 'ebook';
```

#### 9. **Trending & Featured Content** ⭐⭐
**Problem**: No way to promote popular/trending content
**Impact**: No homepage, no featured creators
**Solution**:
```sql
CREATE TABLE trending_content (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID REFERENCES content_item(id) ON DELETE CASCADE,
  trend_score DECIMAL(10,2) NOT NULL, -- Algorithm score
  trend_category TEXT, -- 'today', 'week', 'month', 'all_time'
  rank_position INT,
  started_trending_at TIMESTAMPTZ DEFAULT NOW(),
  last_updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE featured_creator (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  featured_reason TEXT, -- 'editor_pick', 'milestone', 'trending'
  featured_until TIMESTAMPTZ,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_trending_category ON trending_content(trend_category, rank_position);
CREATE INDEX idx_featured_active ON featured_creator(featured_until) WHERE featured_until > NOW();
```

#### 9. **Content Embedding & Previews**
**Problem**: Need to cache platform embed codes/URLs
**Impact**: Slow page loads, API quota waste
**Solution**:
```sql
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS embed_html TEXT; -- YouTube iframe, Instagram embed
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS embed_cached_at TIMESTAMPTZ;
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS preview_thumbnail_small TEXT; -- 320x180
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS preview_thumbnail_medium TEXT; -- 640x360
ALTER TABLE content_item ADD COLUMN IF NOT EXISTS preview_thumbnail_large TEXT; -- 1280x720
```

#### 10. **Creator Social Links**
**Problem**: Need to link back to original platforms
**Impact**: Can't drive traffic back to creator's platforms
**Solution**:
```sql
-- This is already covered by social_account table!
-- Just ensure social_account stores profile_url for each platform

ALTER TABLE social_account ADD COLUMN IF NOT EXISTS profile_url TEXT; -- Direct link to platform profile
ALTER TABLE social_account ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT FALSE; -- Main platform
```

---

### 💡 **NICE TO HAVE** (Post-Launch)

#### 11. **Content Collections/Playlists**
**Problem**: Creators might want to curate collections
**Impact**: Enhanced portfolio presentation
**Solution**: Use existing `playlist` structure from YouTube, make platform-agnostic

#### 12. **Analytics for Creators**
**Problem**: Creators want to see profile views, content performance
**Impact**: Creator engagement and retention
**Solution**: Add basic analytics (views, clicks, referrers)

#### 13. **Collaboration Tracking**
**Problem**: Content often features multiple creators
**Impact**: Miss cross-promotion opportunities
**Solution**:
```sql
CREATE TABLE content_collaborator (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID REFERENCES content_item(id) ON DELETE CASCADE,
  collaborator_user_id UUID REFERENCES users(id),
  collaborator_name TEXT, -- If not on platform yet
  collaborator_platform_handle TEXT,
  role TEXT, -- 'featured', 'guest', 'co_creator'
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 🎯 Priority Matrix (REVISED)

### 1. YouTube Data API v3

**What YouTube Provides:**
- **Channel Information**: ID, title, description, custom URL, thumbnails, subscriber count, view count, video count
- **Video Data**: ID, title, description, thumbnails, duration, published date, view count, like count, comment count, category ID, tags, language, privacy status
- **Playlists**: ID, title, description, video count, privacy status
- **Comments**: Comment text, author, like count, published date
- **Statistics**: Real-time metrics (views, likes, comments, shares)
- **Live Streaming**: Live broadcast metadata

**What YouTube Requires:**
- **OAuth Scopes**: 
  - `youtube.readonly` - Read channel data and videos
  - `youtube.force-ssl` - Full access (upload, update, delete)
  - `youtube.upload` - Upload videos
- **API Quotas**: 10,000 units/day (reads: 1 unit, writes: 50+ units)
- **Rate Limits**: 3,000 requests per 100 seconds per user

**Current Schema Coverage:**
- ✅ Channel → `social_account` (account_name, follower_count, account_url)
- ✅ Videos → `content_item` (title, description, views, likes, comments)
- ❌ **GAP**: Playlists (not supported)
- ❌ **GAP**: Categories mapping (YouTube category IDs)
- ❌ **GAP**: Video statistics history (tracking over time)
- ❌ **GAP**: Live streaming status
- ❌ **GAP**: Thumbnails (multiple resolutions)

---

### 2. Instagram Basic Display API / Graph API

**What Instagram Provides:**
- **Account Info**: ID, username, account_type (BUSINESS, MEDIA_CREATOR, PERSONAL), media_count
- **Media Data**: ID, caption, media_type (IMAGE, VIDEO, CAROUSEL_ALBUM), media_url, permalink, thumbnail_url, timestamp, like_count, comments_count
- **Stories**: Temporary 24-hour content
- **Reels**: Short-form video content
- **Albums**: Multiple media items in single post
- **Insights** (Business accounts only): Impressions, reach, engagement

**What Instagram Requires:**
- **OAuth Scopes**:
  - `user_profile` - Basic profile info
  - `user_media` - Access to posts
  - `instagram_basic` - Read access
  - `instagram_manage_insights` - Analytics (Graph API)
- **Token Expiration**: 60 days (requires refresh)
- **Rate Limits**: 200 calls/hour per user

**Current Schema Coverage:**
- ✅ Account → `social_account`
- ✅ Posts → `content_item` (IMAGE, VIDEO types)
- ⚠️ **PARTIAL**: Carousel albums (single content_item, but multiple media URLs?)
- ❌ **GAP**: Stories (24-hour expiration tracking)
- ❌ **GAP**: Reels (separate from regular videos)
- ❌ **GAP**: Media albums (multiple media_url per content_item)
- ❌ **GAP**: Account type distinction (BUSINESS vs PERSONAL)
- ❌ **GAP**: Insights data (impressions, reach, saves)

---

### 3. TikTok for Developers API

**What TikTok Provides:**
- **User Info**: ID, username, display_name, avatar_url, bio, follower_count, following_count, video_count, likes_count
- **Video Data**: ID, title, video_description, duration, cover_image_url, share_url, embed_link, view_count, like_count, comment_count, share_count
- **Video Query**: List user videos with filters
- **Hashtag/Sound**: Trending hashtags, sounds
- **Analytics** (Creator accounts): Video performance metrics

**What TikTok Requires:**
- **OAuth Scopes**:
  - `user.info.basic` - Basic profile
  - `video.list` - List videos
  - `video.upload` - Upload capability
- **Token Expiration**: Access token (24 hours), Refresh token (1 year)
- **Rate Limits**: Varies by endpoint (100-1000 requests/day)

**Current Schema Coverage:**
- ✅ User → `social_account` (username, follower_count)
- ✅ Videos → `content_item` (short_video type)
- ❌ **GAP**: Sounds/Music (TikTok videos have sound IDs)
- ❌ **GAP**: Effects used in video
- ❌ **GAP**: Share count (not in schema)
- ❌ **GAP**: Duet/Stitch relationships (original video reference)
- ❌ **GAP**: Video challenges/hashtag campaigns

---

### 4. Facebook Graph API

**What Facebook Provides:**
- **Page/Profile Info**: ID, name, about, category, followers, engagement
- **Posts**: ID, message, story, full_picture, created_time, reactions (LIKE, LOVE, WOW, HAHA, SAD, ANGRY), comments, shares
- **Videos**: ID, description, length, thumbnails, views, reactions
- **Photos/Albums**: Multiple photos, album organization
- **Live Videos**: Live streaming metadata
- **Insights**: Page metrics, post reach, engagement

**What Facebook Requires:**
- **OAuth Scopes**:
  - `pages_read_engagement` - Read page content
  - `pages_show_list` - List pages
  - `pages_manage_posts` - Manage posts
- **Token Types**: User token (short-lived), Page token (never expires if user token is valid)
- **Rate Limits**: 200 calls/hour per user

**Current Schema Coverage:**
- ✅ Page → `social_account`
- ✅ Posts → `content_item`
- ❌ **GAP**: Reaction types (LIKE, LOVE, WOW, etc.) - only generic like_count
- ❌ **GAP**: Post type (status, photo, video, link, event)
- ❌ **GAP**: Story vs Feed differentiation
- ❌ **GAP**: Albums/Photo collections
- ❌ **GAP**: Event posts
- ❌ **GAP**: Pinned posts

---

### 5. Twitter/X API v2

**What Twitter Provides:**
- **User Info**: ID, username, name, description, profile_image_url, followers_count, following_count, tweet_count, verified
- **Tweet Data**: ID, text, created_at, attachments (media, polls), public_metrics (retweet_count, reply_count, like_count, quote_count, impression_count)
- **Media**: Photos, videos, GIFs, polls
- **Threads**: Connected tweets
- **Spaces**: Live audio conversations

**What Twitter Requires:**
- **OAuth 2.0 Scopes**:
  - `tweet.read` - Read tweets
  - `users.read` - Read user info
  - `offline.access` - Refresh tokens
- **Rate Limits**: Varies by tier (Free: 10,000 tweets/month, Basic: 100,000/month)

**Current Schema Coverage:**
- ✅ User → `social_account`
- ✅ Tweets → `content_item` (post type)
- ❌ **GAP**: Retweet count (not in schema)
- ❌ **GAP**: Quote tweets (reference to original tweet)
- ❌ **GAP**: Reply threads (parent tweet reference)
- ❌ **GAP**: Polls (poll options, vote counts)
- ❌ **GAP**: Twitter Spaces (live audio)
- ❌ **GAP**: Impression count (views)

---

## 🔍 Identified Schema Gaps

### Critical Gaps (Must Have)

#### 1. **Multiple Media Items per Content**
**Issue**: Instagram carousels, Facebook albums have multiple images/videos in one post
**Current**: Single `media_url` in `content_item`
**Solution Needed**: 
```sql
CREATE TABLE content_media (
    id UUID PRIMARY KEY,
    content_item_id UUID REFERENCES content_item(id),
    media_url TEXT NOT NULL,
    media_type TEXT, -- image, video
    width INTEGER,
    height INTEGER,
    duration_seconds INTEGER,
    sort_order INTEGER,
    created_at TIMESTAMPTZ
);
```

#### 2. **Platform-Specific Metrics**
**Issue**: Each platform has unique metrics (shares, retweets, impressions, saves)
**Current**: Only views_count, likes_count, comments_count, shares_count
**Missing**: impressions, reach, saves, quote_count, reaction_types
**Solution Needed**:
```sql
-- Option A: Add columns to content_item
ALTER TABLE content_item ADD COLUMN impressions_count INTEGER;
ALTER TABLE content_item ADD COLUMN reach_count INTEGER;
ALTER TABLE content_item ADD COLUMN saves_count INTEGER;
ALTER TABLE content_item ADD COLUMN retweet_count INTEGER;

-- Option B: Use JSONB for flexibility
ALTER TABLE content_item ADD COLUMN platform_metrics JSONB;
-- Example: {"impressions": 10000, "reach": 8500, "saves": 250}
```

#### 3. **Content Relationships**
**Issue**: Retweets, quote tweets, duets, stitches, replies reference other content
**Current**: No parent/child relationship support
**Solution Needed**:
```sql
ALTER TABLE content_item ADD COLUMN parent_content_id UUID REFERENCES content_item(id);
ALTER TABLE content_item ADD COLUMN relationship_type TEXT; -- retweet, quote, duet, stitch, reply
```

#### 4. **Thumbnail Variations**
**Issue**: Platforms provide multiple thumbnail sizes
**Current**: Single `thumbnail_url`
**Solution Needed**:
```sql
-- Option A: JSONB
ALTER TABLE content_item ADD COLUMN thumbnails JSONB;
-- {"default": "url1", "medium": "url2", "high": "url3", "standard": "url4", "maxres": "url5"}

-- Option B: Separate table
CREATE TABLE content_thumbnail (
    id UUID PRIMARY KEY,
    content_item_id UUID REFERENCES content_item(id),
    size TEXT, -- default, medium, high, standard, maxres
    url TEXT,
    width INTEGER,
    height INTEGER
);
```

#### 5. **Account Type Distinction**
**Issue**: Instagram BUSINESS vs PERSONAL, YouTube CHANNEL vs BRAND
**Current**: No account type field
**Solution Needed**:
```sql
ALTER TABLE social_account ADD COLUMN account_type TEXT;
-- Values: personal, business, creator, brand
```

---

## 🎯 Priority Matrix (REVISED FOR METADATA AGGREGATION)

| Gap | Priority | Effort | Impact | MVP? | Why? |
|-----|----------|--------|--------|------|------|
| Creator Public Profile | 🔴 Critical | Low | High | ✅ YES | Core product feature |
| Content Categories | 🔴 Critical | Low | High | ✅ YES | Required for discovery |
| AI Tags & Keywords | 🔴 Critical | Medium | High | ✅ YES | SEO & discoverability |
| Full-Text Search | 🔴 Critical | Low | High | ✅ YES | Users must find content |
| Click Tracking | 🔴 Critical | Low | High | ✅ YES | Measure value to creators |
| Multi-Media (Carousels) | 🟡 Important | Medium | Medium | ⏳ Phase 2 | Better previews |
| Spotify Podcasts | 🟡 Important | Medium | Medium | ⏳ Phase 2 | Expand creator types |
| Kindle eBooks | 🟡 Important | Medium | Low | ⏳ Phase 2 | No good API |
| Trending Content | 🟡 Important | High | High | ⏳ Phase 2 | Homepage feature |
| Content Embedding | 🟡 Important | Low | Medium | ⏳ Phase 2 | Better UX |
| Collections/Playlists | 🟢 Nice to Have | Medium | Low | ❌ Later | Curation feature |
| Creator Analytics Dashboard | 🟢 Nice to Have | High | Medium | ❌ Later | Retention tool |
| Collaborations | 🟢 Nice to Have | Low | Low | ❌ Later | Cross-promotion |

---

## 🚀 Recommended MVP Scope (REVISED)

### **Phase 1: MVP - Metadata Aggregation Discovery Platform**
**Goal**: Creators can connect 3 platforms, sync metadata, get discovered via SEO

**Launch Timeline**: 4-6 weeks

**Platforms**: YouTube, Instagram, TikTok (video-focused)

**Schema Changes Needed**:
1. ✅ Extend `users` table with public profile fields (13 new columns)
2. ✅ Add `content_category` lookup table + populate with 10 categories
3. ✅ Add `content_tag` table for AI-generated tags
4. ✅ Add `content_click` table for click tracking
5. ✅ Add full-text search vectors to `users` and `content_item`
6. ✅ Add SEO fields to `content_item` (seo_title, seo_description, canonical_url)

**Core Features**:
- ✅ Creator signup + OAuth for YouTube/Instagram/TikTok
- ✅ Nightly metadata sync (titles, descriptions, thumbnails, stats)
- ✅ AI generates optimized descriptions + trending tags (GPT-4)
- ✅ Public profile pages: `streamvibe.com/c/{username}`
- ✅ Search by creator name, category, tags (PostgreSQL full-text)
- ✅ Click tracking with redirect: `streamvibe.com/go/{content_id}` → YouTube/Instagram/TikTok
- ✅ SEO optimized: Sitemap XML, meta tags, schema.org markup
- ✅ Browse by category: Music, Gaming, Education, etc.

**Edge Functions** (Supabase):
1. `oauth-youtube` - YouTube OAuth flow
2. `oauth-instagram` - Instagram OAuth flow
3. `oauth-tiktok` - TikTok OAuth flow
4. `sync-content` - Nightly metadata sync job
5. `generate-ai-tags` - AI description + tag generation
6. `track-click` - Click tracking + redirect
7. `search` - Full-text search API

**API Quota Impact** (Per creator/day):
- YouTube: 50-100 units (list videos, get details)
- Instagram: 20-30 calls (user media, media details)
- TikTok: 10-20 calls (user info, video list)
- **Total cost**: Minimal - stays within free tiers

**Success Metrics**:
- Creators can sign up and see their portfolio in <5 minutes
- Content appears in Google search within 24 hours
- Click-through rate: 5-10% (users click to original platform)

---

### **Phase 2: Expand Content Types (Audio, Books)**
**Goal**: Support podcast creators and authors

**Launch Timeline**: +2-3 weeks after MVP

**New Platforms**: Spotify (podcasts), Amazon Kindle (books - manual entry)

**Schema Changes**:
1. ✅ Add `podcast_show` table
2. ✅ Add `content_media` table (for carousels)
3. ✅ Extend `content_item` with podcast fields (episode_number, season_number)
4. ✅ Extend `content_item` with eBook fields (ISBN, author, publisher)
5. ✅ Add `trending_content` table for homepage
6. ✅ Add embed caching fields

**New Features**:
- Spotify podcast metadata sync
- Manual book entry form (since no Kindle API)
- Trending/featured sections on homepage
- Content embedding (YouTube iframe, Instagram embed)

---

### **Phase 3: Growth & Retention**
**Goal**: Keep creators engaged, grow user base

**Launch Timeline**: +4-6 weeks after Phase 2

**Features**:
- Creator analytics dashboard (profile views, clicks, top content)
- Collections/playlists (curated content groups)
- Collaboration tracking (featured creators in content)
- Newsletter (trending creators weekly)
- Verification badges (followers > 10K)

---

## 📊 API Integration Simplifications

Since this is a **discovery platform** (not management tool), we can simplify API usage:

### YouTube Data API v3
**Need**: Channel info, videos list, video details
**Don't Need**: Comments API, live streaming, playlists (initially)
**Quota Impact**: ~50-100 units per creator sync (vs 1000+ for full management)

### Instagram Basic Display API
**Need**: User profile, media list (posts/reels)
**Don't Need**: Insights API (business accounts only)
**Rate Limits**: 200 calls/hour is plenty for nightly sync

### TikTok for Developers
**Need**: User info, video list
**Don't Need**: Real-time analytics, posting
**Rate Limits**: 100 requests/day sufficient for sync

### Facebook Graph API
**Need**: Page info, posts, videos
**Don't Need**: Ads API, reactions breakdown
**Rate Limits**: Standard limits work fine

### Spotify (NEW)
**Need**: Show info, episodes list
**API**: [Spotify Web API](https://developer.spotify.com/documentation/web-api)
**Auth**: OAuth 2.0
**Rate Limits**: 180 requests per minute

### Amazon Kindle (NEW - TRICKY)
**Problem**: No public API for Kindle books! 🚨
**Alternatives**:
1. Manual entry (creators add their books)
2. Web scraping Amazon (risky, against TOS)
3. Use Amazon Product Advertising API (limited data)
4. GoodReads API (owned by Amazon, being deprecated)

**Recommendation**: Start with **manual entry** for books, add API later if available

---

## 🏗️ Architecture Decisions for Discovery Platform

### 1. **One-Way Sync Only**
- No posting/scheduling features needed
- Simpler OAuth scopes (read-only)
- Lower API quota usage
- Can batch sync during off-peak hours

### 2. **Public-First Design**
- All creator profiles are public by default (opt-out)
- Content is indexed by search engines
- No privacy concerns (content already public on platforms)

### 3. **SEO as Core Feature**
- Every profile gets schema.org markup
- Sitemap auto-generation
- Meta tags optimized per content
- Clean URLs: `streamvibe.com/c/{username}`

### 4. **AI-Enhanced Discovery**
- Auto-generate better descriptions
- Extract trending keywords
- Suggest categories
- Tag entities (people, brands, locations)

---

## 📋 OLD Analysis (Reference Only)

<details>
<summary>Click to view original platform management tool analysis</summary>

### Important Gaps (Should Have)

#### 6. **Playlists/Collections**
**Issue**: YouTube playlists, Instagram collections
**Current**: No playlist support
**Solution Needed**:
```sql
CREATE TABLE playlist (
    id UUID PRIMARY KEY,
    social_account_id UUID REFERENCES social_account(id),
    platform_id UUID REFERENCES platform(id),
    platform_playlist_id TEXT,
    title TEXT,
    description TEXT,
    item_count INTEGER,
    visibility visibility_enum,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE TABLE playlist_item (
    id UUID PRIMARY KEY,
    playlist_id UUID REFERENCES playlist(id),
    content_item_id UUID REFERENCES content_item(id),
    position INTEGER,
    added_at TIMESTAMPTZ
);
```

#### 7. **Stories/Ephemeral Content**
**Issue**: Instagram stories expire after 24 hours
**Current**: No expiration tracking
**Solution Needed**:
```sql
ALTER TABLE content_item ADD COLUMN expires_at TIMESTAMPTZ;
ALTER TABLE content_item ADD COLUMN is_ephemeral BOOLEAN DEFAULT FALSE;
-- Or use existing deleted_at for auto-cleanup
```

#### 8. **Engagement Breakdown**
**Issue**: Facebook reactions (LIKE, LOVE, WOW, HAHA, SAD, ANGRY)
**Current**: Only generic likes_count
**Solution Needed**:
```sql
-- Option A: Separate columns
ALTER TABLE content_item ADD COLUMN reactions JSONB;
-- {"like": 100, "love": 50, "wow": 10, "haha": 5, "sad": 2, "angry": 1}

-- Option B: Separate table
CREATE TABLE content_reaction (
    id UUID PRIMARY KEY,
    content_item_id UUID REFERENCES content_item(id),
    reaction_type TEXT, -- like, love, wow, haha, sad, angry
    count INTEGER,
    created_at TIMESTAMPTZ
);
```

#### 9. **Hashtag/Tag Entities**
**Issue**: Hashtags are tracked per content, but no global hashtag analytics
**Current**: `tags` and `hashtags` arrays in content_item
**Solution Needed**:
```sql
CREATE TABLE hashtag (
    id UUID PRIMARY KEY,
    tag TEXT UNIQUE NOT NULL,
    platform_id UUID REFERENCES platform(id),
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE TABLE content_hashtag (
    content_item_id UUID REFERENCES content_item(id),
    hashtag_id UUID REFERENCES hashtag(id),
    PRIMARY KEY (content_item_id, hashtag_id)
);
```

#### 10. **Metrics History (Time-Series)**
**Issue**: Track metrics over time for trend analysis
**Current**: Only current snapshot in content_item
**Solution Needed**:
```sql
CREATE TABLE content_metrics_snapshot (
    id UUID PRIMARY KEY,
    content_item_id UUID REFERENCES content_item(id),
    views_count INTEGER,
    likes_count INTEGER,
    comments_count INTEGER,
    shares_count INTEGER,
    impressions_count INTEGER,
    reach_count INTEGER,
    snapshot_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ
);

-- Efficient querying with composite index
CREATE INDEX idx_metrics_content_time 
ON content_metrics_snapshot(content_item_id, snapshot_at DESC);
```

---

### Nice to Have Gaps

#### 11. **Platform Categories Mapping**
**Issue**: YouTube category IDs (e.g., 22 = People & Blogs), Instagram categories
**Solution**:
```sql
CREATE TABLE platform_category (
    id UUID PRIMARY KEY,
    platform_id UUID REFERENCES platform(id),
    platform_category_id TEXT,
    name TEXT,
    parent_category_id UUID REFERENCES platform_category(id)
);

ALTER TABLE content_item ADD COLUMN platform_category_id UUID REFERENCES platform_category(id);
```

#### 12. **Scheduled Posts**
**Issue**: Support for scheduled/draft posts
**Solution**:
```sql
ALTER TABLE content_item ADD COLUMN status TEXT DEFAULT 'published';
-- Values: draft, scheduled, published, archived
ALTER TABLE content_item ADD COLUMN scheduled_for TIMESTAMPTZ;
```

#### 13. **Collaborative Content**
**Issue**: Instagram collab posts, TikTok duets with multiple creators
**Solution**:
```sql
CREATE TABLE content_collaborator (
    id UUID PRIMARY KEY,
    content_item_id UUID REFERENCES content_item(id),
    social_account_id UUID REFERENCES social_account(id),
    role TEXT, -- creator, collaborator, featured
    added_at TIMESTAMPTZ
);
```

---

## 📊 Gap Priority Matrix

| Gap | Priority | Impact | Complexity | Platforms Affected |
|-----|----------|--------|------------|-------------------|
| Multiple media per content | 🔴 Critical | High | Low | Instagram, Facebook |
| Platform-specific metrics | 🔴 Critical | High | Low | All |
| Content relationships | 🔴 Critical | High | Medium | Twitter, TikTok |
| Thumbnail variations | 🔴 Critical | Medium | Low | YouTube, Instagram |
| Account type | 🔴 Critical | Medium | Low | Instagram, YouTube |
| Playlists/Collections | 🟡 Important | Medium | Medium | YouTube, Instagram |
| Stories/Ephemeral | 🟡 Important | Medium | Low | Instagram, Facebook |
| Engagement breakdown | 🟡 Important | High | Low | Facebook |
| Hashtag entities | 🟡 Important | Low | Medium | All |
| Metrics history | 🟡 Important | High | High | All |
| Platform categories | 🟢 Nice to Have | Low | Low | YouTube, Instagram |
| Scheduled posts | 🟢 Nice to Have | Medium | Low | All |
| Collaborative content | 🟢 Nice to Have | Low | Low | Instagram, TikTok |

---

## 🎯 My Understanding Summary

### What the Current Schema Does Well:
✅ Core user authentication and management
✅ OAuth connection tracking (Vault-based security)
✅ Basic content syncing structure
✅ Subscription and quota management
✅ AI and SEO integration foundation
✅ Audit logging and notifications

### What Needs Improvement:
❌ Platform-specific features not captured
❌ Rich media support (multiple images/videos per post)
❌ Content relationships (retweets, duets, replies)
❌ Detailed engagement metrics per platform
❌ Time-series analytics data
❌ Ephemeral content handling

### Recommended Approach:
1. **Phase 1** (Critical): Add missing core fields and tables for multi-media, metrics, relationships
2. **Phase 2** (Important): Implement playlists, stories, metrics history
3. **Phase 3** (Nice to Have): Add scheduled posts, categories, collaborators

---

## 💬 Let's Review Together

**Questions for Discussion:**

1. **Multi-Media Strategy**: Should we use a separate `content_media` table or JSONB array for multiple media items?

2. **Platform Metrics**: Should we add specific columns (impressions_count, reach_count) or use flexible JSONB (platform_metrics)?

3. **Time-Series Data**: Do we need metrics history from day 1, or can we add it later?

4. **Playlists**: Priority for YouTube playlists? Should this be in Phase 1?

5. **Ephemeral Content**: How should we handle Instagram stories that auto-delete after 24 hours?

6. **API Quota Tracking**: Should we track API usage per platform to avoid hitting rate limits?

**Collaborative content | 🟢 Nice to Have | Low | Low | Instagram, TikTok |

</details>

---

## 💬 Next Steps - Let's Decide Together

### Critical Decisions Needed:

1. **MVP Platform Mix**: Start with YouTube + Instagram + TikTok (video focus), or include Spotify (audio)?

2. **Multi-Media Table**: Separate `content_media` table or JSONB array in `content_item`?
   - Separate table = better querying, more normalized
   - JSONB = simpler, fewer joins, flexible schema

3. **AI Tag Generation**: Which AI service? OpenAI (GPT-4) vs Claude vs Google Gemini?
   - Cost per content item: ~$0.01-0.05
   - Quality: GPT-4 > Claude > Gemini for tagging
   - Speed: Gemini > Claude > GPT-4

4. **Search Strategy**: PostgreSQL full-text search vs Algolia/Meilisearch/Typesense?
   - PostgreSQL: Free, integrated, good enough for MVP
   - Dedicated search: Better UX, typo tolerance, instant results
   - Cost: $0 vs $1-100/month

5. **Creator Onboarding**: Auto-import all content or let creators select?
   - Auto-import: Faster, but may include unwanted content
   - Selective: Better curation, but slower onboarding

### What I Need From You:

1. **Use Case Priority**: What will users do most?
   - Browse trending content?
   - Search for specific creators?
   - Discover new creators in categories?

2. **Monetization Model**: How will this make money?
   - Freemium (basic free, premium features)?
   - Commission on bookings/collabs?
   - Ads?
   - Just building for fun?

3. **Scale Expectations**: How many creators at launch?
   - <100: MVP scope is perfect
   - 100-1000: Need caching layer
   - >1000: Need CDN, advanced search

4. **Timeline**: When do you want to launch?
   - 1 month: Minimum MVP (3 platforms, basic search)
   - 3 months: Full Phase 1 + AI
   - 6 months: Phase 1 + Phase 2

### Shall We Create the Migration SQL?

Once you answer these questions, I can generate:
1. **Migration SQL** with all Phase 1 schema changes
2. **Updated ER Diagram** with new tables
3. **Edge Functions structure** for OAuth and sync

What are your thoughts? 🚀
