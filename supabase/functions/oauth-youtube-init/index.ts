import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'
import type { OAuthInitResponse, ErrorResponse } from '../_shared/types.ts'

console.log('YouTube OAuth init function started')

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const user = await getAuthenticatedUser(req, supabase)

    // Get YouTube OAuth credentials from environment
    const clientId = Deno.env.get('YOUTUBE_CLIENT_ID')
    const redirectUri = Deno.env.get('YOUTUBE_REDIRECT_URI') || 
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/oauth-youtube-callback`

    if (!clientId) {
      throw new Error('YouTube OAuth not configured')
    }

    // Generate state parameter for CSRF protection
    const state = crypto.randomUUID()

    // Store state in database for verification
    await supabase
      .from('oauth_state')
      .insert({
        state,
        user_id: user.id,
        platform: 'youtube',
        expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(), // 10 minutes
      })

    // Build YouTube OAuth URL
    const scopes = [
      'https://www.googleapis.com/auth/youtube.readonly',
      'https://www.googleapis.com/auth/userinfo.profile',
    ].join(' ')

    const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth')
    authUrl.searchParams.set('client_id', clientId)
    authUrl.searchParams.set('redirect_uri', redirectUri)
    authUrl.searchParams.set('response_type', 'code')
    authUrl.searchParams.set('scope', scopes)
    authUrl.searchParams.set('state', state)
    authUrl.searchParams.set('access_type', 'offline') // Get refresh token
    authUrl.searchParams.set('prompt', 'consent') // Force consent screen

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
    console.error('Error in oauth-youtube-init:', error)

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
