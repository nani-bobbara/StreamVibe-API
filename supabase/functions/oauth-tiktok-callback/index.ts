import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'

console.log('TikTok OAuth callback function started')

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
      return new Response(
        `<html><body><h1>Authorization Failed</h1><p>Error: ${error}</p></body></html>`,
        { status: 400, headers: { 'Content-Type': 'text/html' } }
      )
    }

    if (!code || !state) {
      throw new Error('Missing code or state parameter')
    }

    const { data: stateData, error: stateError } = await supabase
      .from('oauth_state')
      .select('user_id, platform, expires_at')
      .eq('state', state)
      .eq('platform', 'tiktok')
      .single()

    if (stateError || !stateData || new Date(stateData.expires_at) < new Date()) {
      throw new Error('Invalid or expired state token')
    }

    const clientKey = Deno.env.get('TIKTOK_CLIENT_KEY')
    const clientSecret = Deno.env.get('TIKTOK_CLIENT_SECRET')
    const redirectUri = Deno.env.get('TIKTOK_REDIRECT_URI') || 
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/oauth-tiktok-callback`

    if (!clientKey || !clientSecret) {
      throw new Error('TikTok OAuth credentials not configured')
    }

    // Exchange code for access token
    const tokenResponse = await fetch('https://open.tiktokapis.com/v2/oauth/token/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_key: clientKey,
        client_secret: clientSecret,
        code,
        grant_type: 'authorization_code',
        redirect_uri: redirectUri,
      }),
    })

    if (!tokenResponse.ok) {
      throw new Error('Failed to exchange authorization code')
    }

    const tokens = await tokenResponse.json()
    const { access_token, refresh_token, expires_in, open_id } = tokens.data

    // Get TikTok user info
    const userResponse = await fetch('https://open.tiktokapis.com/v2/user/info/?fields=open_id,union_id,avatar_url,display_name,username,follower_count,video_count', {
      headers: {
        'Authorization': `Bearer ${access_token}`,
      },
    })

    if (!userResponse.ok) {
      throw new Error('Failed to fetch TikTok user info')
    }

    const userData = await userResponse.json()
    const user = userData.data.user

    // Store tokens in Vault
    const vaultKey = `tiktok_tokens_${stateData.user_id}_${open_id}`
    await supabase.rpc('vault_insert', {
      name: vaultKey,
      secret: JSON.stringify({
        access_token,
        refresh_token,
        expires_at: new Date(Date.now() + expires_in * 1000).toISOString(),
        open_id,
      }),
    })

    const { data: existingAccount } = await supabase
      .from('social_account')
      .select('id')
      .eq('user_id', stateData.user_id)
      .eq('platform', 'tiktok')
      .eq('platform_user_id', open_id)
      .single()

    const accountData = {
      handle: user.username || user.display_name,
      display_name: user.display_name,
      profile_url: user.username ? `https://www.tiktok.com/@${user.username}` : '',
      avatar_url: user.avatar_url,
      followers_count: user.follower_count || 0,
      total_content_count: user.video_count || 0,
      vault_key: vaultKey,
      is_active: true,
      last_synced_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }

    if (existingAccount) {
      await supabase.from('social_account').update(accountData).eq('id', existingAccount.id)
    } else {
      await supabase.from('social_account').insert({
        user_id: stateData.user_id,
        platform: 'tiktok',
        platform_user_id: open_id,
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
        <title>TikTok Connected!</title>
        <style>
          body { font-family: system-ui; max-width: 600px; margin: 100px auto; text-align: center; }
          h1 { color: #000; }
          .button { display: inline-block; margin-top: 30px; padding: 12px 24px; background: #000; color: white; text-decoration: none; border-radius: 8px; }
        </style>
      </head>
      <body>
        <h1>✅ TikTok Connected Successfully!</h1>
        <h2>${user.display_name}</h2>
        <p>@${user.username || ''}</p>
        <p>${user.follower_count?.toLocaleString() || 0} Followers | ${user.video_count || 0} Videos</p>
        <a href="${appUrl}/dashboard" class="button">Go to Dashboard</a>
      </body>
      </html>`,
      { status: 200, headers: { 'Content-Type': 'text/html' } }
    )

  } catch (error) {
    console.error('Error in oauth-tiktok-callback:', error)
    return new Response(
      `<!DOCTYPE html><html><body style="text-align: center; margin-top: 100px;">
        <h1 style="color: #ef4444;">❌ Connection Failed</h1>
        <p>${error instanceof Error ? error.message : 'An unknown error occurred'}</p>
      </body></html>`,
      { status: 500, headers: { 'Content-Type': 'text/html' } }
    )
  }
})
