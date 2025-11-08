import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Browse categories function started')

/**
 * PUBLIC ENDPOINT - No authentication required
 * Get all content categories with counts and featured creators
 * Used by: Anonymous users, Category browsing pages, Search engines
 */

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // NO AUTH CHECK - This is a public endpoint
    const supabase = getSupabaseClient()

    // Get all unique categories with content counts
    const { data: categories, error } = await supabase
      .from('content_item')
      .select('category')
      .eq('visibility', 'public')
      .is('deleted_at', null)
      .not('category', 'is', null)

    if (error) {
      throw error
    }

    // Aggregate categories with counts
    const categoryMap = new Map<string, number>()
    categories?.forEach((item) => {
      const count = categoryMap.get(item.category) || 0
      categoryMap.set(item.category, count + 1)
    })

    // Get top creators per category
    const enrichedCategories = await Promise.all(
      Array.from(categoryMap.entries()).map(async ([category, contentCount]) => {
        // Get top 3 creators in this category
        const { data: topCreators } = await supabase
          .from('users')
          .select('id, display_name, avatar_url, profile_slug, is_verified, total_followers_count')
          .eq('primary_category', category)
          .eq('is_public', true)
          .order('total_followers_count', { ascending: false })
          .limit(3)

        // Get sample content from this category
        const { data: sampleContent } = await supabase
          .from('content_item')
          .select('id, title, thumbnail_url, views_count')
          .eq('category', category)
          .eq('visibility', 'public')
          .is('deleted_at', null)
          .order('views_count', { ascending: false })
          .limit(4)

        return {
          name: category,
          slug: category.toLowerCase().replace(/\s+/g, '-'),
          content_count: contentCount,
          top_creators: topCreators || [],
          sample_content: sampleContent || [],
        }
      })
    )

    // Sort by content count descending
    enrichedCategories.sort((a, b) => b.content_count - a.content_count)

    return new Response(
      JSON.stringify({
        success: true,
        categories: enrichedCategories,
        total_categories: enrichedCategories.length,
      }),
      {
        status: 200,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=600', // Cache for 10 minutes
        },
      }
    )

  } catch (error) {
    console.error('Error in browse-categories:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'BROWSE_CATEGORIES_ERROR',
        message: error instanceof Error ? error.message : 'Failed to browse categories',
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
