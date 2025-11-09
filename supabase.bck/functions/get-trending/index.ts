import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Get trending content function started')

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    const category = url.searchParams.get('category') || 'today' // today, week, month, all_time
    const limit = parseInt(url.searchParams.get('limit') || '20')

    const { data: trending, error } = await supabase
      .from('trending_content')
      .select(`
        trend_score,
        rank_position,
        content_item (
          id,
          title,
          description,
          thumbnail_url,
          content_url,
          content_type,
          views_count,
          likes_count,
          total_clicks,
          published_at,
          users (display_name, profile_slug, avatar_url)
        )
      `)
      .eq('trend_category', category)
      .order('rank_position', { ascending: true })
      .limit(limit)

    if (error) {
      throw error
    }

    return new Response(
      JSON.stringify({
        success: true,
        category,
        results: trending.map(t => ({
          ...t.content_item,
          trend_score: t.trend_score,
          rank: t.rank_position,
        })),
        count: trending.length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Error in get-trending:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'TRENDING_ERROR',
        message: error instanceof Error ? error.message : 'Failed to get trending content',
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
