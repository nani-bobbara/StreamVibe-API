# CI/CD Setup Guide

This guide explains how to set up continuous integration and deployment for the StreamVibe API with comprehensive security checks.

## Overview

The CI/CD pipeline automates:
1. **Security Scanning**: Comprehensive security checks on every push/PR
2. **Testing**: Runs Postman collection tests on every push/PR
3. **Deployment**: Deploys database migrations and Edge Functions to Supabase on main branch (only after security and tests pass)

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CI/CD Pipeline Flow                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Code Push/PR                                           │
│       ↓                                                     │
│  2. Security Gate (Pre-check)                              │
│       ├── Secret scanning                                  │
│       ├── Basic security patterns                          │
│       └── Quick validation                                 │
│       ↓                                                     │
│  3. Parallel Execution                                     │
│       ├── API Tests (Newman)                               │
│       └── Security Scans (Detailed)                        │
│           ├── CodeQL Analysis                              │
│           ├── Dependency Review                            │
│           ├── SQL Security Scan                            │
│           ├── TypeScript Security                          │
│           └── Secret Detection (Deep)                      │
│       ↓                                                     │
│  4. Deploy (main branch only)                              │
│       ├── Only if all checks pass                          │
│       ├── Database migrations                              │
│       └── Edge Functions                                   │
│       ↓                                                     │
│  5. Post-deployment                                        │
│       ├── Deployment summary                               │
│       └── PR comments (if applicable)                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## GitHub Actions Workflows

### 1. Test and Deploy Workflow (`test-and-deploy.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual dispatch (Actions tab → "Run workflow")

**Jobs:**

#### Security Gate (Pre-check)
- Runs before any other job
- Quick security pattern checks
- Validates no obvious secrets in code
- Blocks pipeline if critical issues found

#### Test Job
- Requires security gate to pass
- Installs Newman (Postman CLI)
- Creates environment with Supabase credentials
- Runs complete Postman collection
- Generates HTML test report
- Uploads test results as artifacts
- Comments on PR with test summary

#### Deploy Job (main branch only)
- Requires security gate AND tests to pass
- Only runs on pushes to main branch
- Installs Supabase CLI
- Links to Supabase project
- Deploys database migrations
- Deploys all Edge Functions
- Creates deployment summary

### 2. Security Scanning Workflow (`security-scan.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Scheduled daily at 2 AM UTC
- Manual dispatch

**Jobs:**

#### Dependency Review
- Scans for vulnerable dependencies
- Fails on moderate+ severity issues
- Checks license compliance
- Only runs on pull requests

#### Secret Scanning
- Uses TruffleHog for deep secret detection
- Scans entire git history
- Detects API keys, tokens, passwords
- Only reports verified secrets

#### CodeQL Analysis
- GitHub's semantic code analysis
- Scans TypeScript/JavaScript code
- Detects security vulnerabilities
- Identifies code quality issues
- Generates SARIF reports for Security tab

#### SQL Security Scan
- Lints SQL migrations with SQLFluff
- Checks for SQL injection patterns
- Validates PostgreSQL best practices
- Fails on dangerous dynamic SQL

#### TypeScript Security
- Scans for hardcoded credentials
- Detects eval() usage
- Checks for common anti-patterns
- Runs Deno lint for code quality

#### Container Security (if applicable)
- Scans Dockerfiles with Trivy
- Checks for vulnerable base images
- Uploads results to Security tab

#### Security Summary
- Aggregates all scan results
- Posts summary to PR
- Creates GitHub Step Summary
- Reports overall security status

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

SUPABASE_DB_PASSWORD
  Description: Database password for migrations
  Where to find: Supabase Dashboard → Project Settings → Database
  ⚠️ Required for db push operations
```

## Security Features

### 🔒 Automated Security Checks

Every code push and pull request runs through:

1. **Secret Detection**
   - TruffleHog scans entire git history
   - Detects 700+ secret types
   - Only verified secrets reported
   - Blocks PRs with secrets

2. **Dependency Scanning**
   - Checks for known CVEs
   - License compliance verification
   - Automated dependency updates via Dependabot
   - Fails on high/critical vulnerabilities

3. **Code Security Analysis**
   - CodeQL semantic analysis
   - Detects injection vulnerabilities
   - Identifies authentication issues
   - Checks for XSS, CSRF, etc.

4. **SQL Security**
   - SQLFluff linting
   - SQL injection pattern detection
   - PostgreSQL best practices
   - Dynamic SQL concatenation checks

5. **TypeScript Security**
   - Hardcoded credential detection
   - eval() usage detection
   - Deno security best practices
   - Common anti-pattern checks

### 🛡️ Security Gates

Deployment only happens if:
- ✅ All security scans pass
- ✅ All API tests pass
- ✅ Push is to main branch
- ✅ No secrets detected
- ✅ No high/critical vulnerabilities

### 📊 Security Reporting

- **PR Comments**: Automated security summaries on pull requests
- **GitHub Security Tab**: SARIF reports uploaded for CodeQL and Trivy
- **GitHub Step Summaries**: Detailed results in Actions UI
- **Daily Scans**: Scheduled security audits at 2 AM UTC

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

SUPABASE_DB_PASSWORD
  Description: Database password for migrations
  Where to find: Supabase Dashboard → Project Settings → Database
  ⚠️ Required for db push operations
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

### 3. Enable Security Features

1. **Enable Dependabot Alerts**
   - Go to **Settings** → **Security & analysis**
   - Enable **Dependency graph**
   - Enable **Dependabot alerts**
   - Enable **Dependabot security updates**

2. **Enable Code Scanning**
   - Go to **Security** tab → **Code scanning**
   - CodeQL will run automatically via workflow

3. **Enable Secret Scanning**
   - Go to **Settings** → **Security & analysis**
   - Enable **Secret scanning**
   - Enable **Push protection**

### 4. Configure Branch Protection

**Protect your main branch:**

1. Go to **Settings** → **Branches** → **Add rule**
2. Branch name pattern: `main`
3. Enable these protections:
   - ✅ **Require a pull request before merging**
   - ✅ **Require status checks to pass before merging**
   - ✅ **Require branches to be up to date before merging**
   - Select required checks:
     - `Security Pre-check`
     - `Run Postman Tests`
     - `CodeQL`
     - `Secret Detection`
     - `SQL Security Analysis`
     - `TypeScript Security Scan`
   - ✅ **Require conversation resolution before merging**
   - ✅ **Do not allow bypassing the above settings**

4. Click **Create** to save the rule

This ensures NO code reaches main without passing all security checks!

### 5. Verify Workflow Files

Check that these workflow files exist:
```
.github/workflows/test-and-deploy.yml    # Main CI/CD pipeline
.github/workflows/security-scan.yml      # Comprehensive security scans
.github/dependabot.yml                   # Automated dependency updates
```

### 6. Test the Pipeline

#### Option A: Push a commit
```bash
git add .
git commit -m "Test CI/CD security pipeline"
git push origin main
```

#### Option B: Create a Pull Request
```bash
git checkout -b test-security-pipeline
git add .
git commit -m "Test security checks"
git push origin test-security-pipeline
# Then create PR via GitHub UI
```

#### Option C: Manual trigger
1. Go to **Actions** tab in GitHub
2. Select **API Testing and Deployment** or **Security Scanning** workflow
3. Click **Run workflow**
4. Select branch
5. Click **Run workflow** button

## Viewing Results

### Security Scan Results

1. **Security Tab**
   - Go to **Security** tab in your repository
   - View **Code scanning alerts** (CodeQL findings)
   - View **Secret scanning alerts** (if any secrets detected)
   - View **Dependabot alerts** (vulnerable dependencies)

2. **Actions Workflow Results**
   - Go to **Actions** tab
   - Click on the workflow run
   - Review each security job:
     - Secret Detection
     - CodeQL Analysis
     - SQL Security Scan
     - TypeScript Security Scan
   - Check **Security Scan Summary** for overall status

3. **PR Comments**
   - Security bot automatically comments on PRs with:
     - ✅/❌ Overall security status
     - Individual check results
     - Links to detailed reports

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

**API Tests:**
```
## 🧪 API Test Results

**Status:** ✅ All tests passed!

- ✅ Passed: 15/15
- ❌ Failed: 0/15

📊 [View Full Report](...)

_Tests run on commit abc123_
```

**Security Scans:**
```
## 🔒 Security Scan Results

All security scans have completed for this PR:

- ✅ Secret scanning - No secrets detected
- ✅ CodeQL analysis - No high severity issues
- ✅ SQL security scan - No injection vulnerabilities
- ✅ TypeScript security scan - No security issues

📊 [View detailed results](...)

_Security scans run on commit abc123_
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

### Security Scan Issues

#### CodeQL fails with "No code found"

**Solution:** CodeQL requires source code to analyze. Ensure TypeScript files exist in `supabase/functions/`.

#### TruffleHog times out

**Solution:** Large repositories may timeout. Adjust the workflow:
```yaml
- name: TruffleHog Secret Scan
  uses: trufflesecurity/trufflehog@main
  with:
    extra_args: --only-verified --max-depth 50
```

#### Dependabot alerts not showing

**Solution:** 
1. Enable Dependency graph in **Settings** → **Security & analysis**
2. Wait 24 hours for initial scan
3. Check if package files exist (package.json, etc.)

#### SQL security scan reports false positives

**Solution:** Add SQLFluff ignore comments:
```sql
-- noqa: L001
SELECT * FROM users;
```

### Deployment Issues

#### Workflow fails with "Supabase CLI not found"

**Solution:** The `supabase/setup-cli@v1` action should handle this. If it fails, update the action version in `.github/workflows/test-and-deploy.yml`.

#### Tests fail with "Connection refused"

**Solution:** Check that `SUPABASE_URL` secret is correct and doesn't have trailing slash.

#### Deployment fails with "Project not linked"

**Solution:** Verify `SUPABASE_PROJECT_REF` and `SUPABASE_ACCESS_TOKEN` secrets are set correctly.

#### Edge Functions deploy but show "Not found" errors

**Solution:** Check Edge Function secrets are set in Supabase Dashboard:
1. Go to **Project Settings** → **Edge Functions**
2. Add required secrets (YOUTUBE_CLIENT_ID, OPENAI_API_KEY, etc.)

#### Newman test timeout

**Solution:** Increase timeout in workflow file:
```yaml
--timeout-request 30000  # Change to 60000 for 60 seconds
```

#### Security gate blocks deployment with false positive

**Solution:** Review the specific check that failed:
1. Check **Actions** tab → Failed workflow
2. Review **Security Pre-check** job logs
3. If false positive, adjust patterns in workflow
4. Never disable security checks without review

## Security Best Practices

### For Developers

1. **Never Commit Secrets**
   - Use `.env` files (gitignored)
   - Store in GitHub Secrets or Supabase Vault
   - Review diff before committing
   - Use git hooks to prevent accidents

2. **Keep Dependencies Updated**
   - Review Dependabot PRs promptly
   - Test dependency updates before merging
   - Check for breaking changes
   - Monitor security advisories

3. **Write Secure Code**
   - Validate all user inputs
   - Use parameterized SQL queries
   - Sanitize error messages
   - Implement proper authentication
   - Follow principle of least privilege

4. **Review Security Alerts**
   - Check **Security** tab daily
   - Investigate all findings
   - Fix critical/high issues immediately
   - Document false positives

### For Repository Admins

1. **Branch Protection**
   - Require status checks (security + tests)
   - Require pull request reviews
   - Enable conversation resolution
   - Restrict who can push to main

2. **Security Policies**
   - Keep SECURITY.md updated
   - Define vulnerability SLAs
   - Establish disclosure process
   - Document incident response

3. **Access Control**
   - Limit who has write access
   - Review collaborators regularly
   - Use teams for permissions
   - Require 2FA for all users

4. **Monitoring**
   - Enable all GitHub security features
   - Review Actions logs weekly
   - Monitor Supabase logs
   - Set up alerting for failures

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

### CI/CD Performance

1. **Cache Dependencies**
   ```yaml
   - name: Cache Newman
     uses: actions/cache@v3
     with:
       path: ~/.npm
       key: ${{ runner.os }}-newman-${{ hashFiles('**/package-lock.json') }}
   ```

2. **Run Jobs in Parallel**
   - Security scans run parallel to tests
   - Only deployment waits for all checks

3. **Limit Workflow Triggers**
   ```yaml
   on:
     push:
       paths:
         - 'supabase/**'
         - '.github/workflows/**'
       branches: [ main, develop ]
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

Or use GitHub mobile app for push notifications on:
- Failed workflows
- Security alerts
- Dependabot updates

## Monitoring

### GitHub Actions Insights

View workflow performance:
1. **Actions** tab
2. **Insights** (left sidebar)
3. Review success rate, duration, trends

### Supabase Logs

```bash
# Stream Edge Function logs
supabase functions logs --tail

# Specific function
supabase functions logs auth-profile-setup --tail

# Database logs
supabase db inspect
```

### Security Dashboard

Monitor security health:
1. **Security** tab → Overview
2. Review open alerts
3. Check security policy compliance
4. Monitor dependency health

## Cost Optimization

### GitHub Actions Minutes

Free tier includes:
- 2,000 minutes/month (private repos)
- Unlimited minutes (public repos)

To optimize:
1. **Cache dependencies** to speed up builds
2. **Run tests in parallel** where possible
3. **Limit workflow triggers** to relevant paths
4. **Use self-hosted runners** if exceeding limits

### Supabase Usage

Monitor API usage:
1. Supabase Dashboard → Usage
2. Track Edge Function invocations
3. Monitor database queries
4. Review storage usage

## Quick Reference

### Common Commands

```bash
# Trigger workflow manually
gh workflow run test-and-deploy.yml

# View workflow status
gh run list --workflow=test-and-deploy.yml

# View logs for latest run
gh run view

# Download artifacts
gh run download <run-id>

# List secrets
gh secret list

# Set a secret
gh secret set SUPABASE_URL

# Deploy manually
./deploy.sh
```

### Workflow Files

| File | Purpose | Trigger |
|------|---------|---------|
| `test-and-deploy.yml` | Main CI/CD pipeline | Push, PR, Manual |
| `security-scan.yml` | Comprehensive security | Push, PR, Daily, Manual |
| `dependabot.yml` | Dependency updates | Weekly |

### Required Status Checks

For branch protection on `main`:
- ✅ Security Pre-check
- ✅ Run Postman Tests
- ✅ CodeQL
- ✅ Secret Detection
- ✅ SQL Security Analysis
- ✅ TypeScript Security Scan

## Next Steps

### Initial Setup (Do Once)

1. ✅ Add all GitHub Secrets
2. ✅ Enable GitHub security features
3. ✅ Configure branch protection
4. ✅ Test workflows with manual trigger
5. ✅ Review first workflow run results

### Ongoing Maintenance

1. **Daily**: Review security alerts
2. **Weekly**: Review Dependabot PRs
3. **Monthly**: Review workflow performance
4. **Quarterly**: Update security policies

### After Each PR

1. ✅ Verify all checks pass
2. ✅ Review security scan results
3. ✅ Check test coverage
4. ✅ Ensure deployment succeeds (main only)

## Additional Resources

### Documentation
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Supabase CLI Reference](https://supabase.com/docs/guides/cli)
- [Newman Documentation](https://learning.postman.com/docs/running-collections/using-newman-cli/)
- [CodeQL Documentation](https://codeql.github.com/docs/)

### Security Tools
- [TruffleHog](https://github.com/trufflesecurity/trufflehog)
- [SQLFluff](https://docs.sqlfluff.com/)
- [Dependabot](https://docs.github.com/en/code-security/dependabot)
- [Trivy](https://aquasecurity.github.io/trivy/)

### StreamVibe Docs
- [Architecture Documentation](../docs/ARCHITECTURE.md)
- [Security Policy](../SECURITY.md)
- [Database Documentation](../docs/DATABASE.md)
- [Quick Start Guide](../QUICK_START.md)

## Support

- **Security Issues**: See [SECURITY.md](../SECURITY.md)
- **CI/CD Questions**: Open a GitHub Discussion
- **Bug Reports**: Open a GitHub Issue
- **Urgent**: Contact repository maintainers

---

**Last Updated**: November 12, 2024  
**Version**: 2.0.0 (Security-Enhanced Pipeline)  
**Status**: ✅ Production Ready

---

## Summary Checklist

Use this checklist to verify your CI/CD security pipeline is properly configured:

### Infrastructure
- [ ] All GitHub Secrets configured
- [ ] Dependabot enabled
- [ ] Code scanning enabled
- [ ] Secret scanning enabled
- [ ] Push protection enabled
- [ ] Branch protection rules set

### Workflows
- [ ] `test-and-deploy.yml` present and working
- [ ] `security-scan.yml` present and working
- [ ] `.github/dependabot.yml` configured
- [ ] Workflows tested with manual trigger
- [ ] All security checks passing

### Security
- [ ] `.gitignore` prevents secret commits
- [ ] `SECURITY.md` documents policies
- [ ] No secrets in repository history
- [ ] All dependencies up to date
- [ ] Security alerts reviewed and addressed

### Process
- [ ] Team understands security requirements
- [ ] PR review process includes security
- [ ] Incident response plan documented
- [ ] Regular security reviews scheduled

**Once all items are checked, your security pipeline is ready! 🎉**
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
