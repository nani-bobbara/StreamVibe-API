# StreamVibe Database - Entity Relationship Diagram

## Complete ER Diagram

```mermaid
erDiagram
    %% ============================================
    %% LOOKUP TABLES (System Configuration)
    %% ============================================
    
    platform {
        uuid id PK
        text slug UK "youtube, instagram, tiktok"
        text display_name
        text description
        text website_url
        text logo_url
        text api_docs_url
        boolean is_oauth_required
        boolean is_active
        integer sort_order
        timestamptz created_at
        timestamptz updated_at
    }
    
    content_type {
        uuid id PK
        text slug UK "long_video, short_video, image"
        text display_name
        text description
        boolean is_active
        integer sort_order
        timestamptz created_at
        timestamptz updated_at
    }
    
    subscription_tier {
        uuid id PK
        text slug UK "free, basic, premium"
        text display_name
        text description
        integer max_social_accounts
        integer max_syncs_per_month
        integer max_ai_analyses_per_month
        integer max_seo_submissions_per_month
        integer price_cents
        text currency
        text stripe_price_id
        text stripe_product_id
        boolean is_featured
        boolean is_active
        integer sort_order
        timestamptz created_at
        timestamptz updated_at
    }
    
    subscription_status {
        uuid id PK
        text slug UK "active, trialing, canceled"
        text display_name
        text description
        boolean is_active_state
        timestamptz created_at
    }
    
    account_status {
        uuid id PK
        text slug UK "active, inactive, suspended"
        text display_name
        text description
        timestamptz created_at
    }
    
    ai_provider {
        uuid id PK
        text slug UK "openai, anthropic, google"
        text display_name
        text base_url
        boolean is_api_key_required
        boolean is_streaming_supported
        boolean is_active
        timestamptz created_at
        timestamptz updated_at
    }
    
    search_engine {
        uuid id PK
        text slug UK "google, bing, yandex"
        text display_name
        text api_endpoint
        text api_docs_url
        boolean supports_indexnow
        boolean is_active
        timestamptz created_at
        timestamptz updated_at
    }
    
    %% ============================================
    %% CORE USER TABLES
    %% ============================================
    
    users {
        uuid id PK "From auth.users"
        text email
        text full_name
        text avatar_url
        text timezone
        text language
        boolean is_onboarded
        timestamptz onboarded_at
        timestamptz created_at
        timestamptz updated_at
    }
    
    user_setting {
        uuid user_id PK FK
        boolean is_email_notifications_enabled
        boolean is_push_notifications_enabled
        boolean is_weekly_digest_enabled
        boolean is_auto_sync_enabled
        integer sync_frequency_hours
        boolean is_auto_ai_analysis_enabled
        boolean is_auto_apply_ai_suggestions_enabled
        boolean is_auto_seo_submission_enabled
        boolean is_profile_public
        boolean is_analytics_enabled
        timestamptz created_at
        timestamptz updated_at
    }
    
    user_role {
        uuid id PK
        uuid user_id FK
        app_role_enum role "user, admin, moderator"
        text granted_by
        timestamptz granted_at
        timestamptz expires_at
        timestamptz created_at
    }
    
    %% ============================================
    %% SUBSCRIPTION & BILLING
    %% ============================================
    
    subscription {
        uuid id PK
        uuid user_id UK FK
        uuid tier_id FK
        uuid status_id FK
        integer syncs_used
        integer ai_analyses_used
        integer seo_submissions_used
        timestamptz cycle_start_date
        timestamptz cycle_end_date
        timestamptz next_billing_date
        text stripe_customer_id
        text stripe_subscription_id
        text stripe_subscription_item_id_syncs
        text stripe_subscription_item_id_ai
        text stripe_subscription_item_id_seo
        boolean is_auto_renew_enabled
        timestamptz canceled_at
        text cancellation_reason
        timestamptz created_at
        timestamptz updated_at
    }
    
    quota_usage_history {
        uuid id PK
        uuid user_id FK
        text quota_type "sync, ai_analysis, seo_submission"
        text operation "increment, decrement, reset"
        integer amount
        integer current_value
        integer max_value
        text related_entity_type
        uuid related_entity_id
        text reason
        timestamptz billing_cycle_start
        timestamptz billing_cycle_end
        timestamptz created_at
    }
    
    %% ============================================
    %% PLATFORM INTEGRATION
    %% ============================================
    
    platform_connection {
        uuid id PK
        uuid user_id FK
        uuid platform_id FK
        text vault_secret_name UK "Vault reference only"
        text[] scopes
        timestamptz token_expires_at
        text platform_user_id
        text platform_username
        text platform_display_name
        text platform_avatar_url
        boolean is_active
        boolean is_verified
        timestamptz last_verified_at
        text last_error
        timestamptz created_at
        timestamptz updated_at
    }
    
    social_account {
        uuid id PK
        uuid user_id FK "Denormalized"
        uuid connection_id FK
        uuid platform_id FK
        uuid status_id FK
        text account_name
        text account_url
        text description
        integer follower_count
        integer following_count
        integer post_count
        action_mode_enum sync_mode "auto, manual, disabled"
        timestamptz last_synced_at
        text last_sync_status
        timestamptz next_sync_at
        visibility_enum visibility
        boolean is_primary
        timestamptz deleted_at
        timestamptz created_at
        timestamptz updated_at
    }
    
    content_item {
        uuid id PK
        uuid social_account_id FK
        uuid platform_id FK "Denormalized"
        uuid content_type_id FK
        text platform_content_id
        text platform_url
        text title
        text description
        text thumbnail_url
        text media_url
        integer duration_seconds
        integer views_count
        integer likes_count
        integer comments_count
        integer shares_count
        text[] tags
        text[] hashtags
        text category
        text language
        tsvector search_vector "Generated column"
        timestamptz published_at
        timestamptz synced_at
        visibility_enum visibility
        timestamptz deleted_at
        timestamptz created_at
        timestamptz updated_at
    }
    
    content_revision {
        uuid id PK
        uuid content_item_id FK
        uuid user_id FK
        text field_name
        text old_value
        text new_value
        text change_source "manual, ai_suggestion, bulk_edit"
        text change_reason
        timestamptz created_at
    }
    
    %% ============================================
    %% AI INTEGRATION
    %% ============================================
    
    ai_model {
        uuid id PK
        uuid provider_id FK
        text model_name
        text display_name
        text[] capabilities
        integer max_context_tokens
        decimal input_cost_per_1k_tokens
        decimal output_cost_per_1k_tokens
        boolean is_active
        timestamptz created_at
        timestamptz updated_at
    }
    
    user_ai_setting {
        uuid user_id PK FK
        uuid preferred_provider_id FK
        uuid preferred_model_id FK
        text tone "professional, casual, enthusiastic"
        text language
        timestamptz created_at
        timestamptz updated_at
    }
    
    ai_suggestion {
        uuid id PK
        uuid content_item_id FK
        uuid provider_id FK
        uuid model_id FK
        text[] suggested_titles
        text suggested_description
        text[] suggested_tags
        text suggested_category
        text[] trending_keywords
        text[] trending_hashtags
        text[] related_topics
        decimal trending_score
        decimal seo_score
        decimal readability_score
        decimal confidence_score
        text sentiment
        text[] target_audience
        integer prompt_tokens
        integer completion_tokens
        decimal total_cost_cents
        integer processing_time_ms
        boolean is_applied
        timestamptz applied_at
        integer version
        timestamptz created_at
        timestamptz updated_at
    }
    
    ai_suggestion_application {
        uuid id PK
        uuid suggestion_id FK
        text applied_field "title, description, tags"
        text applied_value
        uuid applied_by_user_id FK
        timestamptz applied_at
    }
    
    ai_usage {
        uuid id PK
        uuid user_id FK
        uuid provider_id FK
        uuid model_id FK
        uuid content_item_id FK
        text operation_type
        integer prompt_tokens
        integer completion_tokens
        integer total_tokens
        decimal cost_cents
        integer processing_time_ms
        timestamptz billing_cycle_start
        timestamptz billing_cycle_end
        timestamptz created_at
    }
    
    trending_keyword {
        uuid id PK
        uuid platform_id FK
        text keyword
        text category
        decimal trending_score
        integer search_volume
        text competition_level
        text source
        text region
        text language
        timestamptz valid_from
        timestamptz valid_until
        timestamptz created_at
    }
    
    %% ============================================
    %% SEO INTEGRATION
    %% ============================================
    
    seo_connection {
        uuid id PK
        uuid user_id FK
        uuid search_engine_id FK
        text vault_secret_name "Vault reference"
        text site_url
        boolean is_active
        boolean is_verified
        timestamptz last_verified_at
        text last_error
        timestamptz created_at
        timestamptz updated_at
    }
    
    seo_submission {
        uuid id PK
        uuid content_item_id FK
        uuid connection_id FK
        uuid search_engine_id FK
        text submitted_url
        text submission_type
        text submission_method
        jsonb request_payload
        integer response_status
        jsonb response_body
        text status "pending, submitted, indexed"
        timestamptz status_checked_at
        text index_status_url
        text coverage_state
        text error_message
        integer retry_count
        timestamptz next_retry_at
        timestamptz submitted_at
        timestamptz indexed_at
        timestamptz created_at
        timestamptz updated_at
    }
    
    seo_usage {
        uuid id PK
        uuid user_id FK
        uuid search_engine_id FK
        uuid content_item_id FK
        text operation_type
        integer urls_count
        timestamptz billing_cycle_start
        timestamptz billing_cycle_end
        timestamptz created_at
    }
    
    %% ============================================
    %% SYSTEM TABLES
    %% ============================================
    
    notification {
        uuid id PK
        uuid user_id FK
        notification_type_enum type
        text title
        text message
        text action_url
        text action_label
        jsonb metadata
        text related_entity_type
        uuid related_entity_id
        boolean is_read
        timestamptz read_at
        timestamptz expires_at
        timestamptz created_at
        timestamptz updated_at
    }
    
    audit_log {
        uuid id PK
        uuid user_id FK
        text action
        text entity_type
        uuid entity_id
        jsonb old_values
        jsonb new_values
        inet ip_address
        text user_agent
        timestamptz created_at
    }
    
    cache_store {
        text key PK
        jsonb value
        text category
        timestamptz expires_at
        timestamptz created_at
        timestamptz updated_at
    }
    
    %% ============================================
    %% RELATIONSHIPS
    %% ============================================
    
    %% User relationships
    users ||--o| user_setting : "has preferences"
    users ||--o{ user_role : "has roles"
    users ||--o| subscription : "has subscription"
    users ||--o{ platform_connection : "connects platforms"
    users ||--o{ social_account : "owns accounts"
    users ||--o| user_ai_setting : "has AI preferences"
    users ||--o{ seo_connection : "connects search engines"
    users ||--o{ notification : "receives"
    users ||--o{ audit_log : "performs actions"
    users ||--o{ quota_usage_history : "tracks usage"
    
    %% Subscription relationships
    subscription }o--|| subscription_tier : "belongs to tier"
    subscription }o--|| subscription_status : "has status"
    subscription ||--o{ quota_usage_history : "tracks"
    
    %% Platform integration
    platform ||--o{ platform_connection : "available on"
    platform ||--o{ social_account : "hosted on"
    platform ||--o{ content_item : "synced from"
    platform ||--o{ trending_keyword : "trends on"
    
    platform_connection ||--o{ social_account : "enables"
    platform_connection }o--|| users : "owned by"
    
    social_account }o--|| account_status : "has status"
    social_account ||--o{ content_item : "contains"
    
    content_type ||--o{ content_item : "categorizes"
    
    content_item ||--o{ content_revision : "tracks changes"
    content_item ||--o{ ai_suggestion : "receives suggestions"
    content_item ||--o{ seo_submission : "submitted for indexing"
    content_item ||--o{ ai_usage : "analyzed by AI"
    content_item ||--o{ seo_usage : "indexed"
    
    content_revision }o--|| users : "made by"
    
    %% AI relationships
    ai_provider ||--o{ ai_model : "provides"
    ai_provider ||--o{ user_ai_setting : "preferred"
    ai_provider ||--o{ ai_suggestion : "generates"
    ai_provider ||--o{ ai_usage : "used for"
    
    ai_model ||--o{ user_ai_setting : "preferred"
    ai_model ||--o{ ai_suggestion : "created with"
    ai_model ||--o{ ai_usage : "tracks"
    
    user_ai_setting }o--|| users : "belongs to"
    
    ai_suggestion ||--o{ ai_suggestion_application : "applied as"
    ai_suggestion_application }o--|| users : "applied by"
    
    ai_usage }o--|| users : "consumed by"
    
    %% SEO relationships
    search_engine ||--o{ seo_connection : "connects to"
    search_engine ||--o{ seo_submission : "submitted to"
    search_engine ||--o{ seo_usage : "tracks"
    
    seo_connection ||--o{ seo_submission : "submits via"
    seo_connection }o--|| users : "owned by"
    
    seo_usage }o--|| users : "consumed by"
    
    %% System relationships
    notification }o--|| users : "sent to"
    audit_log }o--|| users : "logged by"
```

## Entity Descriptions

### 🔐 Lookup Tables (System Configuration)

| Entity | Purpose | Key Fields | Records |
|--------|---------|------------|---------|
| **platform** | Supported social media platforms | slug, display_name, is_oauth_required | 5 (YouTube, Instagram, TikTok, Facebook, Twitter) |
| **content_type** | Types of content | slug, display_name | 7 (long_video, short_video, image, carousel, story, reel, post) |
| **subscription_tier** | Pricing tiers with quotas | slug, max_syncs_per_month, price_cents, stripe_price_id | 3 (free, basic, premium) |
| **subscription_status** | Subscription states | slug, is_active_state | 5 (active, trialing, past_due, canceled, paused) |
| **account_status** | Social account connection states | slug, display_name | 4 (active, inactive, suspended, disconnected) |
| **ai_provider** | AI service providers | slug, base_url, is_api_key_required | 4 (OpenAI, Anthropic, Google, Local) |
| **search_engine** | SEO indexing services | slug, api_endpoint, supports_indexnow | 4 (Google, Bing, Yandex, IndexNow) |

### 👤 User Management

| Entity | Purpose | Key Fields | Notes |
|--------|---------|------------|-------|
| **users** | User profiles | email, full_name, is_onboarded | Extends auth.users (Supabase Auth) |
| **user_setting** | User preferences | is_auto_sync_enabled, sync_frequency_hours | 1:1 with users |
| **user_role** | Role assignments | user_id, role (enum), granted_at | Junction table, supports multiple roles |

### 💳 Subscription & Billing

| Entity | Purpose | Key Fields | Notes |
|--------|---------|------------|-------|
| **subscription** | User subscriptions + usage | syncs_used, ai_analyses_used, stripe_customer_id | 1:1 with users, tracks quotas |
| **quota_usage_history** | Historical quota tracking | quota_type, operation, amount, current_value | Analytics & billing reconciliation |

### 🔗 Platform Integration

| Entity | Purpose | Key Fields | Notes |
|--------|---------|------------|-------|
| **platform_connection** | OAuth connections | vault_secret_name, token_expires_at | Vault reference only, NOT actual tokens |
| **social_account** | Connected accounts/channels | account_name, follower_count, sync_mode | Multiple per user, per platform |
| **content_item** | Synced content | title, description, tags, search_vector | Main content table with full-text search |
| **content_revision** | Content edit history | field_name, old_value, new_value, change_source | Audit trail for modifications |

### 🤖 AI Integration

| Entity | Purpose | Key Fields | Notes |
|--------|---------|------------|-------|
| **ai_model** | Available AI models | model_name, max_context_tokens, cost_per_1k_tokens | Model catalog with pricing |
| **user_ai_setting** | User AI preferences | preferred_model_id, tone, language | 1:1 with users |
| **ai_suggestion** | AI-generated suggestions | suggested_titles, trending_keywords, seo_score | Multiple suggestions per content |
| **ai_suggestion_application** | Applied suggestions tracking | applied_field, applied_value | Junction table |
| **ai_usage** | AI API usage tracking | prompt_tokens, completion_tokens, cost_cents | For billing & analytics |
| **trending_keyword** | Cached trending data | keyword, trending_score, search_volume | External API cache |

### 🔍 SEO Integration

| Entity | Purpose | Key Fields | Notes |
|--------|---------|------------|-------|
| **seo_connection** | Search engine API connections | vault_secret_name, site_url | Vault reference for credentials |
| **seo_submission** | URL submissions | submitted_url, status, indexed_at | Tracks indexing progress |
| **seo_usage** | SEO API usage tracking | operation_type, urls_count | For billing |

### 🛠️ System Tables

| Entity | Purpose | Key Fields | Notes |
|--------|---------|------------|-------|
| **notification** | User notifications | type (enum), title, message, is_read | In-app notifications |
| **audit_log** | Complete action audit trail | action, entity_type, old_values, new_values | Security & compliance |
| **cache_store** | Multi-purpose cache | key (PK), value (JSONB), expires_at | For Stripe data, trends, etc. |

## Key Design Patterns

### 🔐 Security Patterns

1. **Vault Storage**: OAuth tokens stored in Supabase Vault, only references in database
   - `platform_connection.vault_secret_name` → Vault
   - `seo_connection.vault_secret_name` → Vault

2. **Row Level Security (RLS)**: All user-facing tables have RLS policies
   - Users can only access their own data
   - Public content visible based on visibility settings
   - Admins can bypass restrictions

3. **Derived Ownership**: Reduce data duplication
   - `content_item` doesn't have `user_id` directly
   - Ownership derived: `content_item → social_account → user_id`

### 📊 Performance Patterns

1. **Denormalization for Performance**:
   - `social_account.user_id` (denormalized from connection)
   - `content_item.platform_id` (denormalized from social_account)

2. **Generated Columns**:
   - `content_item.search_vector` (auto-maintained full-text search)

3. **Composite Indexes**:
   - `(social_account_id, published_at DESC)` for content queries
   - `(user_id, platform_id)` for connection lookups

4. **Partial Indexes**:
   - `WHERE is_active = true` (90% smaller than full index)
   - `WHERE deleted_at IS NULL`

### 🔄 Billing Patterns

1. **Quota Tracking**: Real-time usage counters
   - `subscription.syncs_used` (incremented on each sync)
   - `subscription.ai_analyses_used`
   - `subscription.seo_submissions_used`

2. **Usage History**: Historical analytics
   - `quota_usage_history` (every increment/decrement logged)
   - `ai_usage` (detailed AI API usage)
   - `seo_usage` (detailed SEO API usage)

3. **Stripe Integration**:
   - `subscription.stripe_customer_id`
   - `subscription.stripe_subscription_id`
   - Webhook-driven updates

## Relationship Summary

| Parent | Child | Type | Notes |
|--------|-------|------|-------|
| users | subscription | 1:1 | One subscription per user |
| users | platform_connection | 1:N | Multiple platforms per user |
| platform_connection | social_account | 1:N | Multiple accounts per connection |
| social_account | content_item | 1:N | Multiple content per account |
| content_item | ai_suggestion | 1:N | Multiple AI suggestions per content |
| ai_suggestion | ai_suggestion_application | 1:N | Track which suggestions applied |
| content_item | seo_submission | 1:N | Submit to multiple search engines |
| subscription | subscription_tier | N:1 | Many subscriptions to one tier |

## Total Count: 33 Tables

- **Lookup**: 8 tables
- **User/Auth**: 3 tables
- **Subscription**: 2 tables
- **Platform**: 4 tables
- **AI**: 6 tables
- **SEO**: 3 tables
- **System**: 3 tables
- **Usage Tracking**: 4 tables
