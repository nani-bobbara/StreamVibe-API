# StreamVibe API

> Video content aggregation platform for creators - sync, optimize, and distribute content across YouTube, Instagram, TikTok with AI-powered suggestions and SEO automation.

## 🎯 What is StreamVibe?

StreamVibe helps content creators manage their presence across multiple social media platforms from a single dashboard. Connect your YouTube, Instagram, TikTok, and Facebook accounts, sync content automatically, optimize with AI suggestions, and improve SEO indexing.

## ✨ Key Features

- **Multi-Platform Sync** - Automatically sync content from YouTube, Instagram, TikTok, Facebook, Twitter
- **AI Content Optimization** - Get AI-powered title, description, and tag suggestions
- **SEO Automation** - Submit URLs to Google, Bing, Yandex for faster indexing
- **Usage Quotas** - Fair usage-based billing with Stripe integration
- **Secure OAuth** - Platform credentials stored in Supabase Vault
- **Real-time Analytics** - Track views, likes, comments across all platforms

## 🏗️ Architecture

### Tech Stack

- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **Database**: PostgreSQL 15+ with pg_cron, Vault
- **Authentication**: Supabase Auth (Google, Facebook, Email)
- **Payments**: Stripe (subscriptions + metered billing)
- **AI**: OpenAI, Anthropic, Google AI
- **Deployment**: Edge Functions on Deno

### Core Components

1. **Database Schema** - Normalized PostgreSQL schema with 33 tables
2. **Edge Functions** - OAuth flows, content sync, AI analysis, SEO submission
3. **Supabase Vault** - Secure token storage for OAuth credentials
4. **Stripe Integration** - Subscription tiers + usage-based billing
5. **Row Level Security** - Database-level access control

## 📁 Project Structure

```
StreamVibe-API/
├── README.md                    # This file
├── docs/
│   ├── ARCHITECTURE.md          # System design & decisions
│   ├── DATABASE.md              # Schema design & guide
│   └── INTEGRATIONS.md          # OAuth, Stripe, AI, SEO setup
├── database/
│   ├── schema.sql               # Production database schema
│   └── migrations/              # Future migration files
├── supabase/
│   └── functions/               # Edge Functions (to be added)
└── archive/                     # Brainstorming documents
```

## 🚀 Quick Start

### Prerequisites

- Supabase account (Pro tier recommended)
- Stripe account
- API keys for platforms (YouTube, Instagram, TikTok)
- AI provider API keys (OpenAI, Anthropic, or Google)

### Setup

1. **Create Supabase Project**
   ```bash
   # Create new project at https://supabase.com/dashboard
   ```

2. **Deploy Database Schema**
   ```bash
   # Run the schema file in Supabase SQL Editor
   cat database/schema.sql | supabase db execute
   ```

3. **Configure Environment Variables**
   ```bash
   # Set up in Supabase Dashboard > Settings > Vault
   YOUTUBE_CLIENT_ID=...
   YOUTUBE_CLIENT_SECRET=...
   INSTAGRAM_CLIENT_ID=...
   INSTAGRAM_CLIENT_SECRET=...
   STRIPE_SECRET_KEY=...
   STRIPE_WEBHOOK_SECRET=...
   OPENAI_API_KEY=...
   ```

4. **Deploy Edge Functions**
   ```bash
   # Coming soon
   supabase functions deploy
   ```

## 💰 Pricing Tiers

| Tier | Price | Accounts | Syncs/Month | AI Analyses | SEO Submissions |
|------|-------|----------|-------------|-------------|-----------------|
| Free | $0 | 1 | 10 | 25 | 0 |
| Basic | $19 | 3 | 100 | 100 | 50 |
| Premium | $49 | 10 | 500 | 500 | 200 |

## 📚 Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)** - System design, caching strategy, security
- **[Database Guide](docs/DATABASE.md)** - Schema reference, RLS policies, functions
- **[Integrations Guide](docs/INTEGRATIONS.md)** - OAuth, Stripe, AI, SEO setup

## 🔐 Security

- **Vault Storage** - OAuth tokens never stored in database tables
- **Row Level Security** - User data isolated at database level
- **Webhook Verification** - All Stripe webhooks verified
- **HTTPS Only** - All API communication encrypted
- **Token Rotation** - Automatic OAuth token refresh

## 📊 Database Overview

- **33 Tables** - 8 lookup tables, 24 data tables, 1 junction table
- **5 Enums** - Visibility, roles, notification types, action modes
- **7 Functions** - Quota management, role checks, triggers
- **60+ Indexes** - Composite, partial, GIN for optimal performance
- **RLS Policies** - Comprehensive row-level security

## 🛣️ Roadmap

### Phase 1: Database & Auth (Weeks 1-2)
- [x] Design normalized schema
- [x] Document architecture decisions
- [ ] Deploy to Supabase
- [ ] Configure OAuth providers

### Phase 2: Edge Functions (Weeks 3-4)
- [ ] OAuth flow functions
- [ ] Content sync functions
- [ ] Stripe webhook handler
- [ ] AI analysis functions
- [ ] SEO submission functions

### Phase 3: Frontend (Weeks 5-7)
- [ ] Authentication UI
- [ ] Dashboard with analytics
- [ ] Platform connection flow
- [ ] Content management
- [ ] AI suggestions panel
- [ ] Subscription management

### Phase 4: Testing & Launch (Weeks 8-9)
- [ ] End-to-end testing
- [ ] Performance optimization
- [ ] Security audit
- [ ] Production deployment

## 🤝 Contributing

This is currently a private project in initial development. Contributions will be welcome after the first stable release.

## 📝 License

Proprietary - All rights reserved

## 📧 Contact

For questions or collaboration: [Your Contact Info]

---

**Current Status**: 🟡 Initial Development Phase  
**Last Updated**: November 1, 2025  
**Version**: 3.0.0
