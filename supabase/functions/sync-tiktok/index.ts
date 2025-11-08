import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('TikTok sync function started')

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

    const { data: socialAccount, error: accountError } = await supabase
      .from('social_account')
      .select('*')
      .eq('user_id', user.id)
      .eq('platform', 'tiktok')
      .eq('is_active', true)
      .single()

    if (accountError || !socialAccount) {
      throw new Error('TikTok account not connected')
    }

    const { data: vaultData, error: vaultError } = await supabase.rpc('vault_read', {
      secret_name: socialAccount.vault_key,
    })

    if (vaultError || !vaultData) {
      throw new Error('Failed to retrieve access token')
    }

    const tokens = JSON.parse(vaultData)
    const accessToken = tokens.access_token

    // Fetch videos from TikTok API
    let syncedCount = 0
    let failedCount = 0
    let cursor = 0
    const maxPages = 5 // Limit to 100 videos per sync (20 per page)

    for (let page = 0; page < maxPages; page++) {
      const url = new URL('https://open.tiktokapis.com/v2/video/list/')
      url.searchParams.set('fields', 'id,title,video_description,duration,cover_image_url,share_url,view_count,like_count,comment_count,create_time')
      url.searchParams.set('max_count', '20')
      if (cursor > 0) url.searchParams.set('cursor', cursor.toString())

      const response = await fetch(url.toString(), {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
        },
      })

      if (!response.ok) {
        console.error('Failed to fetch videos from TikTok')
        break
      }

      const data = await response.json()
      
      if (!data.data || !data.data.videos || data.data.videos.length === 0) {
        break
      }

      for (const video of data.data.videos) {
        try {
          const { data: existingContent } = await supabase
            .from('content_item')
            .select('id')
            .eq('social_account_id', socialAccount.id)
            .eq('platform_content_id', video.id)
            .single()

          const contentData = {
            title: video.title || video.video_description?.substring(0, 100) || 'TikTok Video',
            description: video.video_description || '',
            thumbnail_url: video.cover_image_url,
            content_url: video.share_url,
            content_type: 'video',
            duration_seconds: video.duration || 0,
            views_count: video.view_count || 0,
            likes_count: video.like_count || 0,
            comments_count: video.comment_count || 0,
            published_at: new Date(video.create_time * 1000).toISOString(),
            canonical_url: video.share_url,
            last_synced_at: new Date().toISOString(),
          }

          if (existingContent) {
            await supabase
              .from('content_item')
              .update(contentData)
              .eq('id', existingContent.id)
          } else {
            await supabase
              .from('content_item')
              .insert({
                user_id: user.id,
                social_account_id: socialAccount.id,
                platform_content_id: video.id,
                ...contentData,
              })
          }

          syncedCount++
        } catch (error) {
          console.error('Failed to sync video:', error)
          failedCount++
        }
      }

      cursor = data.data.cursor
      if (!data.data.has_more) break
    }

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
    console.error('Error in sync-tiktok:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'SYNC_ERROR',
        message: error instanceof Error ? error.message : 'Failed to sync TikTok content',
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
