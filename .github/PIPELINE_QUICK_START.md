# CI/CD Security Pipeline - Quick Start

## 🚀 One-Time Setup (5 minutes)

### 1. Add GitHub Secrets

Go to **Settings** → **Secrets and variables** → **Actions** and add:

```
SUPABASE_URL              - Your Supabase project URL
SUPABASE_ANON_KEY         - Public API key
SUPABASE_SERVICE_ROLE_KEY - Private service role key
SUPABASE_PROJECT_REF      - Project reference ID
SUPABASE_ACCESS_TOKEN     - Personal access token for CLI
SUPABASE_DB_PASSWORD      - Database password
```

### 2. Enable Security Features

Go to **Settings** → **Security & analysis** and enable:
- ✅ Dependency graph
- ✅ Dependabot alerts
- ✅ Dependabot security updates
- ✅ Secret scanning
- ✅ Push protection

### 3. Protect Main Branch

Go to **Settings** → **Branches** → **Add rule**:
- Branch name: `main`
- ✅ Require pull request reviews
- ✅ Require status checks to pass:
  - Security Pre-check
  - Run Postman Tests
  - CodeQL
  - Secret Detection
  - SQL Security Analysis
  - TypeScript Security Scan

### 4. Test the Pipeline

```bash
# Create a test PR
git checkout -b test-security
git commit --allow-empty -m "Test security pipeline"
git push origin test-security

# Create PR via GitHub UI
# Watch all security checks run automatically!
```

## 🔒 What Gets Checked

Every push and PR automatically runs:

1. **Secret Scanning** - Detects 700+ secret types
2. **CodeQL Analysis** - Finds security vulnerabilities
3. **Dependency Review** - Checks for vulnerable packages
4. **SQL Security** - Detects injection patterns
5. **TypeScript Security** - Finds hardcoded credentials
6. **API Tests** - Validates functionality

## ✅ Deployment Flow

```
Code Push → Security Gate → Parallel (Tests + Security Scans) → Deploy (main only)
```

Deployment only happens if:
- ✅ All security checks pass
- ✅ All tests pass
- ✅ Push is to main branch

## 📊 Where to See Results

- **Actions Tab** - Workflow runs and logs
- **Security Tab** - CodeQL alerts and vulnerabilities
- **PR Comments** - Automated test and security summaries

## 📚 Full Documentation

See [`.github/CI_CD_SETUP.md`](.github/CI_CD_SETUP.md) for:
- Detailed setup instructions
- Troubleshooting guide
- Security best practices
- Complete workflow documentation

## 🆘 Common Issues

**"Workflow not running"**
→ Check GitHub Secrets are configured

**"Security check failing"**
→ Review Actions tab for specific error
→ Fix the issue and push again

**"Can't merge PR"**
→ Ensure all required checks pass
→ Review branch protection settings

## ⏱️ Pipeline Performance

- **Security Scans**: ~3-5 minutes
- **API Tests**: ~1-2 minutes
- **Deployment**: ~5-7 minutes
- **Total Time**: ~10-15 minutes per push

## 🔐 Security Policy

See [`SECURITY.md`](../SECURITY.md) for:
- How to report vulnerabilities
- Security best practices
- Incident response process

---

**Need Help?** Open a GitHub Issue or Discussion
