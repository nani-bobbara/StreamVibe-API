# Archive

This folder contains historical design documents and brainstorming materials from the initial development phase. These documents are kept for reference but may contain outdated information.

## 📚 Archived Documents

### Authentication & OAuth
- **AUTHENTICATION_ARCHITECTURE.md** - Initial auth design (superseded by INTEGRATIONS.md)
- **OAUTH_FLOW_DIAGRAM.md** - OAuth flow diagrams (merged into INTEGRATIONS.md)
- **OAUTH_QUICK_REFERENCE.md** - Quick reference (merged into INTEGRATIONS.md)
- **USER_FLOW_IMPLEMENTATION.md** - User flow specs (superseded by BACKEND_IMPLEMENTATION.md)

### Database Design
- **SCHEMA_IMPROVEMENTS.md** - Initial schema ideas
- **SCHEMA_REFACTORING_ANALYSIS.md** - Schema refactoring proposals
- **SCHEMA_SUMMARY.md** - Early schema documentation
- **StreamVibe.sql** - Original schema v1
- **StreamVibe_v2_improved.sql** - Schema v2
- **StreamVibe_v3_production.sql** - Schema v3 (current version in database/schema.sql)

### Integrations
- **STRIPE_INTEGRATION.md** - Stripe setup (merged into INTEGRATIONS.md)
- **STRIPE_MINIMAL_SCHEMA.sql** - Stripe schema (included in main schema)
- **STRIPE_CACHING_STRATEGY.md** - Caching strategy (merged into ARCHITECTURE.md)
- **SEO_INDEXING_INTEGRATION.md** - SEO implementation (superseded by PUBLIC_API.md)
- **SUPABASE_SECRETS_GUIDE.md** - Secrets management (merged into INTEGRATIONS.md)

### Migration Guides
- **V2_TO_V3_MIGRATION_GUIDE.md** - Schema v2→v3 migration (historical)
- **PLATFORM_REQUIREMENTS_GAP_ANALYSIS.md** - Gap analysis (completed, moved from docs/)

### Implementation Notes
- **instructions.json** - Development instructions
- **ARCHITECTURE_DECISIONS.md** - Early design decisions (superseded by ARCHITECTURE.md)

---

## 📖 Current Documentation

**For up-to-date documentation, see:**

### Main Documentation (docs/ folder)
- **[ARCHITECTURE.md](../docs/ARCHITECTURE.md)** - Current system architecture
- **[ASYNC_ARCHITECTURE.md](../docs/ASYNC_ARCHITECTURE.md)** - Job queue system (NEW)
- **[DATABASE.md](../docs/DATABASE.md)** - Current database schema
- **[DATABASE_OPTIMIZATION.md](../docs/DATABASE_OPTIMIZATION.md)** - Performance optimization (NEW)
- **[INTEGRATIONS.md](../docs/INTEGRATIONS.md)** - OAuth, Stripe, AI, SEO
- **[PUBLIC_API.md](../docs/PUBLIC_API.md)** - Public discovery APIs (NEW)
- **[BACKEND_IMPLEMENTATION.md](../docs/BACKEND_IMPLEMENTATION.md)** - Complete API guide
- **[POSTMAN_GUIDE.md](../docs/POSTMAN_GUIDE.md)** - API testing
- **[MIGRATION_CHECKLIST.md](../docs/MIGRATION_CHECKLIST.md)** - Deployment checklist (NEW)

### Root Documentation
- **[README.md](../README.md)** - Project overview
- **[QUICK_START.md](../QUICK_START.md)** - 30-minute deployment guide
- **[IMPLEMENTATION_COMPLETE.md](../IMPLEMENTATION_COMPLETE.md)** - Implementation summary
- **[PUBLIC_DISCOVERY_SUMMARY.md](../PUBLIC_DISCOVERY_SUMMARY.md)** - Public API details

---

## 🗑️ Why Archived?

These documents served their purpose during initial design and development but are now replaced by:

1. **Consolidated Documentation** - Related topics merged into comprehensive guides
2. **Current Schema** - Live schema in `database/schema.sql` and migrations
3. **Implementation Reality** - Actual code in `supabase/functions/`
4. **Updated Architecture** - Async processing, public APIs, optimizations added

**Recommendation:** Refer to current documentation in `/docs` folder for accurate information.

---

**Last Updated:** November 7, 2025  
**Archive Created:** Development Phase 1-2 (Oct-Nov 2025)
