import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'

console.log('Robots.txt function started')

/**
 * PUBLIC ENDPOINT - No authentication required
 * Serve robots.txt for search engine crawler control
 */

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  const baseUrl = Deno.env.get('APP_BASE_URL') || 'https://streamvibe.com'

  const robotsTxt = `# StreamVibe Robots.txt
# Allow all search engines to crawl public content

User-agent: *
Allow: /
Allow: /creator/*
Allow: /content/*
Allow: /browse/*
Allow: /categories
Allow: /trending
Allow: /search

# Disallow private/admin areas
Disallow: /api/
Disallow: /admin/
Disallow: /dashboard/
Disallow: /settings/
Disallow: /auth/

# Crawl rate limits
Crawl-delay: 1

# Sitemap location
Sitemap: ${baseUrl}/sitemap.xml

# Specific bots
User-agent: Googlebot
Allow: /

User-agent: Bingbot
Allow: /

User-agent: Slurp
Allow: /

# Block aggressive crawlers
User-agent: AhrefsBot
Crawl-delay: 10

User-agent: SemrushBot
Crawl-delay: 10
`

  return new Response(robotsTxt, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/plain',
      'Cache-Control': 'public, max-age=86400', // Cache for 24 hours
    },
  })
})
