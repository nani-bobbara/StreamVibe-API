# StreamVibe API - Project Roadmap

> **Role:** Product Owner + Technical Architect  
> **Last Updated:** November 11, 2025  
> **Status:** In Development - Sprint 3

---

## 📊 Project Board Structure

Following **Agile/SAFe** best practices:

```
🎯 EPIC (Product-Level)
  └─ 📦 FEATURE (Feature-Level)
       └─ ✅ USER STORY / 🐛 BUG / 📋 TASK (Implementation-Level)
```

---

## 🎯 Product Epics (Priority Order)

### Epic #18: User Management & Authentication System
**Priority:** P0 | **Status:** 🔄 60% Complete | **Sprint:** 1-2  
**Business Value:** Enable user registration, profiles, subscription tiers  
**Dependencies:** None (Foundation)

**Features:**
- ✅ **Feature #9:** User Onboarding Flow (COMPLETE)
  - ✅ #6: Auto-create user profile trigger
  - ✅ #7: RLS INSERT policies
  - ✅ #8: Free tier auto-assignment
- 📅 Profile Management (TBD)
- 📅 Quota Management (TBD)
- 📅 Email Verification (TBD)

**Acceptance Criteria:**
- [x] Users can sign up with email/password
- [x] User profile automatically created
- [x] Free tier subscription assigned (10 syncs, 25 AI)
- [x] RLS policies prevent unauthorized access
- [ ] Profile setup Edge Function tested
- [ ] Quota enforcement working

---

### Epic #19: Platform Integrations & OAuth System
**Priority:** P0 | **Status:** 🔴 0% - Blocked | **Sprint:** 3-4  
**Business Value:** Connect YouTube, Instagram, TikTok accounts  
**Dependencies:** Blocks Epic #20 (Content Sync)

**Features:**
- 🔴 **Feature #13:** OAuth Integration (BLOCKED)
  - 🔴 #10: Missing oauth_state table
  - 🔴 #11: Missing Vault wrapper functions
  - 🔴 #12: Missing schema columns
- 📅 Token Refresh & Health Monitoring (TBD)

**Acceptance Criteria:**
- [ ] `oauth_state` table created (#10)
- [ ] Vault functions implemented (#11)
- [ ] Schema columns verified (#12)
- [ ] YouTube OAuth flow works end-to-end
- [ ] Instagram OAuth flow works end-to-end
- [ ] TikTok OAuth flow works end-to-end
- [ ] Access tokens stored securely in Vault
- [ ] CSRF protection via state validation

---

### Epic #24: Content Management & Synchronization
**Priority:** P0 | **Status:** 🔴 0% - Blocked | **Sprint:** 4-5  
**Business Value:** Sync content from YouTube, Instagram, TikTok  
**Dependencies:** Requires Epic #19 (OAuth)

**Features:**
- 🔴 **Feature 3.1:** Content Schema & Database (BLOCKED)
  - Missing `thumbnail_url` column
  - Missing `platform_url` column
  - Schema mismatch for `content_type`
- 🔴 **Feature 3.2:** YouTube Content Sync (BLOCKED)
- 🔴 **Feature 3.3:** Instagram Content Sync (BLOCKED)
- 🔴 **Feature 3.4:** TikTok Content Sync (BLOCKED)
- 📅 **Feature 3.5:** Scheduled Sync Jobs (Cron)
- 📅 **Feature 3.6:** Sync Health & Monitoring

**Acceptance Criteria:**
- [ ] Schema gaps fixed
- [ ] YouTube sync works end-to-end
- [ ] Instagram sync works end-to-end
- [ ] TikTok sync works end-to-end
- [ ] Content appears in database
- [ ] Thumbnails stored and accessible
- [ ] Engagement stats synced
- [ ] Rate limits respected

---

### Epic #25: AI & Analytics Engine
**Priority:** P1 | **Status:** 📅 Planned | **Sprint:** 5-6  
**Business Value:** AI-powered content tagging and recommendations  
**Dependencies:** Requires Epic #24 (Content must exist)

**Features:**
- 📅 **Feature 4.1:** AI Tag Generation System
- 📅 **Feature 4.2:** Tag Storage & Search
- 📅 **Feature 4.3:** AI Quota Management
- 📅 **Feature 4.4:** Tag Quality & Feedback
- 📅 **Feature 4.5:** Advanced AI Features (Sentiment, Genre)

**Acceptance Criteria:**
- [ ] AI generates 5-15 tags per content item
- [ ] Tags stored and searchable
- [ ] AI quota tracked (25 Free, 100 Creator, Unlimited Pro)
- [ ] Multi-language support
- [ ] Response time < 3 seconds
- [ ] Tag accuracy > 85%

---

### Epic #26: Public APIs & SEO Optimization
**Priority:** P0 | **Status:** 📅 Planned | **Sprint:** 6-8  
**Business Value:** Public content discovery and SEO  
**Dependencies:** Requires Epic #24 (Content), Epic #25 (Tags)

**Features:**
- 📅 **Feature 5.1:** Browse & Search APIs
- 📅 **Feature 5.2:** Creator Discovery APIs
- 📅 **Feature 5.3:** SEO Optimization (sitemap, robots, meta tags)
- 📅 **Feature 5.4:** Engagement Tracking
- 📅 **Feature 5.5:** Content Recommendations

**Acceptance Criteria:**
- [ ] Browse/search APIs work (< 200ms response)
- [ ] Creator discovery APIs work
- [ ] sitemap.xml generated and valid
- [ ] Open Graph tags for social sharing
- [ ] Click tracking and analytics
- [ ] Public access (no auth required)
- [ ] Google Search Console validates sitemap

---

## 📅 Sprint Plan

### Sprint 1-2: Foundation (COMPLETE ✅)
**Duration:** Nov 1-11, 2025  
**Goal:** User authentication and onboarding

- [x] Epic #18: User Management (60% complete)
- [x] Feature #9: User Onboarding Flow
- [x] Migration: 20251111200000_fix_user_onboarding.sql
- [x] CI/CD pipeline deployed fixes

**Outcomes:**
- ✅ Users can sign up and auto-create profiles
- ✅ Free tier subscription assigned automatically
- ✅ RLS policies secure user data

---

### Sprint 3: OAuth Infrastructure (CURRENT 🔄)
**Duration:** Nov 11-18, 2025  
**Goal:** Fix OAuth blockers and enable platform connections

- [ ] Epic #19: Platform OAuth (Priority: P0)
- [ ] Fix #10: Create oauth_state table
- [ ] Fix #11: Implement Vault wrapper functions
- [ ] Fix #12: Verify schema columns
- [ ] Test YouTube OAuth end-to-end

**Success Criteria:**
- [ ] All 3 OAuth blockers fixed
- [ ] YouTube OAuth flow completes successfully
- [ ] Access tokens stored in Vault
- [ ] CSRF protection working

**Risks:**
- Vault API complexity (Medium)
- Platform API changes (Low)

---

### Sprint 4: Content Sync - Part 1
**Duration:** Nov 18-25, 2025  
**Goal:** Enable content synchronization from platforms

- [ ] Epic #24: Content Sync (Priority: P0)
- [ ] Feature 3.1: Fix content schema
- [ ] Feature 3.2: YouTube sync working
- [ ] Feature 3.3: Instagram sync working
- [ ] Feature 3.4: TikTok sync working

**Success Criteria:**
- [ ] Schema gaps fixed
- [ ] All 3 platforms sync successfully
- [ ] Content stored in database
- [ ] Thumbnails uploaded to Storage

**Risks:**
- Platform API rate limits (High)
- Schema migration complexity (Medium)

---

### Sprint 5: Content Sync - Part 2 & AI
**Duration:** Nov 25-Dec 2, 2025  
**Goal:** Automate sync and add AI tagging

- [ ] Feature 3.5: Scheduled sync jobs (pg_cron)
- [ ] Feature 3.6: Sync health monitoring
- [ ] Epic #25: AI & Analytics (Priority: P1)
- [ ] Feature 4.1: AI tag generation
- [ ] Feature 4.2: Tag storage & search
- [ ] Feature 4.3: AI quota management

**Success Criteria:**
- [ ] Cron jobs run automatically
- [ ] Sync failures monitored and alerted
- [ ] AI generates tags for all content
- [ ] AI quota tracked per user

**Risks:**
- AI API costs (High)
- Tag quality < 85% (Medium)

---

### Sprint 6: Public APIs - Part 1
**Duration:** Dec 2-9, 2025  
**Goal:** Enable public content discovery

- [ ] Epic #26: Public APIs (Priority: P0)
- [ ] Feature 5.1: Browse & search APIs
- [ ] Feature 5.2: Creator discovery
- [ ] Performance optimization (indexes)

**Success Criteria:**
- [ ] Browse/search APIs < 200ms response
- [ ] Creator discovery working
- [ ] Public access (no auth)
- [ ] RLS policies secure data

**Risks:**
- Query performance (Medium)
- API abuse/DDoS (Medium)

---

### Sprint 7: SEO & Analytics
**Duration:** Dec 9-16, 2025  
**Goal:** SEO optimization and engagement tracking

- [ ] Feature 5.3: SEO optimization
- [ ] sitemap.xml + robots.txt
- [ ] Open Graph + Twitter Cards
- [ ] Feature 5.4: Engagement tracking
- [ ] Feature 5.5: Content recommendations

**Success Criteria:**
- [ ] Google Search Console validates sitemap
- [ ] Social media link previews work
- [ ] Click tracking operational
- [ ] Recommendations > 50% CTR

**Risks:**
- SEO penalties (Low)
- Analytics privacy compliance (Medium)

---

### Sprint 8: Polish & Launch Prep
**Duration:** Dec 16-23, 2025  
**Goal:** Final testing and launch preparation

- [ ] End-to-end testing (all features)
- [ ] Performance optimization
- [ ] Security audit
- [ ] Documentation updates
- [ ] Launch checklist completion

**Success Criteria:**
- [ ] All P0 features complete and tested
- [ ] Performance: < 200ms API response time
- [ ] Security: 0 critical vulnerabilities
- [ ] Documentation: 100% API coverage

---

## 🎯 Success Metrics (KPIs)

### User Engagement:
- **Signup Conversion:** > 60% complete signup
- **Onboarding Completion:** > 80% complete profile
- **Platform Connections:** > 70% connect at least one platform
- **Content Synced:** > 1000 content items by launch

### Technical Performance:
- **API Uptime:** 99.9% availability
- **API Response Time:** < 200ms (p95)
- **Sync Success Rate:** > 98% jobs complete
- **AI Tag Accuracy:** > 85% relevance

### Business Outcomes:
- **Free to Paid Conversion:** > 5% within 30 days
- **Organic Traffic:** > 40% from SEO
- **User Retention:** > 60% return after 30 days
- **Content Growth:** > 10% week-over-week

---

## 🔴 Critical Blockers (P0)

### BLOCKING EPIC #19 (OAuth):
1. **#10:** Missing `oauth_state` table - CSRF protection broken
2. **#11:** Missing Vault wrapper functions - Cannot store tokens
3. **#12:** Missing schema columns - Social accounts cannot be created

### BLOCKING EPIC #24 (Content Sync):
1. Missing `thumbnail_url` column in `content_item`
2. Missing `platform_url` column in `content_item`
3. Schema mismatch: `content_type` (TEXT vs UUID)

**Impact:** All content sync features blocked until resolved  
**Timeline:** Must fix in Sprint 3 to avoid cascading delays

---

## 📋 Issue Labels & Organization

### Priority Labels:
- `P0` - Critical blocker (must fix immediately)
- `P1` - High priority (required for launch)
- `P2` - Medium priority (nice to have)
- `P3` - Low priority (future phase)

### Type Labels:
- `epic` - Product-level Epic
- `feature` - Feature-level work
- `bug` - Defect or issue
- `task` - Technical story
- `enhancement` - Improvement to existing feature

### Area Labels:
- `backend` - Backend/API work
- `database` - Schema/migration work
- `authentication` - Auth and user management
- `integrations` - Platform OAuth and APIs
- `content-sync` - Content synchronization
- `ai` - AI and machine learning
- `public-api` - Public-facing APIs
- `seo` - SEO optimization

---

## 🔗 Issue Hierarchy Reference

```
Epic #18: User Management & Authentication System
  └─ Feature #9: User Onboarding Flow ✅
       ├─ #6: Missing auth.users trigger ✅
       ├─ #7: Missing RLS INSERT policies ✅
       └─ #8: Missing subscription auto-assignment ✅

Epic #19: Platform Integrations & OAuth System
  └─ Feature #13: OAuth Integration 🔴
       ├─ #10: Missing oauth_state table 🔴
       ├─ #11: Missing Vault wrapper functions 🔴
       └─ #12: Missing schema columns 🔴

Epic #24: Content Management & Synchronization
  └─ Feature 3.1: Content Schema & Database 🔴
  └─ Feature 3.2: YouTube Content Sync 🔴
  └─ Feature 3.3: Instagram Content Sync 🔴
  └─ Feature 3.4: TikTok Content Sync 🔴
  └─ Feature 3.5: Scheduled Sync Jobs (Cron) 📅
  └─ Feature 3.6: Sync Health & Monitoring 📅

Epic #25: AI & Analytics Engine
  └─ Feature 4.1: AI Tag Generation System 📅
  └─ Feature 4.2: Tag Storage & Search 📅
  └─ Feature 4.3: AI Quota Management 📅
  └─ Feature 4.4: Tag Quality & Feedback 📅
  └─ Feature 4.5: Advanced AI Features 📅

Epic #26: Public APIs & SEO Optimization
  └─ Feature 5.1: Browse & Search APIs 📅
  └─ Feature 5.2: Creator Discovery APIs 📅
  └─ Feature 5.3: SEO Optimization 📅
  └─ Feature 5.4: Engagement Tracking 📅
  └─ Feature 5.5: Content Recommendations 📅
```

**Legend:**
- ✅ Complete
- 🔄 In Progress
- 🔴 Blocked
- 📅 Planned

---

## 📖 Related Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Database Schema](docs/DATABASE.md)
- [Backend Implementation](docs/BACKEND_IMPLEMENTATION.md)
- [Platform Integrations](docs/INTEGRATIONS.md)
- [Public API Guide](docs/PUBLIC_API.md)
- [Postman Testing](docs/POSTMAN_GUIDE.md)

---

## 🎯 Working Rules (Going Forward)

### 1. **Single Source of Truth:**
   - This roadmap is the authoritative project plan
   - All work must align with documented Epics/Features
   - No ad-hoc features without Epic approval

### 2. **Issue-Driven Development:**
   - All work tracked in GitHub Issues
   - Every code change references an issue (#N)
   - No commits without issue reference

### 3. **Priority Enforcement:**
   - P0 issues block all other work
   - P1 issues required for launch
   - P2/P3 deferred to post-launch

### 4. **Sprint Discipline:**
   - Sprint goals defined at start
   - Daily progress updates
   - Sprint retrospectives

### 5. **Definition of Done:**
   - Code reviewed and merged
   - Tests passing (unit + integration)
   - Documentation updated
   - Issue closed with verification comment

---

**Roadmap Owner:** @nani-bobbara (Product Owner + Technical Architect)  
**Last Sprint Review:** November 11, 2025  
**Next Sprint Planning:** November 11, 2025 (Sprint 3)
