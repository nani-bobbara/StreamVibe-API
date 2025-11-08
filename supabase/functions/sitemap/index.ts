import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'

console.log('Sitemap generator function started')

/**
 * PUBLIC ENDPOINT - No authentication required
 * Generate XML sitemap for search engine crawlers
 * Returns sitemap.xml with all public content and creator profiles
 */

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // NO AUTH CHECK - This is a public endpoint
    const supabase = getSupabaseClient()
    const baseUrl = Deno.env.get('APP_BASE_URL') || 'https://streamvibe.com'
    
    // Get all public creators
    const { data: creators } = await supabase
      .from('users')
      .select('profile_slug, updated_at')
      .eq('is_public', true)
      .order('updated_at', { ascending: false })
      .limit(5000) // Limit for performance

    // Get all public content
    const { data: content } = await supabase
      .from('content_item')
      .select('id, updated_at, published_at')
      .eq('visibility', 'public')
      .is('deleted_at', null)
      .order('published_at', { ascending: false })
      .limit(10000) // Limit for performance

    // Build sitemap XML
    const sitemapUrls: string[] = []

    // Add homepage
    sitemapUrls.push(`
  <url>
    <loc>${baseUrl}</loc>
    <lastmod>${new Date().toISOString().split('T')[0]}</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>`)

    // Add creator profiles
    creators?.forEach((creator) => {
      const lastmod = new Date(creator.updated_at).toISOString().split('T')[0]
      sitemapUrls.push(`
  <url>
    <loc>${baseUrl}/creator/${creator.profile_slug}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>`)
    })

    // Add content items
    content?.forEach((item) => {
      const lastmod = new Date(item.updated_at).toISOString().split('T')[0]
      sitemapUrls.push(`
  <url>
    <loc>${baseUrl}/content/${item.id}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.6</priority>
  </url>`)
    })

    // Add static pages
    const staticPages = [
      { path: '/browse/creators', priority: '0.9' },
      { path: '/browse/content', priority: '0.9' },
      { path: '/categories', priority: '0.8' },
      { path: '/trending', priority: '0.9' },
      { path: '/about', priority: '0.5' },
      { path: '/privacy', priority: '0.3' },
      { path: '/terms', priority: '0.3' },
    ]

    staticPages.forEach((page) => {
      sitemapUrls.push(`
  <url>
    <loc>${baseUrl}${page.path}</loc>
    <changefreq>monthly</changefreq>
    <priority>${page.priority}</priority>
  </url>`)
    })

    // Generate full sitemap XML
    const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${sitemapUrls.join('')}
</urlset>`

    return new Response(sitemap, {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/xml',
        'Cache-Control': 'public, max-age=3600', // Cache for 1 hour
      },
    })

  } catch (error) {
    console.error('Error in sitemap generator:', error)

    // Return minimal valid sitemap on error
    const baseUrl = Deno.env.get('APP_BASE_URL') || 'https://streamvibe.com'
    const fallbackSitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${baseUrl}</loc>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>`

    return new Response(fallbackSitemap, {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/xml',
      },
    })
  }
})
