import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Search creators function started')

interface SearchRequest {
  query: string
  category?: string
  verified_only?: boolean
  limit?: number
  offset?: number
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    const query = url.searchParams.get('query') || ''
    const category = url.searchParams.get('category')
    const verifiedOnly = url.searchParams.get('verified_only') === 'true'
    const limit = parseInt(url.searchParams.get('limit') || '20')
    const offset = parseInt(url.searchParams.get('offset') || '0')

    if (!query) {
      throw new Error('query parameter is required')
    }

    // Build query
    let dbQuery = supabase
      .from('users')
      .select('id, display_name, bio, avatar_url, profile_slug, primary_category, total_followers_count, is_verified, created_at')
      .eq('is_public', true)
      .textSearch('search_vector', query, {
        type: 'websearch',
        config: 'english',
      })
      .order('total_followers_count', { ascending: false })
      .range(offset, offset + limit - 1)

    if (category) {
      dbQuery = dbQuery.eq('primary_category', category)
    }

    if (verifiedOnly) {
      dbQuery = dbQuery.eq('is_verified', true)
    }

    const { data: creators, error } = await dbQuery

    if (error) {
      throw error
    }

    return new Response(
      JSON.stringify({
        success: true,
        results: creators,
        count: creators.length,
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
    console.error('Error in search-creators:', error)

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
