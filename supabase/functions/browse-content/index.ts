import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Browse content function started')

/**
 * PUBLIC ENDPOINT - No authentication required
 * Browse all public content items with filtering and pagination
 * Used by: Anonymous users, Search engines, Front-end discovery feeds
 */

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // NO AUTH CHECK - This is a public endpoint
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    // Parse query parameters
    const category = url.searchParams.get('category')
    const platform = url.searchParams.get('platform')
    const contentType = url.searchParams.get('content_type')
    const creatorSlug = url.searchParams.get('creator_slug')
    const sortBy = (url.searchParams.get('sort_by') || 'recent') as 'recent' | 'popular' | 'trending'
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100) // Max 100
    const offset = parseInt(url.searchParams.get('offset') || '0')

    // Build query for public content only
    let dbQuery = supabase
      .from('content_item')
      .select(`
        id,
        title,
        description,
        thumbnail_url,
        platform_url,
        duration_seconds,
        views_count,
        likes_count,
        comments_count,
        published_at,
        category,
        tags,
        hashtags,
        seo_title,
        seo_description,
        platform:platform_id (
          slug,
          display_name,
          logo_url
        ),
        content_type:content_type_id (
          slug,
          display_name
        ),
        social_account:social_account_id (
          id,
          account_name,
          account_url,
          user:user_id (
            id,
            display_name,
            avatar_url,
            profile_slug,
            is_verified
          )
        )
      `)
      .eq('visibility', 'public')
      .is('deleted_at', null)

    // Apply filters
    if (category) {
      dbQuery = dbQuery.eq('category', category)
    }

    if (platform) {
      dbQuery = dbQuery.eq('platform.slug', platform)
    }

    if (contentType) {
      dbQuery = dbQuery.eq('content_type.slug', contentType)
    }

    if (creatorSlug) {
      dbQuery = dbQuery.eq('social_account.user.profile_slug', creatorSlug)
    }

    // Apply sorting
    switch (sortBy) {
      case 'recent':
        dbQuery = dbQuery.order('published_at', { ascending: false })
        break
      case 'popular':
        dbQuery = dbQuery.order('views_count', { ascending: false })
        break
      case 'trending':
        // Trending = (views * 0.7 + likes * 0.3) / age_days
        dbQuery = dbQuery.order('trending_score', { ascending: false })
        break
    }

    // Apply pagination
    dbQuery = dbQuery.range(offset, offset + limit - 1)

    const { data: content, error } = await dbQuery

    if (error) {
      throw error
    }

    // Get total count for pagination
    const { count: totalCount } = await supabase
      .from('content_item')
      .select('id', { count: 'exact', head: true })
      .eq('visibility', 'public')
      .is('deleted_at', null)

    return new Response(
      JSON.stringify({
        success: true,
        content: content || [],
        pagination: {
          total: totalCount || 0,
          limit,
          offset,
          has_more: (offset + limit) < (totalCount || 0),
        },
        filters: {
          category,
          platform,
          content_type: contentType,
          creator_slug: creatorSlug,
          sort_by: sortBy,
        },
      }),
      {
        status: 200,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=180', // Cache for 3 minutes
        },
      }
    )

  } catch (error) {
    console.error('Error in browse-content:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'BROWSE_CONTENT_ERROR',
        message: error instanceof Error ? error.message : 'Failed to browse content',
      },
    }

    return new Response(
      JSON.stringify(errorResponse),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
