import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Get creator by slug function started')

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    const slug = url.searchParams.get('slug')

    if (!slug) {
      throw new Error('slug parameter is required')
    }

    // Get creator profile
    const { data: creator, error } = await supabase
      .from('users')
      .select(`
        id,
        display_name,
        bio,
        avatar_url,
        website_url,
        location,
        is_verified,
        profile_slug,
        primary_category,
        total_followers_count,
        profile_views_count,
        profile_clicks_count,
        created_at,
        social_account (
          id,
          platform,
          handle,
          followers_count
        )
      `)
      .eq('profile_slug', slug)
      .eq('is_public', true)
      .single()

    if (error || !creator) {
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: 'NOT_FOUND',
            message: 'Creator not found',
          },
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Get creator's content (latest 20)
    const { data: content } = await supabase
      .from('content_item')
      .select('id, title, thumbnail_url, content_type, views_count, likes_count, published_at')
      .eq('user_id', creator.id)
      .order('published_at', { ascending: false })
      .limit(20)

    // Increment profile view count (fire and forget)
    supabase
      .from('users')
      .update({ profile_views_count: (creator.profile_views_count || 0) + 1 })
      .eq('id', creator.id)
      .then()

    return new Response(
      JSON.stringify({
        success: true,
        creator: {
          ...creator,
          recent_content: content || [],
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Error in get-creator-by-slug:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'GET_CREATOR_ERROR',
        message: error instanceof Error ? error.message : 'Failed to get creator',
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
