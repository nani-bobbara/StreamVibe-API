# 🚀 Quick Start: Deploy StreamVibe API in 30 Minutes

**Goal:** Get a production-ready Supabase backend running and testable via Postman.

**What You'll Deploy:**
- ✅ 36-table PostgreSQL database with RLS
- ✅ 24 Edge Functions (REST APIs)
- ✅ OAuth flows (YouTube, Instagram, TikTok)
- ✅ Postman test suite (15 automated requests)

---

## **Prerequisites** (2 minutes)

- [x] **Supabase account** - [Sign up free](https://supabase.com)
- [x] **Supabase CLI** - Install below
- [x] **Postman** - [Download here](https://www.postman.com/downloads/)
- [x] **Terminal** - macOS Terminal, Windows PowerShell, or Linux shell

### Install Supabase CLI

**macOS:**
```bash
brew install supabase/tap/supabase
```

**Windows:**
```bash
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

**Verify:**
```bash
supabase --version  # Should show v2.x.x
```

---

## **Step 1: Create Supabase Project** (3 minutes)

## **Step 1: Create Supabase Project** (3 minutes)

1. Go to **[supabase.com/dashboard](https://supabase.com/dashboard)**
2. Click **"New Project"**
3. Fill in:
   - **Name:** `StreamVibe API`
   - **Database Password:** (generate strong password - **SAVE THIS!**)
   - **Region:** Choose closest to you (e.g., East US)
4. Click **"Create new project"**
5. ⏳ Wait ~2 minutes for provisioning

### Get Your Credentials

Once project is ready:

1. Go to **Settings** → **API**
2. **Copy and save** these values:

```bash
Project URL: https://[project-ref].supabase.co
anon key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
service_role key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

3. Go to **Settings** → **General**  
4. Copy **Reference ID** (e.g., `abcdefghijk`)

> **Save these!** You'll need them for Steps 3 and 6.

---

## **Step 2: Clone & Link Project** (3 minutes)

```bash
# Clone repository (if not already)
cd /path/to/your/projects
git clone <your-repo-url>
cd StreamVibe-API

# Link to your Supabase project
supabase link --project-ref YOUR_PROJECT_REF

# Enter database password when prompted
```

**Expected output:**
```
✔ Enter your database password: ****
Finished supabase link
```

---

## **Step 3: Deploy Database & Functions** (10 minutes)

### Option A: Deploy Everything (Recommended)

```bash
./deploy.sh
```

### Option B: Deploy Separately

```bash
# 1. Deploy database schema
supabase db push

# 2. Deploy Edge Functions
./deploy.sh --skip-migrations
```

**What gets deployed:**
- ✅ Migration 001: 36 tables, 80+ indexes, RLS policies
- ✅ 24 Edge Functions across 7 categories
- ✅ Database functions for quotas, roles, cache

**Expected output:**
```
✔ Applying migration 001_phase1_discovery_platform...
✔ Finished supabase db push

Deploying Edge Functions...
✔ auth-profile-setup deployed
✔ oauth-youtube-init deployed
✔ oauth-youtube-callback deployed
... (21 more functions)
✔ All functions deployed successfully!
```

---

## **Step 4: Verify Deployment** (2 minutes)

### Check Database

```bash
supabase db diff
# Should show: "No schema changes detected"
```

Go to **Supabase Dashboard → Database → Tables**  
You should see 36 tables including:
- `users`, `user_profile`, `subscription`
- `social_account`, `content_item`, `content_media`
- `trending_content`, `featured_creator`
- `content_category`, `content_tag`

### Check Edge Functions

Go to **Supabase Dashboard → Edge Functions**  
You should see 24 functions listed:
- ✅ auth-profile-setup
- ✅ oauth-youtube-init/callback
- ✅ oauth-instagram-init/callback  
- ✅ oauth-tiktok-init/callback
- ✅ sync-youtube, sync-instagram, sync-tiktok
- ✅ browse-creators, browse-content, browse-categories
- ✅ search-creators, search-content
- ✅ get-trending, track-click
- ✅ sitemap, robots, get-seo-metadata

---

## **Step 5: Configure Secrets** (8 minutes)

In **Supabase Dashboard → Project Settings → Edge Functions**:

### Required for Testing (Minimum)

```bash
APP_BASE_URL=https://streamvibe.com
SUPABASE_URL=https://[your-project-ref].supabase.co
```

### Optional: OAuth Credentials

Only add if you want to test OAuth flows (Phase 2):

#### YouTube (Google Cloud Console)
```bash
YOUTUBE_CLIENT_ID=xxx.apps.googleusercontent.com
YOUTUBE_CLIENT_SECRET=GOCSPX-xxx
YOUTUBE_REDIRECT_URI=https://[project-ref].supabase.co/functions/v1/oauth-youtube-callback
```

#### Instagram (Facebook Developers)
```bash
INSTAGRAM_CLIENT_ID=123456789
INSTAGRAM_CLIENT_SECRET=abc123...
INSTAGRAM_REDIRECT_URI=https://[project-ref].supabase.co/functions/v1/oauth-instagram-callback
```

#### TikTok (TikTok Developers)
```bash
TIKTOK_CLIENT_KEY=xxx
TIKTOK_CLIENT_SECRET=xxx
TIKTOK_REDIRECT_URI=https://[project-ref].supabase.co/functions/v1/oauth-tiktok-callback
```

### Optional: AI Features

Only add if you want to test AI tagging:

```bash
OPENAI_API_KEY=sk-proj-xxx
```

> **Can skip OAuth/AI for now** - You can still test Phase 1 (User Onboarding) without any secrets!

---

## **Step 6: Test with Postman** (5 minutes)

### Import Collection

1. Open **Postman**
2. Click **Import** button (top left)
3. Drag these files:
   - `postman/StreamVibe_API_Collection.postman_collection.json`
   - `postman/StreamVibe_Development.postman_environment.json`

### Configure Environment

1. Click **Environments** icon (top right)
2. Select **"StreamVibe Development"**
3. Set these values (from Step 1):

```
base_url = https://[your-project-ref].supabase.co
anon_key = your-anon-key-from-step-1
service_role_key = your-service-role-key-from-step-1
```

4. Click **Save** (Ctrl+S / Cmd+S)

### Run Your First Test

1. Expand **📁 Phase 1: User Onboarding**
2. Click **1.1 Sign Up (Email/Password)**
3. Click blue **Send** button

**Expected Response:**
```json
{
  "access_token": "eyJhbGc...",
  "user": {
    "id": "uuid-here",
    "email": "testuser@example.com",
    "role": "authenticated"
  }
}
```

**Check Test Results:**
- ✅ Status code is 200
- ✅ Response has access_token
- ✅ Response has user.id
- ✅ access_token saved to environment

**All 4 tests should pass!** 🎉

### Run Full Phase 1

Click **📁 Phase 1: User Onboarding** → **Run** button (top right)

Expected results:
```
✅ 1.1 Sign Up - 4/4 tests passed
✅ 1.2 Complete Profile - 3/3 tests passed
✅ 1.3 Get My Profile - 4/4 tests passed
✅ 1.4 Sign In - 4/4 tests passed

Total: 15/15 tests passed ✨
```

---

## **✅ Success! You're Done!**

### What You've Deployed:

- ✅ Production database (36 tables, 80+ indexes)
- ✅ 24 REST API endpoints
- ✅ Row-level security enabled
- ✅ OAuth infrastructure ready
- ✅ Postman tests passing (Phase 1 complete)

### What You Can Do Now:

1. **Test Phase 2 (OAuth)** - If you added OAuth secrets
2. **Test Phase 5 (Discovery)** - Browse public content APIs
3. **Apply Migration 002** - Add async job queue (see below)
4. **Build frontend** - Connect React/Next.js app

---

## **🚀 Next Steps**

### Apply Migration 002 (Async + Webhooks)

**What it adds:**
- Job queue system for async operations
- Stripe webhook infrastructure
- Stripe API caching (90%+ call reduction)

**How to apply:**

1. Read **[docs/MIGRATION_CHECKLIST.md](docs/MIGRATION_CHECKLIST.md)** (pre-flight checks)
2. Open **Supabase Dashboard → SQL Editor**
3. Copy contents of `database/migrations/002_async_job_queue.sql`
4. Paste and run (takes ~10 seconds)
5. Verify: Should see `job_queue`, `job_log`, `stripe_webhook_events` tables

**Full guide:** [docs/ASYNC_ARCHITECTURE.md](docs/ASYNC_ARCHITECTURE.md)

### Test More Endpoints

- **Phase 2: OAuth** - Connect social accounts (requires OAuth secrets)
- **Phase 5: Discovery** - Public content browsing (no auth required)
- **Phase 6: Analytics** - Click tracking

### Build Workers

Next functions to implement:
- `job-processor` - Background worker for async jobs
- `stripe-webhook` - Billing automation
- `job-status` - Job polling API

**Implementation guides:**
- [docs/BACKEND_IMPLEMENTATION.md](docs/BACKEND_IMPLEMENTATION.md)
- [docs/STRIPE_WEBHOOK_INTEGRATION.md](docs/STRIPE_WEBHOOK_INTEGRATION.md)

---

## **🆘 Troubleshooting**

### "Supabase CLI not found"
```bash
# Reinstall
brew uninstall supabase
brew install supabase/tap/supabase
supabase --version
```

### "Failed to link project"
- ✓ Check project ref is correct (Settings → General)
- ✓ Verify database password
- ✓ Ensure project provisioning is complete (green status)

### "Migration failed"
```bash
# Check current state
supabase db remote commit

# Reset and retry
supabase db reset --linked
supabase db push
```

### "Edge Function deployment failed"
```bash
# Deploy specific function
supabase functions deploy auth-profile-setup

# Check logs
supabase functions logs auth-profile-setup --tail
```

### "Postman tests failing"
- ✓ Remove trailing slash from `base_url`
- ✓ Check `anon_key` and `service_role_key` are correct
- ✓ Ensure `access_token` is saved from Sign Up
- ✓ Run requests in order (1.1 → 1.2 → 1.3 → 1.4)
- ✓ Check email format in request body

### "OAuth not working"
- ✓ Verify redirect URI matches exactly (no trailing slash)
- ✓ Check client ID/secret are correct
- ✓ Ensure secrets are set in Edge Functions (not Environment Variables)
- ✓ Check function logs:
  ```bash
  supabase functions logs oauth-youtube-init --tail
  ```

---

## **📚 Additional Resources**

### Documentation
- **[README.md](README.md)** - Project overview + developer onboarding
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design
- **[docs/DATABASE.md](docs/DATABASE.md)** - Schema reference
- **[docs/POSTMAN_GUIDE.md](docs/POSTMAN_GUIDE.md)** - Testing guide

### External Docs
- **[Supabase Docs](https://supabase.com/docs)** - Platform documentation
- **[Postman Learning](https://learning.postman.com)** - API testing tutorials

---

**Deployment Time:** ~30 minutes  
**Difficulty:** Intermediate  
**Status:** ✅ Production Ready (Phase 1)

**Last Updated:** November 8, 2025  
**Version:** 3.2.0

🎉 **You're all set! Happy building!**

In Supabase Dashboard:

1. Go to **Project Settings** → **API**
2. Copy these values:

```bash
# Save these - you'll need them!
Project URL: https://[project-ref].supabase.co
anon key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
service_role key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

3. Go to **Project Settings** → **General**
4. Copy **Reference ID**: `abcdefghijk`

---

## Step 4: Link Project (2 min)

```bash
# Navigate to project directory
cd StreamVibe-API

# Link to your Supabase project
supabase link --project-ref YOUR_PROJECT_REF

# Enter your database password when prompted
```

---

## Step 5: Deploy Database (5 min)

```bash
# Deploy the migration
supabase db push

# You should see:
# Applying migration 001_phase1_discovery_platform...
# ✅ Finished supabase db push.
```

### Verify

```bash
# Check tables were created
supabase db diff
```

You should see tables:
- `content_category`
- `content_tag`
- `content_click`
- `content_media`
- `trending_content`
- `featured_creator`
- Updated `users` and `content_item`

---

## Step 6: Deploy Edge Functions (10 min)

```bash
# Make deployment script executable
chmod +x deploy.sh

# Deploy all Edge Functions
./deploy.sh --skip-migrations
```

You'll see:
```
✅ auth-profile-setup deployed successfully
✅ oauth-youtube-init deployed successfully
✅ oauth-youtube-callback deployed successfully
... (14 functions total)
```

### Verify

Go to Supabase Dashboard → **Edge Functions**

You should see 14 functions listed!

---

## Step 7: Configure Environment Secrets (10 min)

In Supabase Dashboard → **Project Settings** → **Edge Functions**

Click **"Add secret"** and add each:

### OAuth (Get from platform developer consoles)

#### YouTube (Google Cloud Console)
```
YOUTUBE_CLIENT_ID=your-client-id.apps.googleusercontent.com
YOUTUBE_CLIENT_SECRET=GOCSPX-...
YOUTUBE_REDIRECT_URI=https://[project-ref].supabase.co/functions/v1/oauth-youtube-callback
```

#### Instagram (Facebook Developers)
```
INSTAGRAM_CLIENT_ID=123456789
INSTAGRAM_CLIENT_SECRET=abc123...
INSTAGRAM_REDIRECT_URI=https://[project-ref].supabase.co/functions/v1/oauth-instagram-callback
```

#### TikTok (TikTok Developers)
```
TIKTOK_CLIENT_KEY=your-client-key
TIKTOK_CLIENT_SECRET=your-client-secret
TIKTOK_REDIRECT_URI=https://[project-ref].supabase.co/functions/v1/oauth-tiktok-callback
```

### AI
```
OPENAI_API_KEY=sk-proj-...
```

### App
```
APP_BASE_URL=https://streamvibe.com
SUPABASE_URL=https://[project-ref].supabase.co
```

> **Don't have OAuth credentials yet?** Skip for now. You can still test Phase 1 (User Onboarding).

---

## Step 8: Test with Postman (5 min)

### Import Collection

1. Open Postman
2. Click **Import**
3. Drag `postman/StreamVibe_API_Collection.postman_collection.json`
4. Drag `postman/StreamVibe_Development.postman_environment.json`

### Configure Environment

1. Click Environments icon (top right)
2. Select "StreamVibe Development"
3. Set these values:

```
base_url = https://[your-project-ref].supabase.co
anon_key = your-anon-key-from-step-3
service_role_key = your-service-role-key-from-step-3
```

4. Click **Save**

### Run First Test

1. Expand **Phase 1: User Onboarding**
2. Click **1.1 Sign Up (Email/Password)**
3. Click **Send** button

You should see:
```json
{
  "access_token": "eyJhbGc...",
  "user": {
    "id": "uuid-here",
    "email": "testuser@example.com"
  }
}
```

4. Check **Test Results** → Should see ✅ **4/4 passed**

5. Run remaining Phase 1 requests:
   - 1.2 Complete Profile Setup
   - 1.3 Get My Profile  
   - 1.4 Sign In

All tests should pass! 🎉

---

## Step 9: Test OAuth Flow (Optional - 5 min)

If you configured YouTube OAuth:

1. Run **2.1 YouTube - Initialize OAuth**
2. Copy the `authorization_url` from response
3. Paste in browser
4. Sign in with Google
5. Authorize the app
6. You'll be redirected back with success message!

Check Supabase Dashboard → **Database** → `social_account` table → You should see YouTube connection!

---

## Step 10: Setup GitHub Actions (Optional - 10 min)

### Generate Supabase Access Token

1. Go to [supabase.com/dashboard/account/tokens](https://supabase.com/dashboard/account/tokens)
2. Click **"Generate new token"**
3. Name: "GitHub Actions CI/CD"
4. Copy token (shown only once!)

### Add GitHub Secrets

In your GitHub repo:

1. **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Add each secret:

```
SUPABASE_URL = https://[project-ref].supabase.co
SUPABASE_ANON_KEY = your-anon-key
SUPABASE_SERVICE_ROLE_KEY = your-service-role-key
SUPABASE_PROJECT_REF = your-project-ref
SUPABASE_ACCESS_TOKEN = token-from-above
```

### Trigger Workflow

```bash
git add .
git commit -m "Setup CI/CD pipeline"
git push origin main
```

Go to **Actions** tab → Watch workflow run! 🎬

---

## ✅ Verification Checklist

- [ ] Supabase CLI installed and working
- [ ] Project created and linked
- [ ] Database migration deployed (6 new tables)
- [ ] Edge Functions deployed (14 functions)
- [ ] Environment secrets configured
- [ ] Postman collection imported
- [ ] Phase 1 tests passing (4/4)
- [ ] GitHub Actions configured (optional)

---

## 🎊 Success!

Your StreamVibe API is now live!

### What You Can Do Now

1. **Test User Onboarding**: Run Phase 1 in Postman
2. **Connect Platforms**: If you have OAuth, test Phase 2
3. **Import Content**: Test sync functions (Phase 3)
4. **Generate AI Tags**: Test AI enhancement (Phase 4)
5. **Search & Discover**: Test search APIs (Phase 5)
6. **Track Analytics**: Test click tracking (Phase 6)

### Next Steps

1. **Expand Postman Tests**: Add remaining 35 requests
2. **Build Frontend**: Create React/Next.js app
3. **Production Deploy**: Set up custom domain
4. **Monitor**: Set up logging and alerts

---

## 🆘 Troubleshooting

### "Supabase CLI not found"
```bash
# Reinstall
brew uninstall supabase
brew install supabase/tap/supabase
```

### "Failed to link project"
- Check project ref is correct
- Verify database password
- Ensure project provisioning is complete

### "Migration failed"
```bash
# Check what's already applied
supabase db remote commit

# Reset and reapply
supabase db reset --linked
supabase db push
```

### "Edge Function not found"
- Check function name matches folder name
- Verify index.ts exists
- Redeploy specific function:
  ```bash
  supabase functions deploy function-name
  ```

### "Postman tests failing"
- Verify base_url has no trailing slash
- Check anon_key is correct
- Ensure access_token is saved from signup
- Try running requests in order

### "OAuth not working"
- Verify redirect URI matches exactly
- Check client ID/secret are correct
- Ensure secrets are set in Edge Functions settings
- Look at Edge Function logs:
  ```bash
  supabase functions logs oauth-youtube-callback --tail
  ```

---

## 📚 Documentation

- **Backend Guide**: `docs/BACKEND_IMPLEMENTATION.md`
- **Postman Guide**: `docs/POSTMAN_GUIDE.md`
- **CI/CD Setup**: `.github/CI_CD_SETUP.md`
- **Complete Summary**: `IMPLEMENTATION_COMPLETE.md`

---

## 💬 Need Help?

- **Supabase Docs**: https://supabase.com/docs
- **Postman Learning**: https://learning.postman.com
- **GitHub Actions**: https://docs.github.com/actions

---

**Deployment Time**: ~30 minutes  
**Difficulty**: Intermediate  
**Prerequisites**: Supabase account, basic terminal knowledge

🎉 **Happy building!**
