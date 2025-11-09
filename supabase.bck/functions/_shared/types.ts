// Database types
export interface Database {
  public: {
    Tables: {
      users: {
        Row: {
          id: string
          email: string
          display_name: string | null
          bio: string | null
          avatar_url: string | null
          website_url: string | null
          location: string | null
          is_verified: boolean
          profile_slug: string | null
          primary_category: string | null
          total_followers_count: number
          profile_views_count: number
          profile_clicks_count: number
          is_public: boolean
          seo_title: string | null
          seo_description: string | null
          role: 'user' | 'admin'
          created_at: string
          updated_at: string
        }
      }
      content_item: {
        Row: {
          id: string
          user_id: string
          social_account_id: string
          platform_id: string
          platform_content_id: string
          content_type: string
          title: string
          description: string | null
          ai_description: string | null
          media_url: string
          thumbnail_url: string | null
          duration_seconds: number | null
          published_at: string
          views_count: number
          likes_count: number
          comments_count: number
          shares_count: number
          total_clicks: number
          clicks_last_7_days: number
          clicks_last_30_days: number
          category_code: string | null
          seo_title: string | null
          seo_description: string | null
          canonical_url: string | null
          embed_html: string | null
          created_at: string
          updated_at: string
        }
      }
      content_tag: {
        Row: {
          id: string
          content_id: string
          tag: string
          source: 'ai_generated' | 'platform_original' | 'user_added'
          confidence_score: number | null
          tag_type: 'keyword' | 'topic' | 'entity' | 'emotion' | 'trend' | 'hashtag'
          created_at: string
        }
      }
      content_category: {
        Row: {
          code: string
          name: string
          description: string | null
          parent_category: string | null
          icon_name: string | null
          sort_order: number
          is_active: boolean
          created_at: string
        }
      }
    }
  }
}

// API Request/Response types
export interface ProfileSetupRequest {
  display_name: string
  bio?: string
  avatar_url?: string
  primary_category?: string
  website_url?: string
  location?: string
}

export interface ProfileSetupResponse {
  success: boolean
  profile: {
    user_id: string
    display_name: string
    profile_slug: string
    profile_url: string
  }
}

export interface OAuthInitResponse {
  success: boolean
  authorization_url: string
  state: string
}

export interface OAuthCallbackRequest {
  code: string
  state: string
}

export interface OAuthCallbackResponse {
  success: boolean
  platform: string
  social_account_id: string
  account_username: string
}

export interface ContentSyncRequest {
  social_account_id: string
  force_full_sync?: boolean
}

export interface ContentSyncResponse {
  success: boolean
  synced_count: number
  new_count: number
  updated_count: number
  errors: string[]
}

export interface AITagGenerationRequest {
  content_id: string
}

export interface AITagGenerationResponse {
  success: boolean
  tags: Array<{
    tag: string
    confidence_score: number
    tag_type: string
  }>
  ai_description: string
}

export interface SearchRequest {
  q: string // Search query
  category?: string
  platform?: string
  limit?: number
  offset?: number
}

export interface SearchCreatorsResponse {
  success: boolean
  results: Array<{
    user_id: string
    display_name: string
    bio: string
    avatar_url: string
    profile_slug: string
    primary_category: string
    total_followers_count: number
    is_verified: boolean
  }>
  total: number
}

export interface SearchContentResponse {
  success: boolean
  results: Array<{
    id: string
    title: string
    description: string
    thumbnail_url: string
    creator: {
      display_name: string
      profile_slug: string
      avatar_url: string
    }
    platform: string
    views_count: number
    published_at: string
    category: string
  }>
  total: number
}

export interface ClickTrackRequest {
  content_id: string
  referrer?: string
}

export interface ClickTrackResponse {
  success: boolean
  redirect_url: string
}

// Error response
export interface ErrorResponse {
  success: false
  error: {
    code: string
    message: string
    details?: unknown
  }
}

// Helper type for API responses
export type ApiResponse<T> = T | ErrorResponse
