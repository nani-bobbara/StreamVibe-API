# StreamVibe API - Board Hierarchy Organization Plan

## Current State (27 Issues - Flat Structure)
Issues exist without clear hierarchical relationships or type identification.

## Target Hierarchy (Product → Epic → Feature → User Story/Task/Bug)

---

## **EPIC #18: User Management & Authentication**
*Priority: P0 | Sprint: 1-2*

### **Epic Sub-Issues (Critical Fixes)**
- **Issue #9** (Epic): Fix Critical User Onboarding Flow
  - **Issue #6** (Bug): Missing auth.users trigger
  - **Issue #7** (Bug): Missing RLS INSERT policies  
  - **Issue #8** (Bug): Missing Free tier subscription assignment

### **Feature: User Onboarding & Profile Management** *(NEW - to be created)*
- Scope: Complete signup → profile → subscription flow
- User Stories:
  - TBD: Profile customization (bio, avatar, social links)
  - TBD: Email verification flow
  - TBD: Notification preferences

---

## **EPIC #19: Platform Integrations & OAuth System**
*Priority: P0 | Sprint: 3-4*

### **Epic Sub-Issues (Critical Fixes)**
- **Issue #13** (Epic): Fix Critical Platform OAuth Integration
  - **Issue #10** (Bug): Missing oauth_state table
  - **Issue #11** (Bug): Missing Vault wrapper functions
  - **Issue #12** (Bug): OAuth schema verification

### **Feature 1: OAuth Production Readiness** *(NEW - to be created)*
- Scope: Token management, cleanup, multi-account support
- Sprint: 4-5
- User Stories:
  - **Issue #28**: OAuth Token Refresh & Lifecycle Management
  - **Issue #29**: OAuth Connection Cleanup & Error Recovery
  - **Issue #32**: Multi-Account Support (YouTube/Instagram/TikTok)

### **Feature 2: OAuth Core Implementation** *(Existing - needs documentation)*
- Scope: YouTube, Instagram, TikTok OAuth flows
- Sprint: 3 (BLOCKED - in progress)
- Tasks:
  - **Issue #10**: Fix oauth_state table
  - **Issue #11**: Fix Vault functions
  - **Issue #12**: Schema verification

---

## **EPIC #24: Content Management & Synchronization**
*Priority: P1 | Sprint: 3-5*

### **Epic Sub-Issues (Critical Fixes)**
- **Issue #17** (Bug): Missing last_synced_at column
- **Issue #14** (Bug): Missing content_url column

### **Feature 1: Content Sync Reliability** *(NEW - to be created)*
- Scope: Health monitoring, auto-retry, real-time webhooks
- Sprint: 5
- User Stories:
  - **Issue #30**: Content Sync Health Monitoring & Alerts
  - **Issue #31**: Automatic Sync Retry with Exponential Backoff
  - **Issue #34**: Real-time Content Sync via Platform Webhooks

### **Feature 2: Content Sync Core Implementation** *(Existing - needs documentation)*
- Scope: YouTube, Instagram, TikTok sync Edge Functions
- Sprint: 3-4 (BLOCKED - schema fixes needed)
- Tasks:
  - **Issue #17**: Add last_synced_at tracking
  - **Issue #14**: Add content_url column
  - TBD: Sync frequency configuration
  - TBD: Duplicate detection

---

## **EPIC #25: AI Enhancement & Analytics** *(To be confirmed - may not exist yet)*
*Priority: P2 | Sprint: 6-7*

### **Feature: Operations & Monitoring Dashboard** *(NEW - to be created)*
- Scope: Real-time system health, metrics, alerts
- Sprint: 6
- User Stories:
  - **Issue #33**: Admin Operations Dashboard with Real-time Monitoring

### **Feature: AI Content Tagging** *(Existing - documented in roadmap)*
- Scope: Auto-tag content with AI-generated metadata
- Sprint: 6-7
- User Stories: TBD

---

## **EPIC #26: Public APIs & SEO** *(To be confirmed)*
*Priority: P2 | Sprint: 6-8*

### **Feature: Public Content Discovery APIs** *(Existing - documented in roadmap)*
- Scope: Browse, search, trending, creator discovery
- Sprint: 6-7
- User Stories: TBD

### **Feature: SEO & Sitemap Generation** *(Existing - documented in roadmap)*
- Scope: Dynamic sitemaps, robots.txt, meta tags
- Sprint: 7-8
- User Stories: TBD

---

## **Standalone/Unassigned Issues (7)**
These need to be assigned to appropriate Epics or Features:

### **Pending User Stories (Not Created Yet - Tool Disabled)**
1. **Stripe Webhook Integration** → Should go to Epic #18 (Billing/Subscription Management)
2. **Duplicate Content Detection** → Should go to Epic #24 (Content Sync Reliability Feature)

---

## **Issue Type Classification**

### **Epics (7 total)**
- #18: User Management & Authentication
- #19: Platform Integrations & OAuth System
- #24: Content Management & Synchronization
- #25: AI Enhancement & Analytics
- #26: Public APIs & SEO
- #13: Fix Critical Platform OAuth Integration (sub-epic)
- #9: Fix Critical User Onboarding Flow (sub-epic)

### **Features (6 to be created)**
1. User Onboarding & Profile Management (Epic #18)
2. OAuth Production Readiness (Epic #19)
3. OAuth Core Implementation (Epic #19)
4. Content Sync Reliability (Epic #24)
5. Content Sync Core Implementation (Epic #24)
6. Operations & Monitoring Dashboard (Epic #25)

### **User Stories (7 existing + 2 pending)**
- #28, #29, #30, #31, #32, #33, #34
- Pending: Stripe webhooks, Duplicate detection

### **Bugs (8 critical database/schema issues)**
- #6, #7, #8, #10, #11, #12, #14, #17

### **Tasks (TBD - need to identify from remaining 7 issues)**

---

## **Label Standardization Plan**

### **Type Labels** (Add to all issues)
- `epic` → Issues #18, #19, #24, #25, #26, #9, #13
- `feature` → 6 new Feature issues to be created
- `user-story` → Issues #28, #29, #30, #31, #32, #33, #34 + 2 pending
- `bug` → Issues #6, #7, #8, #10, #11, #12, #14, #17
- `task` → TBD from remaining issues

### **Domain Labels** (Preserve existing, add where missing)
- `backend`, `frontend`, `integrations`, `content-sync`, `oauth`, `billing`, `security`, `database`, `ai`, `seo`, `operations`, `monitoring`

### **Priority Labels** (Standardize)
- `critical` (P0), `high-priority` (P1), `medium-priority` (P2), `low-priority` (P3)

### **Status Labels** (Add as needed)
- `blocked`, `in-progress`, `needs-review`, `ready-for-testing`

---

## **Implementation Steps**

### **Phase 1: Retrieve Full Issue List** ✅ COMPLETE (20/27 retrieved)
Retrieved first 20 issues, need remaining 7 when GitHub tools re-enabled.

### **Phase 2: Create Feature Issues** ⏳ NEXT
Create 6 Feature-level issues to serve as containers:
1. User Onboarding & Profile Management
2. OAuth Production Readiness
3. OAuth Core Implementation
4. Content Sync Reliability
5. Content Sync Core Implementation
6. Operations & Monitoring Dashboard

Each Feature issue should include:
- Title: "📦 Feature: {Name}"
- Body: Overview, parent Epic link, child User Stories list, acceptance criteria, Sprint timeline
- Labels: `feature`, domain label, priority
- Link to parent Epic via sub-issue API

### **Phase 3: Update All Issue Labels** ⏳ PENDING
For all 27 issues:
- Add type label (epic/feature/user-story/bug/task)
- Standardize priority labels
- Preserve domain labels
- Add status labels where applicable

### **Phase 4: Establish Sub-Issue Relationships** ⏳ PENDING
Using GitHub sub-issue API:
- Link Features to parent Epics
- Link User Stories to parent Features
- Link Bugs to parent Epics (if part of Epic fix)

### **Phase 5: Update PROJECT_ROADMAP.md** ⏳ PENDING
Rewrite Epic sections to show Feature breakdown:
```markdown
## Epic #19: Platform OAuth Integration
### Feature 1: OAuth Production Readiness (Sprint 4-5)
- #28: Token Refresh & Lifecycle
- #29: Connection Cleanup
- #32: Multi-Account Support
### Feature 2: OAuth Core Implementation (Sprint 3)
- #10, #11, #12: Critical fixes
```

### **Phase 6: Configure GitHub Projects Board** ⏳ PENDING
- Create "Epic View" - Group by Epic, show Feature count
- Create "Sprint View" - Group by Sprint, show all types
- Create "Hierarchy View" - Tree showing Epic → Feature → Story
- Add filters: Type, Priority, Status, Sprint
- Add custom fields: Sprint, Priority (numeric), Epic link

---

## **Success Metrics**

### **Visibility**
- ✅ Every issue clearly labeled with type (epic/feature/user-story/bug/task)
- ✅ GitHub Projects shows clear Epic → Feature → Story hierarchy
- ✅ Can filter board by Epic, Feature, or Sprint
- ✅ Parent-child relationships visible in issue detail view

### **Completeness**
- ✅ All 27 issues categorized
- ✅ All user stories linked to Features
- ✅ All Features linked to Epics
- ✅ PROJECT_ROADMAP.md matches GitHub board structure

### **Usability**
- ✅ Product Owner can get "eagle eye view" from Product → Epic → Feature → Story
- ✅ Developers can see Sprint-level tasks
- ✅ Stakeholders can track Epic progress via Feature completion

---

## **Next Actions (When GitHub Tools Re-enabled)**

1. **Retrieve remaining 7 issues** (issues #6 and below)
2. **Create 6 Feature issues** with proper descriptions
3. **Update all 27 issue labels** (add type labels)
4. **Link hierarchy** using sub-issue API
5. **Update PROJECT_ROADMAP.md** with Feature breakdown
6. **Configure GitHub Projects views** for visualization
7. **Create 2 pending user stories** (Stripe, Duplicate detection)

---

**Status**: Plan complete, waiting for GitHub tools to be re-enabled to execute phases 2-6.
**Last Updated**: 2025-11-12 (Nov 12, 2025)
