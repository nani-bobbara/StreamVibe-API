import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Instagram sync function started')

interface ContentSyncResponse {
  success: boolean
  synced_count: number
  failed_count: number
  total_posts: number
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
      .eq('platform', 'instagram')
      .eq('is_active', true)
      .single()

    if (accountError || !socialAccount) {
      throw new Error('Instagram account not connected')
    }

    const { data: vaultData, error: vaultError } = await supabase.rpc('vault_read', {
      secret_name: socialAccount.vault_key,
    })

    if (vaultError || !vaultData) {
      throw new Error('Failed to retrieve access token')
    }

    const tokens = JSON.parse(vaultData)
    const accessToken = tokens.access_token

    // Fetch media from Instagram API
    let syncedCount = 0
    let failedCount = 0
    let after = ''
    const maxPages = 5 // Limit to 125 posts per sync (25 per page)

    for (let page = 0; page < maxPages; page++) {
      const url = new URL(`https://graph.instagram.com/${socialAccount.platform_user_id}/media`)
      url.searchParams.set('fields', 'id,caption,media_type,media_url,thumbnail_url,permalink,timestamp,like_count,comments_count,children{media_url,media_type}')
      url.searchParams.set('limit', '25')
      url.searchParams.set('access_token', accessToken)
      if (after) url.searchParams.set('after', after)

      const response = await fetch(url.toString())

      if (!response.ok) {
        console.error('Failed to fetch media from Instagram')
        break
      }

      const data = await response.json()
      
      if (!data.data || data.data.length === 0) {
        break
      }

      for (const media of data.data) {
        try {
          const { data: existingContent } = await supabase
            .from('content_item')
            .select('id')
            .eq('social_account_id', socialAccount.id)
            .eq('platform_content_id', media.id)
            .single()

          const contentType = media.media_type === 'VIDEO' ? 'video' : 'image'

          const contentData = {
            title: media.caption ? media.caption.substring(0, 100) : `Instagram ${contentType}`,
            description: media.caption || '',
            thumbnail_url: media.thumbnail_url || media.media_url,
            content_url: media.permalink,
            content_type: contentType,
            likes_count: media.like_count || 0,
            comments_count: media.comments_count || 0,
            published_at: media.timestamp,
            canonical_url: media.permalink,
            last_synced_at: new Date().toISOString(),
          }

          let contentId: string

          if (existingContent) {
            await supabase
              .from('content_item')
              .update(contentData)
              .eq('id', existingContent.id)
            contentId = existingContent.id
          } else {
            const { data: newContent } = await supabase
              .from('content_item')
              .insert({
                user_id: user.id,
                social_account_id: socialAccount.id,
                platform_content_id: media.id,
                ...contentData,
              })
              .select('id')
              .single()
            contentId = newContent?.id
          }

          // Handle carousel/album (multiple images)
          if (media.media_type === 'CAROUSEL_ALBUM' && media.children && contentId) {
            // Delete old media entries
            await supabase
              .from('content_media')
              .delete()
              .eq('content_id', contentId)

            // Insert new media entries
            const mediaEntries = media.children.data.map((child: any, index: number) => ({
              content_id: contentId,
              media_url: child.media_url,
              media_type: child.media_type === 'VIDEO' ? 'video' : 'image',
              display_order: index + 1,
            }))

            await supabase
              .from('content_media')
              .insert(mediaEntries)
          }

          syncedCount++
        } catch (error) {
          console.error('Failed to sync media:', error)
          failedCount++
        }
      }

      after = data.paging?.cursors?.after
      if (!after) break
    }

    await supabase
      .from('social_account')
      .update({ last_synced_at: new Date().toISOString() })
      .eq('id', socialAccount.id)

    const response: ContentSyncResponse = {
      success: true,
      synced_count: syncedCount,
      failed_count: failedCount,
      total_posts: syncedCount + failedCount,
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
    console.error('Error in sync-instagram:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'SYNC_ERROR',
        message: error instanceof Error ? error.message : 'Failed to sync Instagram content',
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
