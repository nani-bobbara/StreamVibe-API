# StreamVibe Postman Collection

This folder contains Postman collection and environment files for testing the StreamVibe API.

## 📁 Files

- **`StreamVibe_API_Collection.postman_collection.json`** - Complete API collection with all endpoints
- **`StreamVibe_Development.postman_environment.json`** - Development environment template

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

### ✅ Phase 1: User Onboarding (COMPLETE)
- 1.1 Sign Up
- 1.2 Complete Profile Setup
- 1.3 Get My Profile
- 1.4 Sign In

### 🔄 Phase 2: OAuth Connections (PARTIAL)
- 2.1 YouTube - Initialize OAuth
- 2.2 YouTube - OAuth Callback
- 2.3 YouTube - Get Connection
- 2.4 Instagram - Initialize OAuth (Coming Soon)
- 2.5 TikTok - Initialize OAuth (Coming Soon)

### ⏳ Phase 3-6 (COMING SOON)
- Phase 3: Content Sync
- Phase 4: AI Enhancement
- Phase 5: Discovery & Search
- Phase 6: Analytics & Tracking

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

## 📈 Current Status

- ✅ **15 requests** implemented
- ✅ **30% coverage** (Phase 1 + partial Phase 2)
- ✅ **Automated tests** on all implemented endpoints
- ⏳ **35 requests** planned for Phases 3-6

## 🚀 Next Steps

1. **Implement Phase 2 OAuth** - Instagram, TikTok flows
2. **Build Phase 3 Content Sync** - Metadata import endpoints
3. **Add Phase 4 AI** - Tag generation, SEO optimization
4. **Create Phase 5 Discovery** - Search APIs
5. **Finish Phase 6 Analytics** - Click tracking

---

**Last Updated**: November 7, 2025
