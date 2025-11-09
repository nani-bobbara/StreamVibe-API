import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('YouTube sync function started')

interface ContentSyncResponse {
  success: boolean
  synced_count: number
  failed_count: number
  total_videos: number
  social_account_id?: string
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const user = await getAuthenticatedUser(req, supabase)

    // Get YouTube social account
    const { data: socialAccount, error: accountError } = await supabase
      .from('social_account')
      .select('*')
      .eq('user_id', user.id)
      .eq('platform', 'youtube')
      .eq('is_active', true)
      .single()

    if (accountError || !socialAccount) {
      throw new Error('YouTube account not connected')
    }

    // Get access token from Vault
    const { data: vaultData, error: vaultError } = await supabase.rpc('vault_read', {
      secret_name: socialAccount.vault_key,
    })

    if (vaultError || !vaultData) {
      throw new Error('Failed to retrieve access token')
    }

    const tokens = JSON.parse(vaultData)
    let accessToken = tokens.access_token

    // Check if token is expired and refresh if needed
    if (new Date(tokens.expires_at) < new Date()) {
      const clientId = Deno.env.get('YOUTUBE_CLIENT_ID')
      const clientSecret = Deno.env.get('YOUTUBE_CLIENT_SECRET')

      const refreshResponse = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          client_id: clientId!,
          client_secret: clientSecret!,
          refresh_token: tokens.refresh_token,
          grant_type: 'refresh_token',
        }),
      })

      if (refreshResponse.ok) {
        const newTokens = await refreshResponse.json()
        accessToken = newTokens.access_token

        // Update vault with new token
        await supabase.rpc('vault_update', {
          secret_name: socialAccount.vault_key,
          secret: JSON.stringify({
            ...tokens,
            access_token: newTokens.access_token,
            expires_at: new Date(Date.now() + newTokens.expires_in * 1000).toISOString(),
          }),
        })
      }
    }

    // Fetch videos from YouTube API
    let syncedCount = 0
    let failedCount = 0
    let nextPageToken = ''
    const maxPages = 5 // Limit to 250 videos per sync (50 per page)

    for (let page = 0; page < maxPages; page++) {
      const url = new URL('https://www.googleapis.com/youtube/v3/search')
      url.searchParams.set('part', 'snippet')
      url.searchParams.set('forMine', 'true')
      url.searchParams.set('type', 'video')
      url.searchParams.set('maxResults', '50')
      url.searchParams.set('order', 'date')
      if (nextPageToken) url.searchParams.set('pageToken', nextPageToken)

      const searchResponse = await fetch(url.toString(), {
        headers: { 'Authorization': `Bearer ${accessToken}` },
      })

      if (!searchResponse.ok) {
        console.error('Failed to fetch videos from YouTube')
        break
      }

      const searchData = await searchResponse.json()
      
      if (!searchData.items || searchData.items.length === 0) {
        break
      }

      // Get detailed video statistics
      const videoIds = searchData.items.map((item: any) => item.id.videoId).join(',')
      
      const detailsResponse = await fetch(
        `https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics,contentDetails&id=${videoIds}`,
        { headers: { 'Authorization': `Bearer ${accessToken}` } }
      )

      if (!detailsResponse.ok) {
        failedCount += searchData.items.length
        continue
      }

      const detailsData = await detailsResponse.json()

      // Process each video
      for (const video of detailsData.items) {
        try {
          const videoId = video.id
          const snippet = video.snippet
          const statistics = video.statistics
          const contentDetails = video.contentDetails

          // Parse ISO 8601 duration to seconds
          const durationMatch = contentDetails.duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
          const hours = parseInt(durationMatch?.[1] || '0')
          const minutes = parseInt(durationMatch?.[2] || '0')
          const seconds = parseInt(durationMatch?.[3] || '0')
          const durationSeconds = hours * 3600 + minutes * 60 + seconds

          // Check if content already exists
          const { data: existingContent } = await supabase
            .from('content_item')
            .select('id')
            .eq('social_account_id', socialAccount.id)
            .eq('platform_content_id', videoId)
            .single()

          const contentData = {
            title: snippet.title,
            description: snippet.description,
            thumbnail_url: snippet.thumbnails.high?.url || snippet.thumbnails.default.url,
            content_url: `https://www.youtube.com/watch?v=${videoId}`,
            content_type: 'video',
            duration_seconds: durationSeconds,
            views_count: parseInt(statistics.viewCount || '0'),
            likes_count: parseInt(statistics.likeCount || '0'),
            comments_count: parseInt(statistics.commentCount || '0'),
            published_at: snippet.publishedAt,
            tags: snippet.tags || [],
            canonical_url: `https://www.youtube.com/watch?v=${videoId}`,
            embed_html: `<iframe width="560" height="315" src="https://www.youtube.com/embed/${videoId}" frameborder="0" allowfullscreen></iframe>`,
            embed_cached_at: new Date().toISOString(),
            last_synced_at: new Date().toISOString(),
          }

          if (existingContent) {
            // Update existing content
            await supabase
              .from('content_item')
              .update(contentData)
              .eq('id', existingContent.id)
          } else {
            // Insert new content
            await supabase
              .from('content_item')
              .insert({
                user_id: user.id,
                social_account_id: socialAccount.id,
                platform_content_id: videoId,
                ...contentData,
              })
          }

          syncedCount++
        } catch (error) {
          console.error('Failed to sync video:', error)
          failedCount++
        }
      }

      nextPageToken = searchData.nextPageToken
      if (!nextPageToken) break
    }

    // Update social account last_synced_at
    await supabase
      .from('social_account')
      .update({ last_synced_at: new Date().toISOString() })
      .eq('id', socialAccount.id)

    const response: ContentSyncResponse = {
      success: true,
      synced_count: syncedCount,
      failed_count: failedCount,
      total_videos: syncedCount + failedCount,
      social_account_id: socialAccount.id,
    }

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Error in sync-youtube:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'SYNC_ERROR',
        message: error instanceof Error ? error.message : 'Failed to sync YouTube content',
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
