import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Browse creators function started')

/**
 * PUBLIC ENDPOINT - No authentication required
 * Browse all public creator profiles with filtering and pagination
 * Used by: Anonymous users, Search engines, Front-end discovery pages
 */

interface BrowseParams {
  category?: string
  verified_only?: boolean
  min_followers?: number
  sort_by?: 'followers' | 'recent' | 'popular'
  limit?: number
  offset?: number
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // NO AUTH CHECK - This is a public endpoint
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    // Parse query parameters
    const category = url.searchParams.get('category')
    const verifiedOnly = url.searchParams.get('verified_only') === 'true'
    const minFollowers = parseInt(url.searchParams.get('min_followers') || '0')
    const sortBy = (url.searchParams.get('sort_by') || 'followers') as 'followers' | 'recent' | 'popular'
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100) // Max 100
    const offset = parseInt(url.searchParams.get('offset') || '0')

    // Build query for public creators only
    let dbQuery = supabase
      .from('users')
      .select(`
        id,
        display_name,
        bio,
        avatar_url,
        profile_slug,
        primary_category,
        total_followers_count,
        is_verified,
        created_at,
        social_account!inner (
          id,
          platform_id,
          account_name,
          follower_count,
          visibility
        )
      `)
      .eq('is_public', true)

    // Apply filters
    if (category) {
      dbQuery = dbQuery.eq('primary_category', category)
    }

    if (verifiedOnly) {
      dbQuery = dbQuery.eq('is_verified', true)
    }

    if (minFollowers > 0) {
      dbQuery = dbQuery.gte('total_followers_count', minFollowers)
    }

    // Apply sorting
    switch (sortBy) {
      case 'followers':
        dbQuery = dbQuery.order('total_followers_count', { ascending: false })
        break
      case 'recent':
        dbQuery = dbQuery.order('created_at', { ascending: false })
        break
      case 'popular':
        dbQuery = dbQuery.order('profile_views_count', { ascending: false })
        break
    }

    // Apply pagination
    dbQuery = dbQuery.range(offset, offset + limit - 1)

    const { data: creators, error, count } = await dbQuery

    if (error) {
      throw error
    }

    // Get total count for pagination
    const { count: totalCount } = await supabase
      .from('users')
      .select('id', { count: 'exact', head: true })
      .eq('is_public', true)

    return new Response(
      JSON.stringify({
        success: true,
        creators: creators || [],
        pagination: {
          total: totalCount || 0,
          limit,
          offset,
          has_more: (offset + limit) < (totalCount || 0),
        },
        filters: {
          category,
          verified_only: verifiedOnly,
          min_followers: minFollowers,
          sort_by: sortBy,
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
    console.error('Error in browse-creators:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'BROWSE_ERROR',
        message: error instanceof Error ? error.message : 'Failed to browse creators',
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
