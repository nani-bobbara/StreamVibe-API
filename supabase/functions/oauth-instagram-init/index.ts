import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'
import type { OAuthInitResponse, ErrorResponse } from '../_shared/types.ts'

console.log('Instagram OAuth init function started')

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const user = await getAuthenticatedUser(req, supabase)

    // Get Instagram OAuth credentials from environment
    const clientId = Deno.env.get('INSTAGRAM_CLIENT_ID')
    const redirectUri = Deno.env.get('INSTAGRAM_REDIRECT_URI') || 
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/oauth-instagram-callback`

    if (!clientId) {
      throw new Error('Instagram OAuth not configured')
    }

    // Generate state parameter for CSRF protection
    const state = crypto.randomUUID()

    // Store state in database for verification
    await supabase
      .from('oauth_state')
      .insert({
        state,
        user_id: user.id,
        platform: 'instagram',
        expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(), // 10 minutes
      })

    // Build Instagram OAuth URL (Facebook OAuth for Instagram)
    const scopes = [
      'instagram_basic',
      'instagram_content_publish',
      'pages_show_list',
    ].join(',')

    const authUrl = new URL('https://api.instagram.com/oauth/authorize')
    authUrl.searchParams.set('client_id', clientId)
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
    console.error('Error in oauth-instagram-init:', error)

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
