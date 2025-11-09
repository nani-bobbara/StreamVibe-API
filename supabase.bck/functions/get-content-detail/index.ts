import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Get content detail function started')

/**
 * PUBLIC ENDPOINT - No authentication required
 * Get detailed information about a single content item
 * Used by: Anonymous users, Search engines, Content detail pages
 * Increments view count on each request
 */

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // NO AUTH CHECK - This is a public endpoint
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    const contentId = url.searchParams.get('id')

    if (!contentId) {
      throw new Error('id parameter is required')
    }

    // Get content item with full details
    const { data: content, error } = await supabase
      .from('content_item')
      .select(`
        id,
        title,
        description,
        thumbnail_url,
        media_url,
        platform_url,
        duration_seconds,
        views_count,
        likes_count,
        comments_count,
        shares_count,
        published_at,
        category,
        tags,
        hashtags,
        language,
        seo_title,
        seo_description,
        seo_keywords,
        created_at,
        platform:platform_id (
          id,
          slug,
          display_name,
          logo_url,
          website_url
        ),
        content_type:content_type_id (
          id,
          slug,
          display_name
        ),
        social_account:social_account_id (
          id,
          account_name,
          account_url,
          description,
          follower_count,
          user:user_id (
            id,
            display_name,
            bio,
            avatar_url,
            profile_slug,
            is_verified,
            total_followers_count
          )
        ),
        content_media (
          id,
          media_url,
          media_type,
          thumbnail_url,
          display_order
        )
      `)
      .eq('id', contentId)
      .eq('visibility', 'public')
      .is('deleted_at', null)
      .single()

    if (error || !content) {
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: 'NOT_FOUND',
            message: 'Content not found or not public',
          },
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Get related content tags
    const { data: contentTags } = await supabase
      .from('content_tag')
      .select(`
        tag_name,
        tag_type,
        confidence_score,
        source
      `)
      .eq('content_item_id', contentId)
      .order('confidence_score', { ascending: false })
      .limit(20)

    // Get related content from same creator
    const { data: relatedContent } = await supabase
      .from('content_item')
      .select('id, title, thumbnail_url, views_count, published_at')
      .eq('social_account_id', content.social_account.id)
      .neq('id', contentId)
      .eq('visibility', 'public')
      .is('deleted_at', null)
      .order('published_at', { ascending: false })
      .limit(6)

    // Increment view count (fire and forget)
    supabase.rpc('increment_content_views', { content_id: contentId }).then()

    return new Response(
      JSON.stringify({
        success: true,
        content: {
          ...content,
          ai_tags: contentTags || [],
          related_content: relatedContent || [],
        },
      }),
      {
        status: 200,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300', // Cache for 5 minutes
        },
      }
    )

  } catch (error) {
    console.error('Error in get-content-detail:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'GET_CONTENT_ERROR',
        message: error instanceof Error ? error.message : 'Failed to get content',
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
