import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Get SEO metadata function started')

/**
 * PUBLIC ENDPOINT - No authentication required
 * Get structured SEO metadata for content items and creator profiles
 * Returns Open Graph tags and Schema.org JSON-LD
 * Used by: Search engines, Social media crawlers, Meta tag generation
 */

interface OpenGraphData {
  'og:type': string
  'og:title': string
  'og:description': string
  'og:image': string
  'og:url': string
  'og:site_name': string
  'twitter:card': string
  'twitter:title': string
  'twitter:description': string
  'twitter:image': string
}

interface SchemaOrgData {
  '@context': string
  '@type': string
  [key: string]: unknown
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // NO AUTH CHECK - This is a public endpoint
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    const type = url.searchParams.get('type') // 'content' or 'creator'
    const id = url.searchParams.get('id')
    const slug = url.searchParams.get('slug')
    const baseUrl = Deno.env.get('APP_BASE_URL') || 'https://streamvibe.com'

    if (!type || (!id && !slug)) {
      throw new Error('type and (id or slug) parameters are required')
    }

    let openGraph: OpenGraphData
    let schemaOrg: SchemaOrgData

    if (type === 'content') {
      // Get content metadata
      const { data: content, error } = await supabase
        .from('content_item')
        .select(`
          id,
          title,
          description,
          thumbnail_url,
          platform_url,
          views_count,
          likes_count,
          published_at,
          seo_title,
          seo_description,
          seo_keywords,
          duration_seconds,
          social_account:social_account_id (
            account_name,
            user:user_id (
              display_name,
              profile_slug,
              avatar_url
            )
          )
        `)
        .eq('id', id)
        .eq('visibility', 'public')
        .is('deleted_at', null)
        .single()

      if (error || !content) {
        return new Response(
          JSON.stringify({
            success: false,
            error: { code: 'NOT_FOUND', message: 'Content not found' },
          }),
          {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        )
      }

      const contentUrl = `${baseUrl}/content/${content.id}`
      const title = content.seo_title || content.title || 'Untitled'
      const description = content.seo_description || content.description || ''

      // Open Graph metadata
      openGraph = {
        'og:type': 'video.other',
        'og:title': title,
        'og:description': description.substring(0, 200),
        'og:image': content.thumbnail_url || '',
        'og:url': contentUrl,
        'og:site_name': 'StreamVibe',
        'twitter:card': 'summary_large_image',
        'twitter:title': title,
        'twitter:description': description.substring(0, 200),
        'twitter:image': content.thumbnail_url || '',
      }

      // Schema.org JSON-LD
      schemaOrg = {
        '@context': 'https://schema.org',
        '@type': 'VideoObject',
        name: title,
        description: description,
        thumbnailUrl: content.thumbnail_url,
        uploadDate: content.published_at,
        duration: content.duration_seconds ? `PT${content.duration_seconds}S` : undefined,
        interactionStatistic: [
          {
            '@type': 'InteractionCounter',
            interactionType: 'https://schema.org/WatchAction',
            userInteractionCount: content.views_count,
          },
          {
            '@type': 'InteractionCounter',
            interactionType: 'https://schema.org/LikeAction',
            userInteractionCount: content.likes_count,
          },
        ],
        author: {
          '@type': 'Person',
          name: content.social_account.user.display_name,
          url: `${baseUrl}/creator/${content.social_account.user.profile_slug}`,
        },
        url: contentUrl,
      }

    } else if (type === 'creator') {
      // Get creator metadata
      const { data: creator, error } = await supabase
        .from('users')
        .select(`
          id,
          display_name,
          bio,
          avatar_url,
          profile_slug,
          is_verified,
          total_followers_count,
          primary_category,
          website_url
        `)
        .or(`id.eq.${id},profile_slug.eq.${slug}`)
        .eq('is_public', true)
        .single()

      if (error || !creator) {
        return new Response(
          JSON.stringify({
            success: false,
            error: { code: 'NOT_FOUND', message: 'Creator not found' },
          }),
          {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        )
      }

      const creatorUrl = `${baseUrl}/creator/${creator.profile_slug}`
      const title = `${creator.display_name} - StreamVibe Creator`
      const description = creator.bio || `Follow ${creator.display_name} on StreamVibe`

      // Open Graph metadata
      openGraph = {
        'og:type': 'profile',
        'og:title': title,
        'og:description': description.substring(0, 200),
        'og:image': creator.avatar_url || '',
        'og:url': creatorUrl,
        'og:site_name': 'StreamVibe',
        'twitter:card': 'summary',
        'twitter:title': title,
        'twitter:description': description.substring(0, 200),
        'twitter:image': creator.avatar_url || '',
      }

      // Schema.org JSON-LD
      schemaOrg = {
        '@context': 'https://schema.org',
        '@type': 'Person',
        name: creator.display_name,
        description: creator.bio,
        image: creator.avatar_url,
        url: creatorUrl,
        sameAs: creator.website_url ? [creator.website_url] : [],
        jobTitle: 'Content Creator',
        knowsAbout: creator.primary_category,
      }

    } else {
      throw new Error('Invalid type parameter. Must be "content" or "creator"')
    }

    return new Response(
      JSON.stringify({
        success: true,
        seo: {
          open_graph: openGraph,
          schema_org: schemaOrg,
        },
      }),
      {
        status: 200,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=3600', // Cache for 1 hour
        },
      }
    )

  } catch (error) {
    console.error('Error in get-seo-metadata:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'SEO_METADATA_ERROR',
        message: error instanceof Error ? error.message : 'Failed to get SEO metadata',
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
