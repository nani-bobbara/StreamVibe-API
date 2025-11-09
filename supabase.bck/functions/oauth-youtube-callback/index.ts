import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('YouTube OAuth callback function started')

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const url = new URL(req.url)
    
    // Get authorization code and state from query params
    const code = url.searchParams.get('code')
    const state = url.searchParams.get('state')
    const error = url.searchParams.get('error')

    // Handle OAuth errors
    if (error) {
      console.error('OAuth error:', error)
      return new Response(
        `<html><body><h1>Authorization Failed</h1><p>Error: ${error}</p><p>You can close this window.</p></body></html>`,
        { 
          status: 400,
          headers: { 'Content-Type': 'text/html' },
        }
      )
    }

    if (!code || !state) {
      throw new Error('Missing code or state parameter')
    }

    // Verify state token (CSRF protection)
    const { data: stateData, error: stateError } = await supabase
      .from('oauth_state')
      .select('user_id, platform, expires_at')
      .eq('state', state)
      .eq('platform', 'youtube')
      .single()

    if (stateError || !stateData) {
      throw new Error('Invalid or expired state token')
    }

    // Check expiration
    if (new Date(stateData.expires_at) < new Date()) {
      throw new Error('State token expired')
    }

    // Get OAuth credentials
    const clientId = Deno.env.get('YOUTUBE_CLIENT_ID')
    const clientSecret = Deno.env.get('YOUTUBE_CLIENT_SECRET')
    const redirectUri = Deno.env.get('YOUTUBE_REDIRECT_URI') || 
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/oauth-youtube-callback`

    if (!clientId || !clientSecret) {
      throw new Error('YouTube OAuth credentials not configured')
    }

    // Exchange authorization code for tokens
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        grant_type: 'authorization_code',
      }),
    })

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.text()
      console.error('Token exchange failed:', errorData)
      throw new Error('Failed to exchange authorization code')
    }

    const tokens = await tokenResponse.json()
    const { access_token, refresh_token, expires_in, token_type } = tokens

    // Get YouTube channel info
    const channelResponse = await fetch(
      'https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics,contentDetails&mine=true',
      {
        headers: {
          'Authorization': `Bearer ${access_token}`,
        },
      }
    )

    if (!channelResponse.ok) {
      throw new Error('Failed to fetch YouTube channel info')
    }

    const channelData = await channelResponse.json()
    
    if (!channelData.items || channelData.items.length === 0) {
      throw new Error('No YouTube channel found for this account')
    }

    const channel = channelData.items[0]
    const channelId = channel.id
    const channelHandle = channel.snippet.customUrl || channelId
    const channelTitle = channel.snippet.title
    const thumbnailUrl = channel.snippet.thumbnails.default.url
    const subscriberCount = parseInt(channel.statistics.subscriberCount || '0')
    const videoCount = parseInt(channel.statistics.videoCount || '0')

    // Store tokens in Vault (encrypted storage)
    const vaultKey = `youtube_tokens_${stateData.user_id}_${channelId}`
    const { error: vaultError } = await supabase.rpc('vault_insert', {
      name: vaultKey,
      secret: JSON.stringify({
        access_token,
        refresh_token,
        expires_at: new Date(Date.now() + expires_in * 1000).toISOString(),
        token_type,
      }),
    })

    if (vaultError) {
      console.error('Vault storage error:', vaultError)
      throw new Error('Failed to store tokens securely')
    }

    // Check if social account already exists
    const { data: existingAccount } = await supabase
      .from('social_account')
      .select('id')
      .eq('user_id', stateData.user_id)
      .eq('platform', 'youtube')
      .eq('platform_user_id', channelId)
      .single()

    if (existingAccount) {
      // Update existing account
      await supabase
        .from('social_account')
        .update({
          handle: channelHandle,
          display_name: channelTitle,
          profile_url: `https://www.youtube.com/@${channelHandle}`,
          avatar_url: thumbnailUrl,
          followers_count: subscriberCount,
          total_content_count: videoCount,
          vault_key: vaultKey,
          is_active: true,
          last_synced_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', existingAccount.id)
    } else {
      // Create new social account
      await supabase
        .from('social_account')
        .insert({
          user_id: stateData.user_id,
          platform: 'youtube',
          platform_user_id: channelId,
          handle: channelHandle,
          display_name: channelTitle,
          profile_url: `https://www.youtube.com/@${channelHandle}`,
          avatar_url: thumbnailUrl,
          followers_count: subscriberCount,
          total_content_count: videoCount,
          vault_key: vaultKey,
          is_active: true,
          last_synced_at: new Date().toISOString(),
        })
    }

    // Delete used state token
    await supabase
      .from('oauth_state')
      .delete()
      .eq('state', state)

    // Update user's total follower count
    await supabase.rpc('update_total_followers', { p_user_id: stateData.user_id })

    // Return success HTML (user sees this in browser)
    const appUrl = Deno.env.get('APP_BASE_URL') || 'https://streamvibe.com'
    
    return new Response(
      `<!DOCTYPE html>
      <html>
      <head>
        <title>YouTube Connected!</title>
        <style>
          body { font-family: system-ui; max-width: 600px; margin: 100px auto; text-align: center; }
          h1 { color: #10b981; }
          .channel { margin: 30px 0; }
          .avatar { width: 88px; height: 88px; border-radius: 50%; }
          .stats { display: flex; gap: 30px; justify-content: center; margin: 20px 0; }
          .stat { text-align: center; }
          .stat-value { font-size: 24px; font-weight: bold; color: #059669; }
          .stat-label { font-size: 14px; color: #6b7280; }
          .button { display: inline-block; margin-top: 30px; padding: 12px 24px; background: #10b981; color: white; text-decoration: none; border-radius: 8px; }
        </style>
      </head>
      <body>
        <h1>✅ YouTube Connected Successfully!</h1>
        <div class="channel">
          <img class="avatar" src="${thumbnailUrl}" alt="${channelTitle}">
          <h2>${channelTitle}</h2>
          <p>@${channelHandle}</p>
        </div>
        <div class="stats">
          <div class="stat">
            <div class="stat-value">${subscriberCount.toLocaleString()}</div>
            <div class="stat-label">Subscribers</div>
          </div>
          <div class="stat">
            <div class="stat-value">${videoCount.toLocaleString()}</div>
            <div class="stat-label">Videos</div>
          </div>
        </div>
        <p>Your YouTube channel is now connected to StreamVibe!</p>
        <a href="${appUrl}/dashboard" class="button">Go to Dashboard</a>
        <p style="margin-top: 30px; color: #6b7280; font-size: 14px;">You can close this window if it doesn't redirect automatically.</p>
      </body>
      </html>`,
      {
        status: 200,
        headers: { 'Content-Type': 'text/html' },
      }
    )

  } catch (error) {
    console.error('Error in oauth-youtube-callback:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'OAUTH_CALLBACK_ERROR',
        message: error instanceof Error ? error.message : 'OAuth callback failed',
      },
    }

    return new Response(
      `<!DOCTYPE html>
      <html>
      <head>
        <title>Connection Failed</title>
        <style>
          body { font-family: system-ui; max-width: 600px; margin: 100px auto; text-align: center; }
          h1 { color: #ef4444; }
          .error { background: #fef2f2; border: 1px solid #fecaca; padding: 20px; border-radius: 8px; margin: 20px 0; }
        </style>
      </head>
      <body>
        <h1>❌ Connection Failed</h1>
        <div class="error">
          <p>${error instanceof Error ? error.message : 'An unknown error occurred'}</p>
        </div>
        <p>Please try connecting your YouTube account again.</p>
        <p style="margin-top: 30px; color: #6b7280; font-size: 14px;">You can close this window.</p>
      </body>
      </html>`,
      {
        status: 500,
        headers: { 'Content-Type': 'text/html' },
      }
    )
  }
})
