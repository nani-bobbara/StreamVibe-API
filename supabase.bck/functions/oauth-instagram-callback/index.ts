import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Instagram OAuth callback function started')

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    const code = url.searchParams.get('code')
    const state = url.searchParams.get('state')
    const error = url.searchParams.get('error')

    if (error) {
      console.error('OAuth error:', error)
      return new Response(
        `<html><body><h1>Authorization Failed</h1><p>Error: ${error}</p><p>You can close this window.</p></body></html>`,
        { status: 400, headers: { 'Content-Type': 'text/html' } }
      )
    }

    if (!code || !state) {
      throw new Error('Missing code or state parameter')
    }

    // Verify state token
    const { data: stateData, error: stateError } = await supabase
      .from('oauth_state')
      .select('user_id, platform, expires_at')
      .eq('state', state)
      .eq('platform', 'instagram')
      .single()

    if (stateError || !stateData) {
      throw new Error('Invalid or expired state token')
    }

    if (new Date(stateData.expires_at) < new Date()) {
      throw new Error('State token expired')
    }

    const clientId = Deno.env.get('INSTAGRAM_CLIENT_ID')
    const clientSecret = Deno.env.get('INSTAGRAM_CLIENT_SECRET')
    const redirectUri = Deno.env.get('INSTAGRAM_REDIRECT_URI') || 
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/oauth-instagram-callback`

    if (!clientId || !clientSecret) {
      throw new Error('Instagram OAuth credentials not configured')
    }

    // Exchange code for short-lived token
    const tokenResponse = await fetch('https://api.instagram.com/oauth/access_token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: 'authorization_code',
        redirect_uri: redirectUri,
        code,
      }),
    })

    if (!tokenResponse.ok) {
      throw new Error('Failed to exchange authorization code')
    }

    const shortTokenData = await tokenResponse.json()
    const { access_token: shortToken, user_id: instagramUserId } = shortTokenData

    // Exchange short-lived token for long-lived token (60 days)
    const longTokenResponse = await fetch(
      `https://graph.instagram.com/access_token?grant_type=ig_exchange_token&client_secret=${clientSecret}&access_token=${shortToken}`
    )

    if (!longTokenResponse.ok) {
      throw new Error('Failed to exchange for long-lived token')
    }

    const longTokenData = await longTokenResponse.json()
    const { access_token, expires_in } = longTokenData

    // Get Instagram account info
    const profileResponse = await fetch(
      `https://graph.instagram.com/${instagramUserId}?fields=id,username,account_type,media_count&access_token=${access_token}`
    )

    if (!profileResponse.ok) {
      throw new Error('Failed to fetch Instagram profile')
    }

    const profile = await profileResponse.json()

    // Store tokens in Vault
    const vaultKey = `instagram_tokens_${stateData.user_id}_${instagramUserId}`
    await supabase.rpc('vault_insert', {
      name: vaultKey,
      secret: JSON.stringify({
        access_token,
        expires_at: new Date(Date.now() + expires_in * 1000).toISOString(),
        token_type: 'Bearer',
      }),
    })

    // Check if account exists
    const { data: existingAccount } = await supabase
      .from('social_account')
      .select('id')
      .eq('user_id', stateData.user_id)
      .eq('platform', 'instagram')
      .eq('platform_user_id', instagramUserId)
      .single()

    const accountData = {
      handle: profile.username,
      display_name: profile.username,
      profile_url: `https://www.instagram.com/${profile.username}`,
      total_content_count: profile.media_count || 0,
      vault_key: vaultKey,
      is_active: true,
      last_synced_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }

    if (existingAccount) {
      await supabase
        .from('social_account')
        .update(accountData)
        .eq('id', existingAccount.id)
    } else {
      await supabase
        .from('social_account')
        .insert({
          user_id: stateData.user_id,
          platform: 'instagram',
          platform_user_id: instagramUserId,
          ...accountData,
        })
    }

    await supabase.from('oauth_state').delete().eq('state', state)
    await supabase.rpc('update_total_followers', { p_user_id: stateData.user_id })

    const appUrl = Deno.env.get('APP_BASE_URL') || 'https://streamvibe.com'
    
    return new Response(
      `<!DOCTYPE html>
      <html>
      <head>
        <title>Instagram Connected!</title>
        <style>
          body { font-family: system-ui; max-width: 600px; margin: 100px auto; text-align: center; }
          h1 { color: #e1306c; }
          .stats { margin: 30px 0; }
          .stat-value { font-size: 24px; font-weight: bold; color: #e1306c; }
          .button { display: inline-block; margin-top: 30px; padding: 12px 24px; background: #e1306c; color: white; text-decoration: none; border-radius: 8px; }
        </style>
      </head>
      <body>
        <h1>✅ Instagram Connected Successfully!</h1>
        <h2>@${profile.username}</h2>
        <div class="stats">
          <div class="stat-value">${profile.media_count || 0} Posts</div>
        </div>
        <p>Your Instagram account is now connected to StreamVibe!</p>
        <a href="${appUrl}/dashboard" class="button">Go to Dashboard</a>
      </body>
      </html>`,
      { status: 200, headers: { 'Content-Type': 'text/html' } }
    )

  } catch (error) {
    console.error('Error in oauth-instagram-callback:', error)
    return new Response(
      `<!DOCTYPE html>
      <html>
      <body style="font-family: system-ui; text-align: center; margin-top: 100px;">
        <h1 style="color: #ef4444;">❌ Connection Failed</h1>
        <p>${error instanceof Error ? error.message : 'An unknown error occurred'}</p>
      </body>
      </html>`,
      { status: 500, headers: { 'Content-Type': 'text/html' } }
    )
  }
})
