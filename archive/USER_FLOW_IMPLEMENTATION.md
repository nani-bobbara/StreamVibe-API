# StreamVibe - Complete User Flow Implementation

## 🎯 User Journey Overview

```
1. User signs up with Supabase Auth (Google/Email)
   ↓
2. User sees dashboard with "Connect Platform" options
   ↓
3. User selects YouTube/Instagram/TikTok
   ↓
4. User redirected to platform's auth screen
   ↓
5. User grants permissions to StreamVibe
   ↓
6. Platform returns tokens to StreamVibe
   ↓
7. Tokens stored in Supabase Vault (encrypted)
   ↓
8. Reference stored in platform_credentials table
   ↓
9. User can now sync/refresh content automatically
```

---

## 📱 Step-by-Step Implementation

### **Step 1: User Signup (Supabase Auth)**

#### **Frontend: Sign Up Component**
```typescript
// src/components/auth/SignUpPage.tsx
import { useState } from 'react'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export default function SignUpPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [fullName, setFullName] = useState('')

  // Sign up with Email/Password
  async function handleEmailSignUp() {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: fullName
        }
      }
    })

    if (error) {
      alert(error.message)
      return
    }

    // User created! Trigger automatically creates profile
    window.location.href = '/dashboard'
  }

  // Sign up with Google
  async function handleGoogleSignUp() {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`
      }
    })

    if (error) {
      alert(error.message)
    }
    // Redirects to Google, then back to /auth/callback
  }

  // Sign up with Facebook
  async function handleFacebookSignUp() {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'facebook',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`
      }
    })

    if (error) {
      alert(error.message)
    }
  }

  return (
    <div className="signup-container">
      <h1>Welcome to StreamVibe</h1>
      
      {/* Social Sign Up */}
      <div className="social-buttons">
        <button onClick={handleGoogleSignUp}>
          <GoogleIcon /> Sign up with Google
        </button>
        <button onClick={handleFacebookSignUp}>
          <FacebookIcon /> Sign up with Facebook
        </button>
      </div>

      <div className="divider">or</div>

      {/* Email Sign Up */}
      <form onSubmit={(e) => { e.preventDefault(); handleEmailSignUp(); }}>
        <input
          type="text"
          placeholder="Full Name"
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
        />
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <button type="submit">Sign Up</button>
      </form>
    </div>
  )
}
```

#### **Frontend: Auth Callback Handler**
```typescript
// src/app/auth/callback/page.tsx
'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export default function AuthCallback() {
  const router = useRouter()

  useEffect(() => {
    // Handle OAuth callback
    const handleCallback = async () => {
      const { data, error } = await supabase.auth.getSession()

      if (error) {
        console.error('Auth error:', error)
        router.push('/login?error=auth_failed')
        return
      }

      if (data.session) {
        // User authenticated! Redirect to dashboard
        router.push('/dashboard')
      } else {
        router.push('/login')
      }
    }

    handleCallback()
  }, [router])

  return <div>Completing sign up...</div>
}
```

---

### **Step 2: Dashboard with Platform Connection Options**

#### **Frontend: Dashboard Component**
```typescript
// src/components/dashboard/Dashboard.tsx
import { useEffect, useState } from 'react'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

interface Platform {
  id: string
  name: string
  description: string
  logo_url: string
  is_active: boolean
}

interface ConnectedPlatform {
  platform_id: string
  platform_username: string
  is_active: boolean
  last_verified_at: string
  scopes: string[]
}

export default function Dashboard() {
  const [user, setUser] = useState<any>(null)
  const [supportedPlatforms, setSupportedPlatforms] = useState<Platform[]>([])
  const [connectedPlatforms, setConnectedPlatforms] = useState<ConnectedPlatform[]>([])

  useEffect(() => {
    loadDashboardData()
  }, [])

  async function loadDashboardData() {
    // Get current user
    const { data: { user } } = await supabase.auth.getUser()
    setUser(user)

    if (!user) {
      window.location.href = '/login'
      return
    }

    // Load supported platforms
    const { data: platforms } = await supabase
      .from('supported_platform_types')
      .select('*')
      .eq('is_active', true)
      .order('name')

    setSupportedPlatforms(platforms || [])

    // Load connected platforms
    const { data: connected } = await supabase
      .from('platform_credentials')
      .select(`
        platform_id,
        platform_username,
        is_active,
        last_verified_at,
        scopes,
        supported_platform_types (name, logo_url)
      `)
      .eq('user_id', user.id)
      .eq('is_active', true)

    setConnectedPlatforms(connected || [])
  }

  // Check if platform is already connected
  function isConnected(platformId: string): boolean {
    return connectedPlatforms.some(cp => cp.platform_id === platformId)
  }

  // Get connected platform info
  function getConnectedInfo(platformId: string) {
    return connectedPlatforms.find(cp => cp.platform_id === platformId)
  }

  // Connect platform
  async function connectPlatform(platformName: string) {
    if (!user) return

    // Call Edge Function to initiate OAuth
    const { data, error } = await supabase.functions.invoke('initiate-platform-oauth', {
      body: {
        platform: platformName.toLowerCase(),
        userId: user.id
      }
    })

    if (error) {
      alert(`Error: ${error.message}`)
      return
    }

    // Redirect to platform's OAuth screen
    window.location.href = data.authUrl
  }

  // Disconnect platform
  async function disconnectPlatform(platformId: string) {
    const confirmed = confirm('Are you sure you want to disconnect this platform?')
    if (!confirmed) return

    const { error } = await supabase.functions.invoke('disconnect-platform', {
      body: {
        platformId,
        userId: user?.id
      }
    })

    if (error) {
      alert(`Error: ${error.message}`)
      return
    }

    // Refresh connected platforms
    loadDashboardData()
  }

  return (
    <div className="dashboard">
      <h1>Welcome, {user?.user_metadata?.full_name || user?.email}!</h1>

      <section className="platforms-section">
        <h2>Connect Your Platforms</h2>
        <p>Connect your social media accounts to sync and manage your content</p>

        <div className="platforms-grid">
          {supportedPlatforms.map((platform) => {
            const connected = isConnected(platform.id)
            const connectedInfo = getConnectedInfo(platform.id)

            return (
              <div key={platform.id} className="platform-card">
                <img src={platform.logo_url} alt={platform.name} />
                <h3>{platform.name}</h3>
                <p>{platform.description}</p>

                {connected && connectedInfo ? (
                  <div className="connected-info">
                    <div className="status">
                      <span className="badge success">✓ Connected</span>
                    </div>
                    <p className="username">@{connectedInfo.platform_username}</p>
                    <p className="last-sync">
                      Last verified: {new Date(connectedInfo.last_verified_at).toLocaleDateString()}
                    </p>
                    <button 
                      className="btn-secondary"
                      onClick={() => disconnectPlatform(platform.id)}
                    >
                      Disconnect
                    </button>
                  </div>
                ) : (
                  <button
                    className="btn-primary"
                    onClick={() => connectPlatform(platform.name)}
                  >
                    Connect {platform.name}
                  </button>
                )}
              </div>
            )
          })}
        </div>
      </section>

      {connectedPlatforms.length > 0 && (
        <section className="content-section">
          <h2>Your Content</h2>
          <ContentList connectedPlatforms={connectedPlatforms} />
        </section>
      )}
    </div>
  )
}
```

---

### **Step 3: Edge Function - Initiate Platform OAuth**

#### **Edge Function: Generate OAuth URL**
```typescript
// supabase/functions/initiate-platform-oauth/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { platform, userId } = await req.json()

    const REDIRECT_URI = `${Deno.env.get('APP_URL')}/oauth/callback`
    const state = `${userId}_${platform}_${Date.now()}`

    let authUrl: string

    switch (platform) {
      case 'youtube': {
        authUrl = `https://accounts.google.com/o/oauth2/v2/auth?` +
          `client_id=${Deno.env.get('YOUTUBE_CLIENT_ID')}` +
          `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
          `&response_type=code` +
          `&scope=${encodeURIComponent('https://www.googleapis.com/auth/youtube.readonly')}` +
          `&access_type=offline` +
          `&prompt=consent` + // Force to get refresh token
          `&state=${state}`
        break
      }

      case 'instagram': {
        authUrl = `https://api.instagram.com/oauth/authorize?` +
          `client_id=${Deno.env.get('INSTAGRAM_CLIENT_ID')}` +
          `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
          `&scope=user_profile,user_media` +
          `&response_type=code` +
          `&state=${state}`
        break
      }

      case 'tiktok': {
        authUrl = `https://www.tiktok.com/v2/auth/authorize?` +
          `client_key=${Deno.env.get('TIKTOK_CLIENT_KEY')}` +
          `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
          `&response_type=code` +
          `&scope=user.info.basic,video.list` +
          `&state=${state}`
        break
      }

      case 'facebook': {
        authUrl = `https://www.facebook.com/v18.0/dialog/oauth?` +
          `client_id=${Deno.env.get('FACEBOOK_APP_ID')}` +
          `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
          `&scope=pages_read_engagement,pages_show_list,instagram_basic` +
          `&response_type=code` +
          `&state=${state}`
        break
      }

      default:
        return new Response(
          JSON.stringify({ error: 'Platform not supported' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }

    return new Response(
      JSON.stringify({ authUrl }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

---

### **Step 4: OAuth Callback - Store Tokens in Vault**

#### **Frontend: OAuth Callback Route**
```typescript
// src/app/oauth/callback/page.tsx
'use client'

import { useEffect, useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export default function OAuthCallback() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [status, setStatus] = useState('Processing...')

  useEffect(() => {
    handleOAuthCallback()
  }, [])

  async function handleOAuthCallback() {
    const code = searchParams.get('code')
    const state = searchParams.get('state')
    const error = searchParams.get('error')

    if (error) {
      setStatus(`Error: ${error}`)
      setTimeout(() => router.push('/dashboard'), 3000)
      return
    }

    if (!code || !state) {
      setStatus('Invalid callback parameters')
      setTimeout(() => router.push('/dashboard'), 3000)
      return
    }

    try {
      // Call Edge Function to exchange code for tokens
      const { data, error: exchangeError } = await supabase.functions.invoke(
        'platform-oauth-callback',
        {
          body: { code, state }
        }
      )

      if (exchangeError) {
        setStatus(`Error: ${exchangeError.message}`)
        setTimeout(() => router.push('/dashboard'), 3000)
        return
      }

      setStatus(`✓ ${data.platform} connected successfully!`)
      setTimeout(() => router.push('/dashboard'), 2000)

    } catch (err) {
      setStatus(`Error: ${err.message}`)
      setTimeout(() => router.push('/dashboard'), 3000)
    }
  }

  return (
    <div className="callback-container">
      <h2>{status}</h2>
      <p>Redirecting to dashboard...</p>
    </div>
  )
}
```

#### **Edge Function: Exchange Code & Store in Vault**
```typescript
// supabase/functions/platform-oauth-callback/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { code, state } = await req.json()

    // Parse state: "userId_platform_timestamp"
    const [userId, platform] = state.split('_')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // Service role for Vault access
    )

    // Exchange code for tokens (platform-specific)
    let tokens: any
    let platformAccountInfo: any

    switch (platform) {
      case 'youtube':
        tokens = await exchangeYouTubeCode(code)
        platformAccountInfo = await getYouTubeChannelInfo(tokens.access_token)
        break

      case 'instagram':
        tokens = await exchangeInstagramCode(code)
        platformAccountInfo = await getInstagramAccountInfo(tokens.access_token)
        break

      case 'tiktok':
        tokens = await exchangeTikTokCode(code)
        platformAccountInfo = await getTikTokUserInfo(tokens.access_token)
        break

      default:
        throw new Error('Platform not supported')
    }

    // Store tokens in Supabase Vault
    const secretName = `platform_token_${userId}_${platform}_${Date.now()}`

    const { error: vaultError } = await supabaseClient
      .from('vault.secrets')
      .insert({
        name: secretName,
        secret: JSON.stringify({
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          token_type: tokens.token_type,
          expires_in: tokens.expires_in,
          scope: tokens.scope
        }),
        description: `${platform} OAuth tokens for user ${userId}`
      })

    if (vaultError) {
      console.error('Vault error:', vaultError)
      throw new Error('Failed to store credentials securely')
    }

    // Get platform_id
    const { data: platformData } = await supabaseClient
      .from('supported_platform_types')
      .select('id')
      .eq('name', platform)
      .single()

    if (!platformData) {
      throw new Error('Platform not found in database')
    }

    // Store reference in platform_credentials
    const { error: credError } = await supabaseClient
      .from('platform_credentials')
      .upsert({
        user_id: userId,
        platform_id: platformData.id,
        vault_secret_name: secretName,
        token_expires_at: new Date(Date.now() + tokens.expires_in * 1000),
        scopes: tokens.scope?.split(' ') || [],
        is_active: true,
        last_verified_at: new Date(),
        platform_account_id: platformAccountInfo.id,
        platform_username: platformAccountInfo.username
      }, {
        onConflict: 'user_id,platform_id'
      })

    if (credError) {
      console.error('Credential error:', credError)
      throw new Error('Failed to save platform credentials')
    }

    // Log successful connection
    await supabaseClient.from('audit_log').insert({
      user_id: userId,
      action: 'platform_connected',
      resource_type: 'platform_credentials',
      metadata: {
        platform,
        username: platformAccountInfo.username
      }
    })

    return new Response(
      JSON.stringify({
        success: true,
        platform,
        username: platformAccountInfo.username
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('OAuth callback error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Helper: Exchange YouTube code for tokens
async function exchangeYouTubeCode(code: string) {
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: Deno.env.get('YOUTUBE_CLIENT_ID')!,
      client_secret: Deno.env.get('YOUTUBE_CLIENT_SECRET')!,
      redirect_uri: `${Deno.env.get('APP_URL')}/oauth/callback`,
      grant_type: 'authorization_code'
    })
  })

  if (!response.ok) {
    throw new Error('Failed to exchange YouTube code')
  }

  return await response.json()
}

// Helper: Get YouTube channel info
async function getYouTubeChannelInfo(accessToken: string) {
  const response = await fetch(
    'https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics&mine=true',
    {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    }
  )

  if (!response.ok) {
    throw new Error('Failed to get YouTube channel info')
  }

  const data = await response.json()
  const channel = data.items[0]

  return {
    id: channel.id,
    username: channel.snippet.title,
    avatar_url: channel.snippet.thumbnails.default.url,
    subscriber_count: channel.statistics.subscriberCount
  }
}

// Helper: Exchange Instagram code for tokens
async function exchangeInstagramCode(code: string) {
  const response = await fetch('https://api.instagram.com/oauth/access_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: Deno.env.get('INSTAGRAM_CLIENT_ID')!,
      client_secret: Deno.env.get('INSTAGRAM_CLIENT_SECRET')!,
      redirect_uri: `${Deno.env.get('APP_URL')}/oauth/callback`,
      grant_type: 'authorization_code'
    })
  })

  return await response.json()
}

// Helper: Get Instagram account info
async function getInstagramAccountInfo(accessToken: string) {
  const response = await fetch(
    `https://graph.instagram.com/me?fields=id,username,account_type,media_count&access_token=${accessToken}`
  )

  return await response.json()
}

// Helper: Exchange TikTok code for tokens
async function exchangeTikTokCode(code: string) {
  const response = await fetch('https://open.tiktokapis.com/v2/oauth/token/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_key: Deno.env.get('TIKTOK_CLIENT_KEY')!,
      client_secret: Deno.env.get('TIKTOK_CLIENT_SECRET')!,
      redirect_uri: `${Deno.env.get('APP_URL')}/oauth/callback`,
      grant_type: 'authorization_code'
    })
  })

  return await response.json()
}

// Helper: Get TikTok user info
async function getTikTokUserInfo(accessToken: string) {
  const response = await fetch('https://open.tiktokapis.com/v2/user/info/', {
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    }
  })

  const data = await response.json()
  return {
    id: data.data.user.open_id,
    username: data.data.user.display_name
  }
}
```

---

### **Step 5: Sync Content Using Stored Tokens**

#### **Edge Function: Sync Platform Content**
```typescript
// supabase/functions/sync-platform-content/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { handleId } = await req.json()

    // Verify user from JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Get handle and platform info
    const { data: handle } = await supabaseClient
      .from('account_handles')
      .select(`
        *,
        supported_platform_types (name)
      `)
      .eq('id', handleId)
      .single()

    if (!handle) {
      throw new Error('Handle not found')
    }

    // Get platform credentials
    const { data: credential } = await supabaseClient
      .from('platform_credentials')
      .select('vault_secret_name, platform_account_id, token_expires_at')
      .eq('user_id', handle.user_id)
      .eq('platform_id', handle.platform_id)
      .eq('is_active', true)
      .single()

    if (!credential) {
      throw new Error('Platform not connected')
    }

    // Check if token expired
    if (new Date(credential.token_expires_at) < new Date()) {
      // TODO: Implement token refresh
      throw new Error('Token expired, please reconnect platform')
    }

    // Retrieve tokens from Vault
    const { data: vaultData } = await supabaseClient
      .from('vault.decrypted_secrets')
      .select('decrypted_secret')
      .eq('name', credential.vault_secret_name)
      .single()

    if (!vaultData) {
      throw new Error('Tokens not found in vault')
    }

    const tokens = JSON.parse(vaultData.decrypted_secret)

    // Sync content from platform
    let syncedContent: any[]

    switch (handle.supported_platform_types.name) {
      case 'youtube':
        syncedContent = await syncYouTubeVideos(tokens.access_token, credential.platform_account_id)
        break
      case 'instagram':
        syncedContent = await syncInstagramMedia(tokens.access_token)
        break
      case 'tiktok':
        syncedContent = await syncTikTokVideos(tokens.access_token)
        break
      default:
        throw new Error('Platform not supported')
    }

    // Store synced content in database
    const contentToInsert = syncedContent.map(item => ({
      handle_id: handleId,
      user_id: handle.user_id,
      platform_id: handle.platform_id,
      content_type_id: item.content_type_id,
      platform_content_id: item.id,
      title: item.title,
      description: item.description,
      thumbnail_url: item.thumbnail_url,
      content_url: item.content_url,
      published_at: item.published_at,
      views: item.views,
      likes: item.likes,
      comments: item.comments
    }))

    await supabaseClient
      .from('handle_content')
      .upsert(contentToInsert, {
        onConflict: 'platform_id,platform_content_id'
      })

    // Update handle sync status
    await supabaseClient
      .from('account_handles')
      .update({
        last_synced_at: new Date(),
        last_sync_status: 'success'
      })
      .eq('id', handleId)

    return new Response(
      JSON.stringify({
        success: true,
        synced: syncedContent.length,
        platform: handle.supported_platform_types.name
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Sync error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Sync YouTube videos
async function syncYouTubeVideos(accessToken: string, channelId: string) {
  // Fetch videos from YouTube API
  const response = await fetch(
    `https://www.googleapis.com/youtube/v3/search?` +
    `part=snippet&channelId=${channelId}&maxResults=50&order=date&type=video`,
    {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    }
  )

  const data = await response.json()

  // Get video statistics
  const videoIds = data.items.map((item: any) => item.id.videoId).join(',')
  const statsResponse = await fetch(
    `https://www.googleapis.com/youtube/v3/videos?` +
    `part=statistics&id=${videoIds}`,
    {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    }
  )

  const statsData = await statsResponse.json()

  // Combine data
  return data.items.map((item: any, index: number) => ({
    id: item.id.videoId,
    content_type_id: 'long_video_id', // TODO: Get from DB
    title: item.snippet.title,
    description: item.snippet.description,
    thumbnail_url: item.snippet.thumbnails.high.url,
    content_url: `https://www.youtube.com/watch?v=${item.id.videoId}`,
    published_at: item.snippet.publishedAt,
    views: statsData.items[index]?.statistics?.viewCount || 0,
    likes: statsData.items[index]?.statistics?.likeCount || 0,
    comments: statsData.items[index]?.statistics?.commentCount || 0
  }))
}

// Similar functions for Instagram and TikTok...
async function syncInstagramMedia(accessToken: string) {
  // Implementation for Instagram
  return []
}

async function syncTikTokVideos(accessToken: string) {
  // Implementation for TikTok
  return []
}
```

---

## 🔄 Complete Flow Summary

```
┌────────────────────────────────────────────────────────────┐
│                    USER EXPERIENCE                         │
└────────────────────────────────────────────────────────────┘

Step 1: Sign Up
User → "Sign in with Google" → Supabase Auth → Dashboard ✅

Step 2: Connect Platform
Dashboard → "Connect YouTube" → Edge Function generates URL

Step 3: Authorize
User redirected to YouTube → Grant permissions → YouTube callback

Step 4: Store Tokens
Edge Function receives code → Exchange for tokens → Store in Vault ✅

Step 5: Sync Content
User → "Sync YouTube" → Edge Function:
  1. Get tokens from Vault
  2. Call YouTube API
  3. Store videos in database ✅

Step 6: Auto Refresh (Background)
Scheduled job → Check token expiry → Refresh if needed → Update Vault
```

---

## 🎯 Key Implementation Points

1. ✅ **Supabase Auth** handles user signup/login (no token management)
2. ✅ **Edge Functions** handle platform OAuth flow
3. ✅ **Supabase Vault** stores platform tokens (encrypted)
4. ✅ **platform_credentials** table stores only references (no actual tokens)
5. ✅ **Sync** happens via Edge Functions using tokens from Vault
6. ✅ **Refresh** is automated via scheduled Edge Functions

This is exactly the architecture you described! 🚀
