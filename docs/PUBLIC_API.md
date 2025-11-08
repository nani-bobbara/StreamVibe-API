# 🌐 StreamVibe Public API Documentation

## Overview

StreamVibe provides a comprehensive set of **public APIs** that require **no authentication**. These endpoints enable:

- ✅ **Anonymous browsing** of creators and content
- ✅ **Search engine indexing** for SEO
- ✅ **Social media sharing** with Open Graph metadata
- ✅ **Content discovery** without requiring user accounts

## 🔓 Public Endpoints (No Auth Required)

### 1. Browse Creators

**GET** `/browse-creators`

Browse all public creator profiles with filtering and pagination.

**Query Parameters:**
- `category` (optional): Filter by creator category
- `verified_only` (optional): `true` to show only verified creators
- `min_followers` (optional): Minimum follower count
- `sort_by` (optional): `followers` | `recent` | `popular` (default: `followers`)
- `limit` (optional): Items per page, max 100 (default: `50`)
- `offset` (optional): Pagination offset (default: `0`)

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/browse-creators?category=gaming&verified_only=true&limit=20"
```

**Response:**
```json
{
  "success": true,
  "creators": [
    {
      "id": "uuid",
      "display_name": "TechGuru",
      "bio": "Tech reviews and tutorials",
      "avatar_url": "https://...",
      "profile_slug": "techguru",
      "primary_category": "gaming",
      "total_followers_count": 150000,
      "is_verified": true,
      "social_account": [...]
    }
  ],
  "pagination": {
    "total": 245,
    "limit": 20,
    "offset": 0,
    "has_more": true
  }
}
```

**Cache:** 5 minutes

---

### 2. Browse Content

**GET** `/browse-content`

Browse all public content items with filtering and pagination.

**Query Parameters:**
- `category` (optional): Filter by content category
- `platform` (optional): Filter by platform slug (`youtube`, `instagram`, `tiktok`)
- `content_type` (optional): Filter by content type slug
- `creator_slug` (optional): Filter by creator profile slug
- `sort_by` (optional): `recent` | `popular` | `trending` (default: `recent`)
- `limit` (optional): Items per page, max 100 (default: `50`)
- `offset` (optional): Pagination offset (default: `0`)

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/browse-content?platform=youtube&sort_by=popular&limit=30"
```

**Response:**
```json
{
  "success": true,
  "content": [
    {
      "id": "uuid",
      "title": "How to Build a React App",
      "description": "Complete tutorial...",
      "thumbnail_url": "https://...",
      "platform_url": "https://youtube.com/watch?v=...",
      "views_count": 50000,
      "likes_count": 2500,
      "published_at": "2025-11-01T10:00:00Z",
      "platform": {
        "slug": "youtube",
        "display_name": "YouTube"
      },
      "social_account": {
        "user": {
          "display_name": "TechGuru",
          "profile_slug": "techguru",
          "is_verified": true
        }
      }
    }
  ],
  "pagination": {
    "total": 1245,
    "limit": 30,
    "offset": 0,
    "has_more": true
  }
}
```

**Cache:** 3 minutes

---

### 3. Get Content Detail

**GET** `/get-content-detail`

View detailed information about a single content item. Increments view count on each request.

**Query Parameters:**
- `id` (required): Content item UUID

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/get-content-detail?id=123e4567-e89b-12d3-a456-426614174000"
```

**Response:**
```json
{
  "success": true,
  "content": {
    "id": "uuid",
    "title": "How to Build a React App",
    "description": "Complete tutorial covering...",
    "thumbnail_url": "https://...",
    "media_url": "https://...",
    "platform_url": "https://youtube.com/watch?v=...",
    "duration_seconds": 1200,
    "views_count": 50001,
    "likes_count": 2500,
    "comments_count": 150,
    "shares_count": 50,
    "published_at": "2025-11-01T10:00:00Z",
    "category": "technology",
    "tags": ["react", "javascript", "tutorial"],
    "hashtags": ["#ReactJS", "#WebDev"],
    "seo_title": "React App Tutorial - Complete Guide",
    "seo_description": "Learn to build...",
    "platform": {...},
    "content_type": {...},
    "social_account": {
      "user": {
        "display_name": "TechGuru",
        "bio": "Tech educator",
        "profile_slug": "techguru"
      }
    },
    "ai_tags": [
      {
        "tag_name": "web_development",
        "tag_type": "topic",
        "confidence_score": 0.95,
        "source": "ai_generated"
      }
    ],
    "related_content": [...]
  }
}
```

**Cache:** 5 minutes

---

### 4. Browse Categories

**GET** `/browse-categories`

Get all content categories with counts and featured creators.

**Query Parameters:** None

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/browse-categories"
```

**Response:**
```json
{
  "success": true,
  "categories": [
    {
      "name": "Technology",
      "slug": "technology",
      "content_count": 1245,
      "top_creators": [
        {
          "id": "uuid",
          "display_name": "TechGuru",
          "avatar_url": "https://...",
          "profile_slug": "techguru",
          "is_verified": true,
          "total_followers_count": 150000
        }
      ],
      "sample_content": [...]
    }
  ],
  "total_categories": 15
}
```

**Cache:** 10 minutes

---

### 5. Search Creators

**GET** `/search-creators`

Full-text search for creator profiles. Only returns public profiles.

**Query Parameters:**
- `query` (required): Search query string
- `category` (optional): Filter by category
- `verified_only` (optional): `true` for verified creators only
- `limit` (optional): Results per page (default: `20`)
- `offset` (optional): Pagination offset (default: `0`)

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/search-creators?query=tech%20tutorials&verified_only=true"
```

**Response:**
```json
{
  "success": true,
  "results": [...],
  "count": 15,
  "query": "tech tutorials",
  "offset": 0,
  "limit": 20
}
```

---

### 6. Search Content

**GET** `/search-content`

Full-text search for content items. Only returns public content.

**Query Parameters:**
- `query` (required): Search query string
- `category` (optional): Filter by category
- `content_type` (optional): Filter by content type
- `limit` (optional): Results per page (default: `20`)
- `offset` (optional): Pagination offset (default: `0`)

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/search-content?query=react%20tutorial&category=technology"
```

**Response:**
```json
{
  "success": true,
  "results": [...],
  "count": 42,
  "query": "react tutorial",
  "offset": 0,
  "limit": 20
}
```

---

### 7. Get Trending Content

**GET** `/get-trending`

Get trending content ranked by engagement metrics.

**Query Parameters:**
- `category` (optional): `today` | `week` | `month` | `all_time` (default: `today`)
- `limit` (optional): Results to return (default: `20`)

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/get-trending?category=week&limit=10"
```

**Response:**
```json
{
  "success": true,
  "category": "week",
  "results": [
    {
      "id": "uuid",
      "title": "Viral Video Title",
      "trend_score": 0.95,
      "rank": 1,
      "views_count": 250000,
      "likes_count": 15000,
      ...
    }
  ],
  "count": 10
}
```

---

### 8. Get Creator by Slug

**GET** `/get-creator-by-slug`

Get detailed creator profile by slug. Increments profile view count.

**Query Parameters:**
- `slug` (required): Creator profile slug

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/get-creator-by-slug?slug=techguru"
```

**Response:**
```json
{
  "success": true,
  "creator": {
    "id": "uuid",
    "display_name": "TechGuru",
    "bio": "Tech educator and content creator",
    "avatar_url": "https://...",
    "website_url": "https://...",
    "is_verified": true,
    "profile_slug": "techguru",
    "total_followers_count": 150000,
    "profile_views_count": 50001,
    "social_account": [...],
    "recent_content": [...]
  }
}
```

**Cache:** 5 minutes

---

## 🤖 SEO & Crawlers

### 9. Get SEO Metadata

**GET** `/get-seo-metadata`

Get Open Graph and Schema.org metadata for content items and creator profiles.

**Query Parameters:**
- `type` (required): `content` or `creator`
- `id` (optional): UUID (for content items)
- `slug` (optional): Profile slug (for creators)

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/get-seo-metadata?type=content&id=123e4567-e89b-12d3-a456-426614174000"
```

**Response:**
```json
{
  "success": true,
  "seo": {
    "open_graph": {
      "og:type": "video.other",
      "og:title": "How to Build a React App",
      "og:description": "Complete tutorial...",
      "og:image": "https://...",
      "og:url": "https://streamvibe.com/content/123...",
      "twitter:card": "summary_large_image",
      ...
    },
    "schema_org": {
      "@context": "https://schema.org",
      "@type": "VideoObject",
      "name": "How to Build a React App",
      "description": "Complete tutorial...",
      "thumbnailUrl": "https://...",
      "uploadDate": "2025-11-01T10:00:00Z",
      "duration": "PT1200S",
      "interactionStatistic": [...],
      "author": {
        "@type": "Person",
        "name": "TechGuru",
        "url": "https://streamvibe.com/creator/techguru"
      }
    }
  }
}
```

**Cache:** 1 hour

**Use Cases:**
- Generating meta tags for content pages
- Social media preview cards (Facebook, Twitter, LinkedIn)
- Rich search results (Google, Bing)

---

### 10. Sitemap (XML)

**GET** `/sitemap`

Generate XML sitemap for search engine crawlers.

**Query Parameters:** None

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/sitemap"
```

**Response:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://streamvibe.com</loc>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://streamvibe.com/creator/techguru</loc>
    <lastmod>2025-11-07</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://streamvibe.com/content/123...</loc>
    <lastmod>2025-11-01</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.6</priority>
  </url>
  ...
</urlset>
```

**Cache:** 1 hour

**Limits:**
- 5,000 creators
- 10,000 content items

**Update Frequency:**
- Regenerated every hour
- Includes homepage, creator profiles, content items, static pages

---

### 11. Robots.txt

**GET** `/robots`

Serve robots.txt for crawler control.

**Query Parameters:** None

**Example Request:**
```bash
curl "https://your-project.supabase.co/functions/v1/robots"
```

**Response:**
```text
# StreamVibe Robots.txt
User-agent: *
Allow: /
Allow: /creator/*
Allow: /content/*
Allow: /browse/*
Allow: /categories
Allow: /trending
Allow: /search

Disallow: /api/
Disallow: /admin/
Disallow: /dashboard/

Crawl-delay: 1

Sitemap: https://streamvibe.com/sitemap.xml
```

**Cache:** 24 hours

---

## 📊 Response Formats

### Success Response
```json
{
  "success": true,
  "data": {...}
}
```

### Error Response
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

### Common Error Codes
- `NOT_FOUND`: Resource not found or not public (404)
- `BROWSE_ERROR`: Failed to browse resources (500)
- `SEARCH_ERROR`: Search operation failed (500)
- `SEO_METADATA_ERROR`: Failed to generate SEO metadata (500)

---

## 🚀 Integration Examples

### Frontend (React)

```typescript
// Browse creators
const response = await fetch(
  'https://your-project.supabase.co/functions/v1/browse-creators?verified_only=true&limit=20'
)
const { creators } = await response.json()

// Get content detail
const contentResponse = await fetch(
  `https://your-project.supabase.co/functions/v1/get-content-detail?id=${contentId}`
)
const { content } = await contentResponse.json()
```

### SEO Meta Tags (Next.js)

```typescript
export async function generateMetadata({ params }) {
  const res = await fetch(
    `https://your-project.supabase.co/functions/v1/get-seo-metadata?type=content&id=${params.id}`
  )
  const { seo } = await res.json()
  
  return {
    title: seo.open_graph['og:title'],
    description: seo.open_graph['og:description'],
    openGraph: {
      type: seo.open_graph['og:type'],
      images: [seo.open_graph['og:image']],
    },
  }
}
```

### Server-Side Rendering

```html
<!DOCTYPE html>
<html>
<head>
  <!-- Open Graph tags -->
  <meta property="og:title" content="{{og_title}}">
  <meta property="og:description" content="{{og_description}}">
  <meta property="og:image" content="{{og_image}}">
  
  <!-- Schema.org JSON-LD -->
  <script type="application/ld+json">
    {{schema_org_json}}
  </script>
</head>
</html>
```

---

## 🔒 Security Notes

### Public vs Private Content

All public endpoints automatically filter for:
- ✅ `visibility = 'public'`
- ✅ `is_public = true` (for users)
- ✅ `deleted_at IS NULL`

Private/unlisted content is **never** exposed through public APIs.

### Rate Limiting

Recommended rate limits (configure in Supabase):
- **Browse/Search:** 100 requests/minute per IP
- **Detail Views:** 300 requests/minute per IP
- **SEO/Sitemap:** 10 requests/minute per IP

### CORS

All endpoints support CORS with proper headers:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

---

## 🎯 Best Practices

### Pagination
- Always use `limit` and `offset` for large result sets
- Maximum `limit` is 100 to prevent performance issues
- Check `has_more` field to detect more pages

### Caching
- Public endpoints include `Cache-Control` headers
- Implement client-side caching to reduce API calls
- Respect cache durations:
  - Browse: 3-5 minutes
  - Detail: 5 minutes
  - SEO: 1 hour
  - Sitemap: 1 hour

### Search Engine Optimization
1. Add sitemap to `robots.txt` and Google Search Console
2. Use `get-seo-metadata` to generate meta tags dynamically
3. Implement server-side rendering for better indexing
4. Include Schema.org JSON-LD on content pages

### Performance
- Use specific filters to reduce result set size
- Implement infinite scroll instead of large page sizes
- Cache frequently accessed data on CDN
- Monitor function execution times in Supabase dashboard

---

## 📝 Summary

**Total Public Endpoints:** 11

**Categories:**
- 🔍 **Discovery:** browse-creators, browse-content, browse-categories (3)
- 🔎 **Search:** search-creators, search-content, get-trending (3)
- 📄 **Detail Views:** get-content-detail, get-creator-by-slug (2)
- 🤖 **SEO/Crawlers:** get-seo-metadata, sitemap, robots (3)

**Key Features:**
- ✅ No authentication required
- ✅ Automatic public content filtering
- ✅ CORS enabled for all endpoints
- ✅ Built-in caching headers
- ✅ Pagination support
- ✅ SEO-friendly metadata
- ✅ Search engine crawler support

---

**Last Updated:** November 7, 2025  
**API Version:** v1
