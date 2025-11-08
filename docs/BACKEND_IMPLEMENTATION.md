# StreamVibe Backend Implementation Guide

## 📋 Overview

This document provides a complete guide to building the StreamVibe Supabase backend, from database migration to API implementation and testing.

## 🗂️ Project Status

### ✅ Phase 1: Database Schema (COMPLETE)
- [x] Migration SQL created (`001_phase1_discovery_platform.sql`)
- [x] Rollback script created
- [x] 6 new tables added
- [x] Extended users and content_item tables
- [x] Full-text search vectors
- [x] Click tracking infrastructure
- [x] AI tags support
- [x] Trending algorithm

### 🔄 Phase 2: Edge Functions (IN PROGRESS)
- [x] Folder structure created
- [x] Shared utilities (_shared/)
- [x] Profile setup function
- [x] YouTube OAuth init
- [ ] YouTube OAuth callback
- [ ] Instagram OAuth (init + callback)
- [ ] TikTok OAuth (init + callback)
- [ ] Content sync functions
- [ ] AI tag generation
- [ ] Click tracking
- [ ] Search APIs

### 📮 Phase 3: Testing & Documentation (PENDING)
- [ ] Postman collection
- [ ] API documentation
- [ ] User flow diagrams
- [ ] Deployment guide

---

## 🚀 Getting Started

### Prerequisites

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Install Deno (for local testing)
brew install deno

# Install PostgreSQL client (for migrations)
brew install postgresql
```

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Note down:
   - Project URL
   - API Keys (anon, service_role)
   - Database password

### 2. Link Local Project

```bash
cd /path/to/StreamVibe-API
supabase login
supabase link --project-ref <your-project-ref>
```

### 3. Run Database Migration

```bash
# Option A: Using Supabase CLI
supabase db push

# Option B: Manual SQL execution
psql postgresql://postgres:[password]@[host]:5432/postgres \
  -f database/migrations/001_phase1_discovery_platform.sql
```

### 4. Set Environment Secrets

```bash
# YouTube OAuth
supabase secrets set YOUTUBE_CLIENT_ID="your_client_id"
supabase secrets set YOUTUBE_CLIENT_SECRET="your_secret"
supabase secrets set YOUTUBE_REDIRECT_URI="https://[project-ref].supabase.co/functions/v1/oauth-youtube-callback"

# Instagram OAuth
supabase secrets set INSTAGRAM_CLIENT_ID="your_client_id"
supabase secrets set INSTAGRAM_CLIENT_SECRET="your_secret"

# TikTok OAuth
supabase secrets set TIKTOK_CLIENT_KEY="your_key"
supabase secrets set TIKTOK_CLIENT_SECRET="your_secret"

# OpenAI API
supabase secrets set OPENAI_API_KEY="sk-your-key"

# App URLs
supabase secrets set APP_BASE_URL="https://streamvibe.com"
```

### 5. Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy

# Or deploy individually
supabase functions deploy auth-profile-setup
supabase functions deploy oauth-youtube-init
```

---

## 📖 Complete User Flows

### Flow 1: User Signup & Profile Setup

**Step 1: Create Account**
```bash
# Using Supabase Auth
POST https://[project-ref].supabase.co/auth/v1/signup
Content-Type: application/json

{
  "email": "creator@example.com",
  "password": "securepassword123",
  "data": {
    "display_name": "Gaming Creator"
  }
}

# Response
{
  "access_token": "eyJ...",
  "user": {
    "id": "uuid",
    "email": "creator@example.com"
  }
}
```

**Step 2: Complete Profile**
```bash
POST https://[project-ref].supabase.co/functions/v1/auth-profile-setup
Authorization: Bearer [access_token]
Content-Type: application/json

{
  "display_name": "Gaming Creator",
  "bio": "Professional gamer and content creator",
  "avatar_url": "https://example.com/avatar.jpg",
  "primary_category": "gaming",
  "website_url": "https://gamingcreator.com",
  "location": "Los Angeles, CA"
}

# Response
{
  "success": true,
  "profile": {
    "user_id": "uuid",
    "display_name": "Gaming Creator",
    "profile_slug": "gaming-creator",
    "profile_url": "https://streamvibe.com/c/gaming-creator"
  }
}
```

---

### Flow 2: Connect YouTube Account

**Step 1: Initialize OAuth**
```bash
GET https://[project-ref].supabase.co/functions/v1/oauth-youtube-init
Authorization: Bearer [access_token]

# Response
{
  "success": true,
  "authorization_url": "https://accounts.google.com/o/oauth2/v2/auth?client_id=...",
  "state": "csrf-token-uuid"
}
```

**Step 2: User Authorizes (Browser)**
- User clicks authorization_url
- Logs into Google
- Grants YouTube permissions
- Redirected to callback URL

**Step 3: OAuth Callback (Automatic)**
```bash
GET https://[project-ref].supabase.co/functions/v1/oauth-youtube-callback?code=xxx&state=csrf-token

# Backend actions:
# 1. Verify state (CSRF protection)
# 2. Exchange code for tokens
# 3. Store tokens in Vault (encrypted)
# 4. Create platform_connection record
# 5. Fetch YouTube channel info
# 6. Create social_account record
# 7. Trigger initial content sync

# Response (redirect to frontend)
Location: https://streamvibe.com/dashboard?youtube=connected
```

**Step 4: Verify Connection**
```bash
GET https://[project-ref].supabase.co/rest/v1/social_account?user_id=eq.[user_id]
Authorization: Bearer [access_token]
apikey: [anon_key]

# Response
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "platform_id": "youtube-platform-uuid",
    "account_username": "GamingCreator",
    "account_display_name": "Gaming Creator Official",
    "followers_count": 125000,
    "is_active": true,
    "last_synced_at": "2025-11-07T10:00:00Z"
  }
]
```

---

### Flow 3: Content Sync (Automatic)

**Nightly Sync Job**
```bash
# Triggered by pg_cron or manual API call
POST https://[project-ref].supabase.co/functions/v1/sync-youtube
Authorization: Bearer [access_token]
Content-Type: application/json

{
  "social_account_id": "uuid",
  "force_full_sync": false
}

# Backend actions:
# 1. Get OAuth tokens from Vault
# 2. Call YouTube Data API v3
#    - channels.list (channel info)
#    - search.list (videos)
#    - videos.list (video details)
# 3. For each video:
#    - Upsert content_item
#    - Extract hashtags
#    - Store thumbnail URL
#    - Update view/like counts
# 4. Trigger AI tag generation (async)

# Response
{
  "success": true,
  "synced_count": 47,
  "new_count": 5,
  "updated_count": 42,
  "errors": []
}
```

---

### Flow 4: AI Tag Generation

**Automatic After Sync**
```bash
POST https://[project-ref].supabase.co/functions/v1/ai-generate-tags
Authorization: Bearer [service_role_key]
Content-Type: application/json

{
  "content_id": "uuid"
}

# Backend actions:
# 1. Get content title + description
# 2. Call OpenAI GPT-4 API:
#    - Generate searchable keywords
#    - Extract topics/entities
#    - Detect emotions/trends
#    - Improve SEO description
# 3. Store in content_tag table
# 4. Update content_item.ai_description

# Response
{
  "success": true,
  "tags": [
    {
      "tag": "minecraft",
      "confidence_score": 0.95,
      "tag_type": "keyword"
    },
    {
      "tag": "gaming tutorial",
      "confidence_score": 0.89,
      "tag_type": "topic"
    },
    {
      "tag": "beginner friendly",
      "confidence_score": 0.78,
      "tag_type": "emotion"
    }
  ],
  "ai_description": "Complete Minecraft survival guide for beginners..."
}
```

---

### Flow 5: Search & Discovery

**Search Creators**
```bash
GET https://[project-ref].supabase.co/functions/v1/search-creators?q=gaming&category=gaming&limit=20
Authorization: Bearer [anon_key]

# Response
{
  "success": true,
  "results": [
    {
      "user_id": "uuid",
      "display_name": "Gaming Creator",
      "bio": "Professional gamer...",
      "avatar_url": "...",
      "profile_slug": "gaming-creator",
      "primary_category": "gaming",
      "total_followers_count": 125000,
      "is_verified": true
    }
  ],
  "total": 47
}
```

**Search Content**
```bash
GET https://[project-ref].supabase.co/functions/v1/search-content?q=minecraft+tutorial&category=gaming&limit=20

# Response
{
  "success": true,
  "results": [
    {
      "id": "uuid",
      "title": "Minecraft Survival Guide - Day 1",
      "description": "Complete beginner tutorial...",
      "thumbnail_url": "...",
      "creator": {
        "display_name": "Gaming Creator",
        "profile_slug": "gaming-creator",
        "avatar_url": "..."
      },
      "platform": "youtube",
      "views_count": 54231,
      "published_at": "2025-11-01T12:00:00Z",
      "category": "gaming"
    }
  ],
  "total": 234
}
```

**Get Trending**
```bash
GET https://[project-ref].supabase.co/functions/v1/trending?period=week&category=gaming&limit=10

# Response
{
  "success": true,
  "trending": [
    {
      "content_id": "uuid",
      "title": "...",
      "trend_score": 87.5,
      "rank_position": 1,
      "views_count": 125000,
      "total_clicks": 3421
    }
  ]
}
```

---

### Flow 6: Click Tracking

**User Clicks Content**
```bash
GET https://[project-ref].supabase.co/functions/v1/track-click/[content_id]?ref=search
# No auth required (anonymous tracking)

# Backend actions:
# 1. Log click in content_click table
# 2. Increment content_item counters
# 3. Increment user profile_clicks_count
# 4. Get original platform URL
# 5. Redirect to original platform

# Response (302 redirect)
Location: https://youtube.com/watch?v=abc123
```

---

## 🔑 API Authentication

### Public Endpoints (No Auth)
- `/trending`
- `/search-creators`
- `/search-content`
- `/track-click/:id`

### Authenticated Endpoints (Bearer Token)
- `/auth-profile-setup`
- `/oauth-*-init`
- `/sync-*`

### Service Role Endpoints (Backend Only)
- `/ai-generate-tags`
- Admin functions

### Getting Auth Token

```bash
# Login
POST https://[project-ref].supabase.co/auth/v1/token?grant_type=password
Content-Type: application/json
apikey: [anon_key]

{
  "email": "user@example.com",
  "password": "password123"
}

# Response
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "..."
}
```

---

## 📊 Database Schema Reference

### Key Tables

**users** (extended)
```sql
SELECT 
  id,
  email,
  display_name,
  bio,
  avatar_url,
  profile_slug,         -- URL: /c/{slug}
  primary_category,     -- gaming, music, etc.
  total_followers_count,
  profile_views_count,
  profile_clicks_count,
  is_verified,
  is_public
FROM users;
```

**content_item** (extended)
```sql
SELECT 
  id,
  title,
  description,
  ai_description,       -- AI-enhanced
  media_url,            -- YouTube/Instagram URL
  thumbnail_url,
  category_code,        -- gaming, music, etc.
  total_clicks,
  clicks_last_7_days,
  seo_title,
  seo_description
FROM content_item;
```

**content_tag** (new)
```sql
SELECT 
  content_id,
  tag,                  -- 'minecraft'
  source,               -- ai_generated, platform_original
  confidence_score,     -- 0.95
  tag_type              -- keyword, topic, entity
FROM content_tag;
```

**content_click** (new)
```sql
SELECT 
  content_id,
  user_id,              -- NULL if anonymous
  clicked_at,
  referrer,             -- google, twitter, direct
  user_agent,
  country_code
FROM content_click;
```

---

## 🧪 Testing Checklist

### Database Tests
- [ ] Run migration successfully
- [ ] Verify all tables created
- [ ] Test RLS policies
- [ ] Test helper functions
- [ ] Verify indexes exist

### API Tests
- [ ] User signup
- [ ] Profile setup
- [ ] YouTube OAuth flow
- [ ] Content sync
- [ ] AI tag generation
- [ ] Search creators
- [ ] Search content
- [ ] Click tracking

### Performance Tests
- [ ] Full-text search speed
- [ ] Content sync for 1000+ videos
- [ ] Click tracking under load
- [ ] Trending algorithm execution time

---

## 🐛 Common Issues & Solutions

### Issue: Migration fails
```bash
# Check PostgreSQL version
psql $DATABASE_URL -c "SELECT version();"
# Requires PostgreSQL 15+

# Check extensions
psql $DATABASE_URL -c "\dx"
# Requires: uuid-ossp, pgcrypto, pg_cron, pgsodium
```

### Issue: OAuth redirect not working
```bash
# Verify redirect URI matches exactly
# In Google/Instagram/TikTok console AND environment variable

# Check:
supabase secrets list | grep REDIRECT_URI
```

### Issue: Full-text search not working
```bash
# Rebuild search vectors
UPDATE users SET updated_at = NOW();
UPDATE content_item SET updated_at = NOW();
# Triggers regenerate search_vector (GENERATED ALWAYS)
```

---

## 📚 Next Steps

1. Complete remaining OAuth functions (Instagram, TikTok)
2. Implement content sync functions
3. Build AI tag generation
4. Create Postman collection
5. Write comprehensive API docs
6. Deploy to production
7. Set up monitoring & alerts

---

## 🤝 Contributing

When adding new Edge Functions:
1. Follow naming convention: `[category]-[action]`
2. Use shared utilities from `_shared/`
3. Add proper error handling
4. Include TypeScript types
5. Update this README

---

**Last Updated**: November 7, 2025
**Version**: Phase 1 - MVP
