# StreamVibe Postman Collection Guide

## 📋 Overview

This Postman collection provides complete API testing for the StreamVibe platform, organized by phases and user flows with automated test scripts.

## 🚀 Quick Start

### 1. Import Collection

1. Open Postman
2. Click **Import** button
3. Select `StreamVibe_API_Collection.postman_collection.json`
4. Collection appears in left sidebar

### 2. Import Environment

1. Click **Environments** (gear icon, top right)
2. Click **Import**
3. Select `StreamVibe_Development.postman_environment.json`
4. Set as active environment

### 3. Configure Environment Variables

Update these values in your environment:

```
base_url = https://[your-project-ref].supabase.co
anon_key = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
service_role_key = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**How to get these values:**
1. Go to [supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - Project URL → `base_url`
   - `anon` `public` key → `anon_key`
   - `service_role` `secret` key → `service_role_key`

### 4. Run First Request

1. Expand **Phase 1: User Onboarding**
2. Click **1.1 Sign Up (Email/Password)**
3. Click **Send**
4. Check **Test Results** tab (should see 4 passed tests ✅)
5. Check environment - `access_token` and `user_id` are now set automatically

---

## 📚 Collection Structure

### Phase 1: User Onboarding (4 requests)
Complete user registration and profile setup.

#### Requests:
1. **1.1 Sign Up** - Create new account
2. **1.2 Complete Profile Setup** - Set display name, bio, avatar
3. **1.3 Get My Profile** - Verify profile data
4. **1.4 Sign In** - Login existing user

#### Automated Tests:
- ✅ Status code validation
- ✅ Response structure validation
- ✅ Data persistence checks
- ✅ Profile slug generation
- ✅ Auto-save tokens to environment

#### Test Scenario:
```
User: test.creator@streamvibe.com
Display Name: Test Gaming Creator
Category: gaming
Expected: Profile at /c/test-gaming-creator
```

---

### Phase 2: Platform Connections (OAuth) (6 requests)

Connect social media accounts via OAuth 2.0.

#### YouTube OAuth Flow:
1. **2.1 Initialize OAuth** - Get authorization URL
2. **Manual Step** - Open URL in browser, grant permissions
3. **2.2 OAuth Callback** - Exchange code for tokens
4. **2.3 Get Connection** - Verify connection created

#### Instagram OAuth Flow:
5. **2.4 Initialize OAuth** - Coming soon
6. **2.5 Callback** - Coming soon

#### Automated Tests:
- ✅ OAuth URL generation
- ✅ State token (CSRF) validation
- ✅ Token exchange success
- ✅ Account connection creation
- ✅ Auto-save social_account_id

#### Manual Steps Required:
OAuth requires browser interaction for user consent:
1. Run Initialize request
2. Copy `authorization_url` from response
3. Open in browser
4. Log into Google/Instagram/TikTok
5. Grant permissions
6. Copy `code` from redirect URL
7. Paste into Callback request

---

### Phase 3: Content Sync (Coming Soon)

Pull metadata from connected platforms.

#### Planned Requests:
- **3.1 Sync YouTube Content** - Fetch videos metadata
- **3.2 Sync Instagram Content** - Fetch posts metadata
- **3.3 Sync TikTok Content** - Fetch videos metadata
- **3.4 Get Synced Content** - View imported content
- **3.5 Sync All Platforms** - Batch sync

---

### Phase 4: AI Enhancement (Coming Soon)

Generate tags and optimize descriptions.

#### Planned Requests:
- **4.1 Generate AI Tags** - OpenAI GPT-4 tag generation
- **4.2 Enhance Description** - SEO-optimized descriptions
- **4.3 Auto-Categorize** - Content category detection
- **4.4 Get Content Tags** - View generated tags

---

### Phase 5: Discovery & Search (Coming Soon)

Search creators and content.

#### Planned Requests:
- **5.1 Search Creators** - Full-text creator search
- **5.2 Search Content** - Full-text content search
- **5.3 Get Trending** - Trending content algorithm
- **5.4 Get Featured Creators** - Curated creators
- **5.5 Browse by Category** - Filter by genre

---

### Phase 6: Analytics & Tracking (Coming Soon)

Click tracking and performance metrics.

#### Planned Requests:
- **6.1 Track Click** - Log content click
- **6.2 Track Profile View** - Log profile view
- **6.3 Get Content Analytics** - Click stats per content
- **6.4 Get Profile Analytics** - Views, clicks, referrers
- **6.5 Get Top Content** - Best performing content

---

## 🧪 Automated Testing Features

### Test Scripts
Every request includes automated test scripts that:
- ✅ Validate HTTP status codes
- ✅ Check response structure
- ✅ Verify data types
- ✅ Test business logic
- ✅ Auto-save variables for next requests

### Example Test Script:
```javascript
// Validate status
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

// Validate response structure
const response = pm.response.json();
pm.test("Response contains required fields", function () {
    pm.expect(response).to.have.property('success');
    pm.expect(response.success).to.be.true;
});

// Auto-save for next request
if (response.user_id) {
    pm.environment.set('user_id', response.user_id);
    console.log('✅ Saved user_id:', response.user_id);
}
```

### Test Results
After each request, check the **Test Results** tab:
- ✅ Green = Passed
- ❌ Red = Failed (with error details)

---

## 🔄 Running Full Test Suite

### Option A: Collection Runner
Run all requests in sequence:

1. Click **...** next to collection name
2. Select **Run collection**
3. Configure:
   - Environment: StreamVibe - Development
   - Iterations: 1
   - Delay: 1000ms (between requests)
4. Click **Run StreamVibe API**
5. Watch tests execute automatically
6. View summary report

### Option B: Newman CLI
Automate testing with command line:

```bash
# Install Newman
npm install -g newman

# Run collection
newman run StreamVibe_API_Collection.postman_collection.json \
  -e StreamVibe_Development.postman_environment.json \
  --delay-request 1000

# Generate HTML report
newman run StreamVibe_API_Collection.postman_collection.json \
  -e StreamVibe_Development.postman_environment.json \
  --reporters cli,html \
  --reporter-html-export report.html
```

### Option C: CI/CD Integration
Add to GitHub Actions:

```yaml
# .github/workflows/api-test.yml
name: API Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Newman
        run: npm install -g newman
      
      - name: Run API Tests
        run: |
          newman run postman/StreamVibe_API_Collection.postman_collection.json \
            -e postman/StreamVibe_Development.postman_environment.json \
            --env-var "base_url=${{ secrets.SUPABASE_URL }}" \
            --env-var "anon_key=${{ secrets.SUPABASE_ANON_KEY }}"
```

---

## 📊 Environment Variables Reference

### Configuration (Set Manually)
| Variable | Description | Example |
|----------|-------------|---------|
| `base_url` | Supabase project URL | `https://abc123.supabase.co` |
| `anon_key` | Supabase public anon key | `eyJhbGc...` |
| `service_role_key` | Supabase service role key | `eyJhbGc...` |

### Session Data (Auto-populated)
| Variable | Set By | Used By |
|----------|--------|---------|
| `access_token` | 1.1 Sign Up, 1.4 Sign In | All authenticated requests |
| `user_id` | 1.1 Sign Up | 1.3 Get Profile, 2.x OAuth |
| `user_email` | 1.1 Sign Up | 1.4 Sign In |
| `profile_slug` | 1.2 Profile Setup | Display, frontend routing |
| `display_name` | 1.2 Profile Setup | Display purposes |

### OAuth Data (Auto-populated)
| Variable | Set By | Used By |
|----------|--------|---------|
| `youtube_oauth_state` | 2.1 YouTube Init | 2.2 YouTube Callback |
| `youtube_social_account_id` | 2.2 YouTube Callback | 3.1 Sync YouTube |
| `instagram_oauth_state` | 2.4 Instagram Init | 2.5 Instagram Callback |
| `instagram_social_account_id` | 2.5 Instagram Callback | 3.2 Sync Instagram |

### Content Data (Auto-populated)
| Variable | Set By | Used By |
|----------|--------|---------|
| `content_id` | 3.x Sync requests | 4.1 AI Tags, 6.1 Track Click |
| `test_content_title` | 3.x Sync requests | Search validation |

---

## 🛠️ Troubleshooting

### Issue: 401 Unauthorized

**Cause**: Missing or expired `access_token`

**Solution**:
1. Run **1.4 Sign In** to get fresh token
2. Check environment has `access_token` set
3. Verify token hasn't expired (1 hour default)

---

### Issue: 404 Not Found on Edge Function

**Cause**: Edge Function not deployed

**Solution**:
```bash
# Deploy specific function
supabase functions deploy auth-profile-setup

# Or deploy all
supabase functions deploy
```

---

### Issue: OAuth Code Already Used

**Cause**: Authorization code can only be used once

**Solution**:
1. Run **2.1 Initialize OAuth** again (generates new state)
2. Open new authorization URL in browser
3. Get fresh code
4. Use in **2.2 Callback**

---

### Issue: CORS Error in Browser

**Cause**: Missing CORS headers in Edge Function

**Solution**:
Edge Functions must include CORS headers:
```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
}

// Return with headers
return new Response(JSON.stringify(data), {
  headers: { ...corsHeaders, 'Content-Type': 'application/json' }
})
```

---

### Issue: Test Fails with "Cannot read property"

**Cause**: Response structure different than expected

**Solution**:
1. Check **Response** tab to see actual response
2. Compare with expected structure in test script
3. Update test script or fix API endpoint

---

## 📝 Best Practices

### 1. Use Environments
Create separate environments for:
- **Development** - Local Supabase or dev project
- **Staging** - Pre-production testing
- **Production** - Live API (read-only tests only!)

### 2. Never Commit Secrets
Add to `.gitignore`:
```
*.postman_environment.json
```

Share sanitized environment template instead.

### 3. Run Tests Before Commits
```bash
# Add to pre-commit hook
newman run postman/StreamVibe_API_Collection.postman_collection.json \
  -e postman/StreamVibe_Development.postman_environment.json
```

### 4. Document Manual Steps
OAuth flows require browser interaction - document clearly:
- Which URL to open
- What permissions to grant
- Where to find the code
- How to use it in next request

### 5. Use Variables for Everything
Never hardcode:
- ❌ `https://abc123.supabase.co/...`
- ✅ `{{base_url}}/...`

This makes collection portable and maintainable.

---

## 🚦 Test Coverage Status

### Phase 1: User Onboarding
- ✅ Sign Up - 4 automated tests
- ✅ Profile Setup - 6 automated tests
- ✅ Get Profile - 3 automated tests
- ✅ Sign In - 2 automated tests
- **Coverage: 100%**

### Phase 2: OAuth
- ✅ YouTube Init - 3 automated tests
- ⚠️ YouTube Callback - Manual step required
- ✅ YouTube Verify - 2 automated tests
- ⏳ Instagram - Coming soon
- ⏳ TikTok - Coming soon
- **Coverage: 33%**

### Phase 3-6
- ⏳ Content Sync - 0%
- ⏳ AI Enhancement - 0%
- ⏳ Discovery - 0%
- ⏳ Analytics - 0%

**Overall Coverage: 15/50 requests (30%)**

---

## 📚 Additional Resources

### Postman Learning Center
- [Writing Tests](https://learning.postman.com/docs/writing-scripts/test-scripts/)
- [Using Variables](https://learning.postman.com/docs/sending-requests/variables/)
- [Running Collections](https://learning.postman.com/docs/running-collections/intro-to-collection-runs/)

### Supabase Docs
- [Edge Functions](https://supabase.com/docs/guides/functions)
- [Auth API](https://supabase.com/docs/reference/javascript/auth-signup)
- [PostgREST API](https://supabase.com/docs/guides/api)

### OAuth 2.0
- [Google OAuth](https://developers.google.com/identity/protocols/oauth2)
- [Instagram OAuth](https://developers.facebook.com/docs/instagram-basic-display-api)
- [TikTok OAuth](https://developers.tiktok.com/doc/login-kit-web)

---

## 🤝 Contributing

### Adding New Requests

1. **Create request in appropriate phase folder**
2. **Add detailed description** with:
   - Purpose
   - Required parameters
   - Expected response
   - Error cases
3. **Write automated tests**:
   - Status code validation
   - Response structure checks
   - Data persistence tests
   - Environment variable updates
4. **Document manual steps** (if any)
5. **Update this README** with new request

### Test Script Template
```javascript
// Test: Status code
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

// Parse response
const response = pm.response.json();

// Test: Success flag
pm.test("Response success is true", function () {
    pm.expect(response.success).to.be.true;
});

// Test: Required fields
pm.test("Response has required fields", function () {
    pm.expect(response).to.have.property('data');
    // Add more specific checks
});

// Save to environment
if (response.id) {
    pm.environment.set('resource_id', response.id);
    console.log('✅ Saved resource_id:', response.id);
}

// Log useful info
console.log('Response:', JSON.stringify(response, null, 2));
```

---

## 📞 Support

### Issues?
1. Check **Test Results** tab for specific error
2. Review **Console** tab for logs
3. Verify environment variables are set
4. Check Edge Function is deployed
5. Review database migration ran successfully

### Questions?
Open an issue on GitHub with:
- Request name
- Error message
- Environment (dev/staging/prod)
- Screenshots of Test Results

---

**Last Updated**: November 7, 2025  
**Version**: 1.0.0 - Phase 1 Complete  
**Status**: 30% Coverage (15/50 requests)
