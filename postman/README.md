# StreamVibe Postman Collection

This folder contains Postman collection and environment files for testing the StreamVibe API.

## 📊 Status

- **Collection Version:** 2.0.0
- **Total Requests:** 30
- **Total Phases:** 7
- **Edge Function Coverage:** 100% (23/23) ✅
- **Test Scripts:** 30+ automated validations

## 📁 Files

- **`StreamVibe_API_Collection.postman_collection.json`** - Complete API collection with all endpoints
- **`StreamVibe_Development.postman_environment.json`** - Development environment template
- **`README.md`** - This file

## 🚀 Quick Start

### 1. Import into Postman

**Import Collection:**
1. Open Postman
2. Click **Import**
3. Drag `StreamVibe_API_Collection.postman_collection.json`

**Import Environment:**
1. Click Environments icon (top right)
2. Click **Import**
3. Drag `StreamVibe_Development.postman_environment.json`
4. Select as active environment

### 2. Configure Environment

Set these 3 required variables:

```
base_url = https://your-project-ref.supabase.co
anon_key = your-anon-key
service_role_key = your-service-role-key
```

Get from: [Supabase Dashboard](https://supabase.com/dashboard) → Project → Settings → API

### 3. Run Your First Test

1. Expand **Phase 1: User Onboarding**
2. Click **1.1 Sign Up (Email/Password)**
3. Click **Send** button
4. Check **Test Results** - Should see ✅ 4/4 passed
5. Check environment - `access_token` auto-saved!

## 📊 Collection Structure

### ✅ Phase 1: User Onboarding (4 requests)
- 1.1 Sign Up (Email/Password)
- 1.2 Complete Profile Setup
- 1.3 Get My Profile
- 1.4 Sign In (Existing User)

### ✅ Phase 2: OAuth Connections (8 requests)
- **YouTube OAuth**
  - 2.1 Initialize OAuth
  - 2.2 OAuth Callback (Manual)
  - 2.3 Get YouTube Connection
- **Instagram OAuth**
  - 2.4 Initialize OAuth
  - 2.4b OAuth Callback
- **TikTok OAuth**
  - 2.5 Initialize OAuth
  - 2.5b OAuth Callback

### ✅ Phase 3: Content Sync (4 requests)
- 3.1 Sync YouTube Content
- 3.2 Sync Instagram Content
- 3.3 Sync TikTok Content
- 3.4 Get Synced Content

### ✅ Phase 4: AI Enhancement (2 requests)
- 4.1 Generate AI Tags
- 4.2 Get Content Tags

### ✅ Phase 5: Discovery & Search (9 requests)
- 5.1 Browse Creators
- 5.2 Browse Content
- 5.3 Browse Categories
- 5.4 Get Creator by Slug
- 5.5 Get Content Detail
- 5.6 Get Trending Content
- 5.7 Search Creators
- 5.8 Search Content
- 5.9 Get SEO Metadata

### ✅ Phase 6: Analytics & Tracking (2 requests)
- 6.1 Track Click
- 6.2 Get Content Analytics

### ✅ Phase 7: SEO & Robots (2 requests)
- 7.1 Get Robots.txt
- 7.2 Get Sitemap

## 🧪 Automated Testing

Every request includes test scripts that:
- ✅ Validate status codes
- ✅ Check response structure
- ✅ Verify data persistence
- ✅ Auto-save variables for next requests

**Run all tests:**
```bash
newman run StreamVibe_API_Collection.postman_collection.json \
  -e StreamVibe_Development.postman_environment.json
```

## 📚 Documentation

See [POSTMAN_GUIDE.md](../docs/POSTMAN_GUIDE.md) for:
- Detailed setup instructions
- Complete test coverage report
- Troubleshooting guide
- Best practices
- Contributing guidelines

## 🔐 Security Note

**Never commit environment files with real credentials!**

This repository includes a template environment with placeholders. Create your own:

```bash
cp StreamVibe_Development.postman_environment.json .my-local-env.json
# Edit .my-local-env.json with your real keys
# Add to .gitignore
```

## 📈 Coverage Report

**Complete Endpoint Coverage Achieved! ✅**

- ✅ **30 requests** implemented across 7 phases
- ✅ **100% coverage** - All 23 Edge Functions testable
- ✅ **Automated tests** on every endpoint
- ✅ **Newman CLI** compatible for CI/CD

### All Edge Functions Covered

✅ ai-generate-tags  
✅ auth-profile-setup  
✅ browse-categories  
✅ browse-content  
✅ browse-creators  
✅ get-content-detail  
✅ get-creator-by-slug  
✅ get-seo-metadata  
✅ get-trending  
✅ oauth-instagram-callback  
✅ oauth-instagram-init  
✅ oauth-tiktok-callback  
✅ oauth-tiktok-init  
✅ oauth-youtube-callback  
✅ oauth-youtube-init  
✅ robots  
✅ search-content  
✅ search-creators  
✅ sitemap  
✅ sync-instagram  
✅ sync-tiktok  
✅ sync-youtube  
✅ track-click  

See [../POSTMAN_COVERAGE_REPORT.md](../POSTMAN_COVERAGE_REPORT.md) for detailed analysis.

---

**Last Updated**: November 12, 2025  
**Collection Version**: 2.0.0  
**Status**: ✅ Complete - 100% Coverage
