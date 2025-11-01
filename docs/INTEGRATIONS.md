# StreamVibe - Integrations Guide

Complete setup guide for OAuth, Stripe, AI, and SEO integrations.

## 📋 Table of Contents

1. [OAuth Integration](#oauth-integration)
2. [Stripe Integration](#stripe-integration)
3. [AI Integration](#ai-integration)
4. [SEO Integration](#seo-integration)

---

## 🔐 OAuth Integration

### Two OAuth Systems

**1. User Authentication** (Supabase Auth)
- **Purpose**: User login to StreamVibe
- **Providers**: Google, Facebook, Email/Password
- **Managed By**: Supabase (automatic)
- **Setup**: Supabase Dashboard > Authentication > Providers

**2. Platform Access** (Platform OAuth)
- **Purpose**: Access user's social media content
- **Platforms**: YouTube, Instagram, TikTok, Facebook
- **Managed By**: Edge Functions (manual)
- **Tokens Stored**: Supabase Vault (encrypted)

### Setup Platform OAuth

#### 1. Register OAuth Apps

**YouTube Data API**
```
1. Visit: https://console.cloud.google.com/
2. Create new project: "StreamVibe"
3. Enable API: YouTube Data API v3
4. Create credentials: OAuth 2.0 Client ID
   - Application type: Web application
   - Authorized redirect URIs:
     * http://localhost:3000/oauth/callback (dev)
     * https://streamvibe.app/oauth/callback (prod)
5. Copy:
   - Client ID → YOUTUBE_CLIENT_ID
   - Client Secret → YOUTUBE_CLIENT_SECRET
6. Scopes needed:
   - https://www.googleapis.com/auth/youtube.readonly
   - https://www.googleapis.com/auth/youtube.force-ssl
```

**Instagram Basic Display API**
```
1. Visit: https://developers.facebook.com/apps
2. Create new app: "StreamVibe"
3. Add product: Instagram Basic Display
4. Configure OAuth:
   - Valid OAuth Redirect URIs:
     * https://streamvibe.app/oauth/callback
   - Deauthorize Callback URL:
     * https://streamvibe.app/oauth/deauth
5. Copy:
   - Instagram App ID → INSTAGRAM_CLIENT_ID
   - Instagram App Secret → INSTAGRAM_CLIENT_SECRET
6. Submit for review (required for production)
```

**TikTok for Developers**
```
1. Visit: https://developers.tiktok.com/
2. Create app: "StreamVibe"
3. Configure:
   - Redirect URI: https://streamvibe.app/oauth/callback
4. Request scopes:
   - user.info.basic
   - video.list
5. Copy:
   - Client Key → TIKTOK_CLIENT_ID
   - Client Secret → TIKTOK_CLIENT_SECRET
```

#### 2. Store Credentials in Supabase

```bash
# Set secrets in Supabase
supabase secrets set YOUTUBE_CLIENT_ID="your-client-id"
supabase secrets set YOUTUBE_CLIENT_SECRET="your-secret"
supabase secrets set INSTAGRAM_CLIENT_ID="your-app-id"
supabase secrets set INSTAGRAM_CLIENT_SECRET="your-secret"
supabase secrets set TIKTOK_CLIENT_ID="your-client-key"
supabase secrets set TIKTOK_CLIENT_SECRET="your-secret"
```

#### 3. Edge Function: Initiate OAuth

```typescript
// supabase/functions/oauth-initiate/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const PLATFORMS = {
  youtube: {
    authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
    scope: 'https://www.googleapis.com/auth/youtube.readonly',
    clientId: Deno.env.get('YOUTUBE_CLIENT_ID'),
  },
  instagram: {
    authUrl: 'https://api.instagram.com/oauth/authorize',
    scope: 'user_profile,user_media',
    clientId: Deno.env.get('INSTAGRAM_CLIENT_ID'),
  },
  tiktok: {
    authUrl: 'https://www.tiktok.com/auth/authorize',
    scope: 'user.info.basic,video.list',
    clientId: Deno.env.get('TIKTOK_CLIENT_ID'),
  }
}

serve(async (req) => {
  const { platform, userId } = await req.json()
  const config = PLATFORMS[platform]
  
  const redirectUri = 'https://streamvibe.app/oauth/callback'
  const state = `${userId}_${platform}_${Date.now()}`
  
  const authUrl = `${config.authUrl}?` +
    `client_id=${config.clientId}` +
    `&redirect_uri=${encodeURIComponent(redirectUri)}` +
    `&response_type=code` +
    `&scope=${encodeURIComponent(config.scope)}` +
    `&state=${state}` +
    `&access_type=offline` // Get refresh token
  
  return new Response(JSON.stringify({ authUrl, state }))
})
```

#### 4. Edge Function: OAuth Callback

```typescript
// supabase/functions/oauth-callback/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const url = new URL(req.url)
  const code = url.searchParams.get('code')
  const state = url.searchParams.get('state')
  
  const [userId, platform, timestamp] = state.split('_')
  
  // Initialize Supabase with service role (for Vault access)
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  // Exchange code for tokens
  const tokenResponse = await fetch(
    'https://oauth2.googleapis.com/token', // Example: YouTube
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        code,
        client_id: Deno.env.get('YOUTUBE_CLIENT_ID'),
        client_secret: Deno.env.get('YOUTUBE_CLIENT_SECRET'),
        redirect_uri: 'https://streamvibe.app/oauth/callback',
        grant_type: 'authorization_code'
      })
    }
  )
  
  const tokens = await tokenResponse.json()
  // { access_token, refresh_token, expires_in, scope }
  
  // Store tokens in Vault (encrypted)
  const vaultSecretName = `oauth_${platform}_${userId}`
  
  await supabase.rpc('vault.create_secret', {
    secret: JSON.stringify({
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_at: new Date(Date.now() + tokens.expires_in * 1000).toISOString(),
      scope: tokens.scope
    }),
    name: vaultSecretName
  })
  
  // Store reference in database (NOT the actual tokens!)
  const { data: platformData } = await supabase
    .from('platform')
    .select('id')
    .eq('slug', platform)
    .single()
  
  await supabase.from('platform_connection').insert({
    user_id: userId,
    platform_id: platformData.id,
    vault_secret_name: vaultSecretName,
    scopes: tokens.scope.split(' '),
    token_expires_at: new Date(Date.now() + tokens.expires_in * 1000).toISOString(),
    is_active: true,
    is_verified: true,
    last_verified_at: new Date().toISOString()
  })
  
  // Redirect user back to dashboard
  return Response.redirect('https://streamvibe.app/dashboard?connected=youtube')
})
```

#### 5. Retrieve Tokens from Vault

```typescript
// supabase/functions/sync-content/index.ts
async function getPlatformTokens(supabase, userId: string, platform: string) {
  // Get vault secret name from database
  const { data: connection } = await supabase
    .from('platform_connection')
    .select('vault_secret_name')
    .eq('user_id', userId)
    .eq('platform_id', platform)
    .eq('is_active', true)
    .single()
  
  if (!connection) throw new Error('Platform not connected')
  
  // Retrieve encrypted tokens from Vault
  const { data: secret } = await supabase.rpc('vault.read_secret', {
    secret_name: connection.vault_secret_name
  })
  
  const tokens = JSON.parse(secret)
  
  // Check if token expired and refresh if needed
  if (new Date(tokens.expires_at) < new Date()) {
    return await refreshPlatformTokens(supabase, connection.vault_secret_name, tokens)
  }
  
  return tokens
}
```

---

## 💳 Stripe Integration

### Setup

#### 1. Create Stripe Account

```
1. Visit: https://stripe.com
2. Create account
3. Get API keys:
   - Publishable Key (pk_test_...)
   - Secret Key (sk_test_...)
   - Webhook Secret (whsec_...)
```

#### 2. Create Products & Prices

```bash
# Create products in Stripe Dashboard or via API

# Free Tier
stripe products create \
  --name="Free" \
  --description="1 account, 10 syncs, 25 AI analyses"

stripe prices create \
  --product=prod_xxx \
  --unit-amount=0 \
  --currency=usd \
  --recurring[interval]=month

# Basic Tier
stripe products create \
  --name="Basic" \
  --description="3 accounts, 100 syncs, 100 AI analyses"

stripe prices create \
  --product=prod_yyy \
  --unit-amount=1900 \
  --currency=usd \
  --recurring[interval]=month

# Premium Tier
stripe products create \
  --name="Premium" \
  --description="10 accounts, 500 syncs, 500 AI analyses"

stripe prices create \
  --product=prod_zzz \
  --unit-amount=4900 \
  --currency=usd \
  --recurring[interval]=month
```

#### 3. Configure Webhooks

```
1. Stripe Dashboard > Developers > Webhooks
2. Add endpoint: https://your-project.supabase.co/functions/v1/stripe-webhook
3. Select events:
   - customer.subscription.created
   - customer.subscription.updated
   - customer.subscription.deleted
   - invoice.paid
   - invoice.payment_failed
   - checkout.session.completed
4. Copy webhook signing secret → STRIPE_WEBHOOK_SECRET
```

#### 4. Edge Function: Create Checkout Session

```typescript
// supabase/functions/create-checkout/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@13.0.0'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16'
})

serve(async (req) => {
  const { priceId, userId, email } = await req.json()
  
  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    customer_email: email,
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: 'https://streamvibe.app/dashboard?upgraded=true',
    cancel_url: 'https://streamvibe.app/pricing',
    metadata: { user_id: userId }
  })
  
  return new Response(JSON.stringify({ url: session.url }))
})
```

#### 5. Edge Function: Webhook Handler

```typescript
// supabase/functions/stripe-webhook/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@13.0.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!)
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

serve(async (req) => {
  const signature = req.headers.get('stripe-signature')
  const body = await req.text()
  
  // Verify webhook signature
  const event = stripe.webhooks.constructEvent(
    body,
    signature,
    Deno.env.get('STRIPE_WEBHOOK_SECRET')!
  )
  
  // Handle different events
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object
      const userId = session.metadata.user_id
      const customerId = session.customer
      const subscriptionId = session.subscription
      
      // Update subscription in database
      await supabase.from('subscription').update({
        stripe_customer_id: customerId,
        stripe_subscription_id: subscriptionId,
        cycle_start_date: new Date(),
        cycle_end_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      }).eq('user_id', userId)
      
      break
    }
    
    case 'customer.subscription.updated': {
      const subscription = event.data.object
      
      // Update tier based on price ID
      const { data: tier } = await supabase
        .from('subscription_tier')
        .select('id')
        .eq('stripe_price_id', subscription.items.data[0].price.id)
        .single()
      
      await supabase.from('subscription').update({
        tier_id: tier.id,
        status_id: /* map Stripe status */,
        cycle_start_date: new Date(subscription.current_period_start * 1000),
        cycle_end_date: new Date(subscription.current_period_end * 1000)
      }).eq('stripe_subscription_id', subscription.id)
      
      break
    }
    
    case 'customer.subscription.deleted': {
      const subscription = event.data.object
      
      // Mark subscription as canceled
      await supabase.from('subscription').update({
        status_id: /* canceled status */,
        canceled_at: new Date()
      }).eq('stripe_subscription_id', subscription.id)
      
      break
    }
  }
  
  return new Response(JSON.stringify({ received: true }))
})
```

---

## 🤖 AI Integration

### Supported Providers

- **OpenAI**: GPT-4o, GPT-4o-mini
- **Anthropic**: Claude 3.5 Sonnet
- **Google**: Gemini 1.5 Pro
- **Local**: Llama 3.2 (via Ollama)

### Setup

#### 1. Get API Keys

```bash
# OpenAI
# Visit: https://platform.openai.com/api-keys
OPENAI_API_KEY=sk-...

# Anthropic
# Visit: https://console.anthropic.com/
ANTHROPIC_API_KEY=sk-ant-...

# Google AI
# Visit: https://aistudio.google.com/app/apikey
GOOGLE_AI_API_KEY=AIza...
```

#### 2. Store in Supabase

```bash
supabase secrets set OPENAI_API_KEY="sk-..."
supabase secrets set ANTHROPIC_API_KEY="sk-ant-..."
supabase secrets set GOOGLE_AI_API_KEY="AIza..."
```

#### 3. Edge Function: AI Analysis

```typescript
// supabase/functions/ai-analyze/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import OpenAI from 'https://esm.sh/openai@4'

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

serve(async (req) => {
  const { contentId, userId } = await req.json()
  
  const supabase = createClient(/* ... */)
  
  // Get content
  const { data: content } = await supabase
    .from('content_item')
    .select('title, description, tags')
    .eq('id', contentId)
    .single()
  
  // Check quota
  const { data: hasQuota } = await supabase.rpc('check_quota', {
    user_id: userId,
    quota_type: 'ai_analysis'
  })
  
  if (!hasQuota) {
    return new Response('Quota exceeded', { status: 429 })
  }
  
  // Call OpenAI
  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      {
        role: 'system',
        content: 'You are an expert content optimizer. Analyze the content and provide optimized title, description, tags, and trending keywords.'
      },
      {
        role: 'user',
        content: `Title: ${content.title}\nDescription: ${content.description}\nTags: ${content.tags.join(', ')}`
      }
    ],
    response_format: { type: 'json_object' }
  })
  
  const suggestions = JSON.parse(response.choices[0].message.content)
  
  // Store suggestions
  await supabase.from('ai_suggestion').insert({
    content_item_id: contentId,
    provider_id: /* openai id */,
    model_id: /* gpt-4o-mini id */,
    suggested_titles: suggestions.titles,
    suggested_description: suggestions.description,
    suggested_tags: suggestions.tags,
    trending_keywords: suggestions.keywords,
    prompt_tokens: response.usage.prompt_tokens,
    completion_tokens: response.usage.completion_tokens,
    total_cost_cents: calculateCost(response.usage)
  })
  
  // Increment quota
  await supabase.rpc('increment_quota', {
    user_id: userId,
    quota_type: 'ai_analysis',
    amount: 1,
    entity_type: 'content_item',
    entity_id: contentId
  })
  
  return new Response(JSON.stringify(suggestions))
})
```

---

## 🔍 SEO Integration

### Supported Services

- **Google Search Console**: URL Indexing API
- **Bing Webmaster Tools**: URL Submission API
- **Yandex Webmaster**: Indexing API
- **IndexNow**: Protocol for instant indexing

### Setup Google Search Console

#### 1. Verify Domain

```
1. Visit: https://search.google.com/search-console
2. Add property: https://streamvibe.app
3. Verify ownership (DNS or HTML file)
4. Wait for verification
```

#### 2. Enable Indexing API

```
1. Visit: https://console.cloud.google.com/
2. Enable: Indexing API
3. Create service account
4. Download JSON key file
5. Add service account to Search Console:
   - Permissions: Owner
   - Email: xxx@xxx.iam.gserviceaccount.com
```

#### 3. Edge Function: Submit URL

```typescript
// supabase/functions/seo-submit/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

const auth = new GoogleAuth({
  credentials: JSON.parse(Deno.env.get('GOOGLE_SERVICE_ACCOUNT_KEY')!),
  scopes: ['https://www.googleapis.com/auth/indexing']
})

serve(async (req) => {
  const { contentUrl, userId } = await req.json()
  
  const client = await auth.getClient()
  const accessToken = await client.getAccessToken()
  
  // Submit to Google
  const response = await fetch(
    'https://indexing.googleapis.com/v3/urlNotifications:publish',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken.token}`
      },
      body: JSON.stringify({
        url: contentUrl,
        type: 'URL_UPDATED'
      })
    }
  )
  
  const result = await response.json()
  
  // Log submission
  await supabase.from('seo_submission').insert({
    content_item_id: contentId,
    search_engine_id: /* google id */,
    submitted_url: contentUrl,
    submission_type: 'url_updated',
    response_status: response.status,
    response_body: result,
    status: response.ok ? 'submitted' : 'failed',
    submitted_at: new Date()
  })
  
  // Increment quota
  await supabase.rpc('increment_quota', {
    user_id: userId,
    quota_type: 'seo_submission',
    amount: 1
  })
  
  return new Response(JSON.stringify(result))
})
```

---

## 🎯 Summary Checklist

### OAuth Setup
- [ ] Register YouTube app
- [ ] Register Instagram app
- [ ] Register TikTok app
- [ ] Store credentials in Supabase secrets
- [ ] Deploy oauth-initiate function
- [ ] Deploy oauth-callback function
- [ ] Test connection flow

### Stripe Setup
- [ ] Create Stripe account
- [ ] Create products & prices
- [ ] Configure webhook endpoint
- [ ] Store keys in Supabase secrets
- [ ] Deploy create-checkout function
- [ ] Deploy stripe-webhook function
- [ ] Test subscription flow

### AI Setup
- [ ] Get OpenAI API key
- [ ] Get Anthropic API key (optional)
- [ ] Store keys in Supabase secrets
- [ ] Deploy ai-analyze function
- [ ] Test analysis flow

### SEO Setup
- [ ] Verify domain in Search Console
- [ ] Enable Indexing API
- [ ] Create service account
- [ ] Store credentials in Supabase secrets
- [ ] Deploy seo-submit function
- [ ] Test URL submission

---

**Next Steps**: See [ARCHITECTURE.md](ARCHITECTURE.md) for system design details.
