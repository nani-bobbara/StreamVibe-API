import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Search content function started')

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    const query = url.searchParams.get('query') || ''
    const category = url.searchParams.get('category')
    const contentType = url.searchParams.get('content_type')
    const limit = parseInt(url.searchParams.get('limit') || '20')
    const offset = parseInt(url.searchParams.get('offset') || '0')

    if (!query) {
      throw new Error('query parameter is required')
    }

    // PUBLIC ENDPOINT - Only return public content
    let dbQuery = supabase
      .from('content_item')
      .select(`
        id,
        title,
        description,
        thumbnail_url,
        content_url,
        content_type,
        views_count,
        likes_count,
        published_at,
        user_id,
        users (display_name, profile_slug, avatar_url)
      `)
      .eq('visibility', 'public')
      .is('deleted_at', null)
      .textSearch('search_vector', query, {
        type: 'websearch',
        config: 'english',
      })
      .order('views_count', { ascending: false })
      .range(offset, offset + limit - 1)

    if (category) {
      dbQuery = dbQuery.eq('category_code', category)
    }

    if (contentType) {
      dbQuery = dbQuery.eq('content_type', contentType)
    }

    const { data: content, error } = await dbQuery

    if (error) {
      throw error
    }

    return new Response(
      JSON.stringify({
        success: true,
        results: content,
        count: content.length,
        query,
        offset,
        limit,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Error in search-content:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'SEARCH_ERROR',
        message: error instanceof Error ? error.message : 'Search failed',
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
