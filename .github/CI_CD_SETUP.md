# CI/CD Setup Guide

This guide explains how to set up continuous integration and deployment for the StreamVibe API.

## Overview

The CI/CD pipeline automates:
1. **Testing**: Runs Postman collection tests on every push/PR
2. **Deployment**: Deploys database migrations and Edge Functions to Supabase on main branch

## GitHub Actions Workflow

### Triggers

The workflow runs on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual dispatch (Actions tab → "Run workflow")

### Jobs

#### 1. Test Job
- Installs Newman (Postman CLI)
- Creates environment with Supabase credentials
- Runs complete Postman collection
- Generates HTML test report
- Uploads test results as artifacts
- Comments on PR with test summary

#### 2. Deploy Job (main branch only)
- Installs Supabase CLI
- Links to Supabase project
- Deploys database migrations
- Deploys all Edge Functions
- Creates deployment summary

## Required GitHub Secrets

Configure these secrets in: **Settings → Secrets and variables → Actions → New repository secret**

### Supabase Secrets

```
SUPABASE_URL
  Description: Your Supabase project URL
  Example: https://abcdefghijk.supabase.co
  Where to find: Supabase Dashboard → Project Settings → API

SUPABASE_ANON_KEY
  Description: Anonymous (public) API key
  Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  Where to find: Supabase Dashboard → Project Settings → API

SUPABASE_SERVICE_ROLE_KEY
  Description: Service role (private) API key
  Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  Where to find: Supabase Dashboard → Project Settings → API → service_role key (secret)
  ⚠️ Keep this secret! Has full database access

SUPABASE_PROJECT_REF
  Description: Project reference ID
  Example: abcdefghijk
  Where to find: Supabase Dashboard → Project Settings → General → Reference ID

SUPABASE_ACCESS_TOKEN
  Description: Personal access token for Supabase CLI
  How to generate:
    1. Go to https://supabase.com/dashboard/account/tokens
    2. Click "Generate new token"
    3. Give it a name (e.g., "GitHub Actions")
    4. Copy the token
  ⚠️ Save immediately - shown only once!
```

## Setup Steps

### 1. Generate Supabase Access Token

```bash
# Visit https://supabase.com/dashboard/account/tokens
# Click "Generate new token"
# Name it "GitHub Actions CI/CD"
# Copy the token (you'll need it for GitHub Secrets)
```

### 2. Add GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add each secret from the list above

### 3. Verify Workflow File

The workflow file is located at:
```
.github/workflows/test-and-deploy.yml
```

### 4. Test the Workflow

#### Option A: Push a commit
```bash
git add .
git commit -m "Test CI/CD pipeline"
git push origin main
```

#### Option B: Manual trigger
1. Go to **Actions** tab in GitHub
2. Select **API Testing with Postman** workflow
3. Click **Run workflow**
4. Select branch
5. Click **Run workflow** button

## Viewing Results

### Test Results

1. Go to **Actions** tab
2. Click on the workflow run
3. Click on **postman-test-results** artifact to download HTML report
4. Open `report.html` in browser

### Deployment Logs

1. Go to **Actions** tab
2. Click on the workflow run
3. Click on **Deploy to Supabase** job
4. Expand steps to see deployment logs

### Pull Request Comments

When you create a PR, the bot will automatically comment with:
- ✅/❌ Test status
- Number of passed/failed tests
- Link to full report

Example:
```
## 🧪 Postman API Test Results

**Status:** ✅ Passed

- ✅ Passed: 15
- ❌ Failed: 0

📊 [View Full Report](...)
```

## Manual Deployment

If you need to deploy manually:

### Using the Script

```bash
# Deploy everything
./deploy.sh

# Deploy only migrations
./deploy.sh --skip-functions

# Deploy only functions
./deploy.sh --skip-migrations

# Dry run (preview changes)
./deploy.sh --dry-run
```

### Using Supabase CLI

```bash
# Link project (first time only)
supabase link --project-ref YOUR_PROJECT_REF

# Deploy migrations
supabase db push

# Deploy specific function
supabase functions deploy auth-profile-setup

# Deploy all functions
supabase functions deploy
```

## Troubleshooting

### Workflow fails with "Supabase CLI not found"

**Solution:** The `supabase/setup-cli@v1` action should handle this. If it fails, update the action version in `.github/workflows/test-and-deploy.yml`.

### Tests fail with "Connection refused"

**Solution:** Check that `SUPABASE_URL` secret is correct and doesn't have trailing slash.

### Deployment fails with "Project not linked"

**Solution:** Verify `SUPABASE_PROJECT_REF` and `SUPABASE_ACCESS_TOKEN` secrets are set correctly.

### Edge Functions deploy but show "Not found" errors

**Solution:** Check Edge Function secrets are set in Supabase Dashboard:
1. Go to **Project Settings** → **Edge Functions**
2. Add required secrets (YOUTUBE_CLIENT_ID, OPENAI_API_KEY, etc.)

### Newman test timeout

**Solution:** Increase timeout in workflow file:
```yaml
--timeout-request 30000  # Change to 60000 for 60 seconds
```

## Best Practices

### Branch Protection

Protect your main branch:
1. **Settings** → **Branches** → **Add rule**
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date
   - Select: "Run Postman Tests"

This prevents merging PRs with failing tests.

### Environment Variables

Never commit real credentials! The workflow creates environment files dynamically from secrets.

Bad ❌:
```json
{
  "anon_key": "eyJhbGciOiJIUz..."  // Don't commit this!
}
```

Good ✅:
```yaml
"value": "${{ secrets.SUPABASE_ANON_KEY }}"  // Read from secrets
```

### Notifications

Get Slack notifications on deployment:
```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Monitoring

### Supabase Logs

```bash
# Stream Edge Function logs
supabase functions logs --tail

# Specific function
supabase functions logs auth-profile-setup --tail

# Database logs
supabase db inspect
```

### GitHub Actions Insights

View workflow performance:
1. **Actions** tab
2. **Insights** (left sidebar)
3. See success rate, duration, trends

## Cost Optimization

### Reduce API Calls

Run tests only on specific paths:
```yaml
on:
  push:
    paths:
      - 'supabase/**'
      - 'postman/**'
      - '.github/workflows/**'
```

### Cache Dependencies

```yaml
- name: Cache Newman
  uses: actions/cache@v3
  with:
    path: ~/.npm
    key: ${{ runner.os }}-newman-${{ hashFiles('**/package-lock.json') }}
```

## Next Steps

1. ✅ Add GitHub Secrets
2. ✅ Push code to trigger workflow
3. ✅ Verify tests pass
4. ✅ Enable branch protection
5. ✅ Set up Slack notifications (optional)

## Support

- **Supabase Docs**: https://supabase.com/docs/guides/cli
- **Newman Docs**: https://learning.postman.com/docs/running-collections/using-newman-cli/
- **GitHub Actions**: https://docs.github.com/en/actions
