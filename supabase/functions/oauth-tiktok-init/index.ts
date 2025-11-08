import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'
import type { OAuthInitResponse, ErrorResponse } from '../_shared/types.ts'

console.log('TikTok OAuth init function started')

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const user = await getAuthenticatedUser(req, supabase)

    const clientKey = Deno.env.get('TIKTOK_CLIENT_KEY')
    const redirectUri = Deno.env.get('TIKTOK_REDIRECT_URI') || 
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/oauth-tiktok-callback`

    if (!clientKey) {
      throw new Error('TikTok OAuth not configured')
    }

    const state = crypto.randomUUID()

    await supabase
      .from('oauth_state')
      .insert({
        state,
        user_id: user.id,
        platform: 'tiktok',
        expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
      })

    // Build TikTok OAuth URL
    const scopes = ['user.info.basic', 'video.list'].join(',')
    
    const authUrl = new URL('https://www.tiktok.com/v2/auth/authorize/')
    authUrl.searchParams.set('client_key', clientKey)
    authUrl.searchParams.set('redirect_uri', redirectUri)
    authUrl.searchParams.set('response_type', 'code')
    authUrl.searchParams.set('scope', scopes)
    authUrl.searchParams.set('state', state)

    const response: OAuthInitResponse = {
      success: true,
      authorization_url: authUrl.toString(),
      state,
    }

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Error in oauth-tiktok-init:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'OAUTH_INIT_ERROR',
        message: error instanceof Error ? error.message : 'Failed to initialize OAuth',
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
