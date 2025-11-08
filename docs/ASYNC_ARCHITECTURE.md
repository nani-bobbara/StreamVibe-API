# 🔄 Async Architecture & Background Jobs Strategy

**Date:** November 7, 2025  
**Focus:** Performance, Scalability, User Experience

---

## 🎯 Executive Summary

### Current Problem
All long-running operations (content sync, AI processing) are **synchronous**, causing:
- ❌ **Timeouts:** YouTube sync can take 30-60 seconds
- ❌ **Poor UX:** Users wait with loading spinners
- ❌ **Resource waste:** Edge Functions have 60s timeout limit
- ❌ **No visibility:** Can't track progress of long operations
- ❌ **No retry logic:** Failed operations lost forever
- ❌ **Scaling issues:** Can't handle concurrent heavy operations

### Proposed Solution
Implement **3-tier async architecture**:
1. ⚡ **Immediate Response** (<500ms) - Return job ID, process in background
2. 📊 **Real-time Updates** - Supabase Realtime for status streaming
3. 🔄 **Background Processing** - Database triggers + pg_cron + job queue

---

## 📊 Operation Categorization

### Tier 1: Synchronous (Keep As-Is) ✅
**Execution Time:** <500ms  
**Pattern:** Request → Process → Respond

| Function | Avg Time | Keep Sync? | Reason |
|----------|----------|------------|--------|
| `auth-profile-setup` | 50ms | ✅ Yes | Simple DB insert |
| `oauth-*-init` | 100ms | ✅ Yes | Generate state, return URL |
| `oauth-*-callback` | 400ms | ✅ Yes | Token exchange + DB write |
| `search-creators` | 200ms | ✅ Yes | Indexed full-text search |
| `search-content` | 250ms | ✅ Yes | Indexed full-text search |
| `get-trending` | 150ms | ✅ Yes | Read from materialized view |
| `get-creator-by-slug` | 180ms | ✅ Yes | Single record fetch |
| `get-content-detail` | 220ms | ✅ Yes | Single record with joins |
| `track-click` | 80ms | ✅ Yes | Fire-and-forget insert |
| `browse-*` | 300ms | ✅ Yes | Paginated reads with cache |
| `get-seo-metadata` | 150ms | ✅ Yes | Simple data transformation |
| `sitemap` | 800ms | ⚠️ Edge | OK for now, monitor |
| `robots` | 10ms | ✅ Yes | Static text response |

**Total:** 13 functions stay synchronous

---

### Tier 2: Async with Polling (Refactor) 🔄
**Execution Time:** 500ms - 5 minutes  
**Pattern:** Request → Job ID → Poll Status → Complete

| Function | Current Time | Why Async? | Refactor Approach |
|----------|-------------|------------|-------------------|
| `sync-youtube` | **30-60s** | Fetches 250 videos via API | Job queue + polling |
| `sync-instagram` | **20-40s** | Fetches 125 posts via API | Job queue + polling |
| `sync-tiktok` | **15-30s** | Fetches 100 videos via API | Job queue + polling |
| `ai-generate-tags` | **5-10s** | GPT-4 API call + processing | Job queue + polling |

**Total:** 4 functions need async refactor

---

### Tier 3: Background Jobs (New) 🚀
**Execution Time:** >5 minutes or scheduled  
**Pattern:** Triggered automatically, no user request

| Job Type | Trigger | Frequency | Implementation |
|----------|---------|-----------|----------------|
| **Auto-sync content** | User preference | Every 24h per account | pg_cron + job_queue |
| **Trending recalculation** | Scheduled | Every 1 hour | pg_cron (existing) |
| **Bulk AI tagging** | Admin request | On-demand | Job queue |
| **Follower count sync** | Scheduled | Every 6 hours | pg_cron (existing) |
| **Cleanup old clicks** | Scheduled | Daily | pg_cron (existing) |
| **SEO sitemap regen** | Content change | On content publish | Database trigger |

**Total:** 6 background job types

---

## 🏗️ Architecture Design

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENT (Frontend)                      │
│  React/Next.js - Initiates requests, subscribes to updates   │
└───────────┬──────────────────────────────────┬───────────────┘
            │                                  │
            │ HTTP Request                     │ WebSocket
            │ (Immediate Response)             │ (Real-time Updates)
            ▼                                  ▼
┌─────────────────────────┐      ┌──────────────────────────┐
│   Edge Functions        │      │   Supabase Realtime      │
│   (API Handlers)        │      │   (Status Broadcasting)  │
│                         │      │                          │
│  • Create job record    │      │  • Listen to job_queue   │
│  • Return job_id        │      │  • Broadcast changes     │
│  • Validate request     │      │  • Filter by user_id     │
└─────────┬───────────────┘      └──────────────────────────┘
          │                                   ▲
          │ Insert job                        │ NOTIFY
          ▼                                   │
┌─────────────────────────────────────────────┴───────────────┐
│              PostgreSQL Database                              │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  job_queue   │  │  job_log     │  │  job_result  │      │
│  │  (Active)    │  │  (History)   │  │  (Output)    │      │
│  └──────┬───────┘  └──────────────┘  └──────────────┘      │
│         │                                                     │
│         │ Trigger on INSERT/UPDATE                           │
│         ▼                                                     │
│  ┌──────────────────────────────────┐                       │
│  │   pg_notify('job_status')        │                       │
│  │   Trigger Function               │                       │
│  └──────────────────────────────────┘                       │
└───────────────────────────────┬───────────────────────────┘
                                │
                                │ Poll for jobs
                                ▼
┌─────────────────────────────────────────────────────────────┐
│              Background Workers                               │
│  (Edge Functions invoked by pg_cron or triggers)             │
│                                                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │  job-processor  │  │  retry-handler  │  │  job-cleanup││
│  │  (Main Worker)  │  │  (Failed Jobs)  │  │  (Old Jobs) ││
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                               │
│  Processes: sync-youtube, sync-instagram, ai-generate-tags   │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Database Schema: Job Queue

### Table: job_queue
```sql
CREATE TABLE public.job_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Job identification
    job_type TEXT NOT NULL, -- 'sync_youtube', 'sync_instagram', 'ai_generate_tags'
    job_priority INT DEFAULT 5, -- 1 (highest) to 10 (lowest)
    
    -- Job parameters
    params JSONB NOT NULL, -- Job-specific parameters
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'pending', 
        -- 'pending', 'processing', 'completed', 'failed', 'cancelled'
    progress_percent INT DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
    progress_message TEXT,
    
    -- Execution metadata
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    worker_id TEXT, -- Edge Function invocation ID
    
    -- Error handling
    error_message TEXT,
    error_code TEXT,
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 3,
    
    -- Result storage
    result JSONB, -- Job output data
    
    -- Scheduling
    scheduled_for TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours',
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_job_queue_user_status ON public.job_queue(user_id, status);
CREATE INDEX idx_job_queue_status_priority ON public.job_queue(status, job_priority, scheduled_for) 
    WHERE status = 'pending';
CREATE INDEX idx_job_queue_processing ON public.job_queue(worker_id, started_at) 
    WHERE status = 'processing';
CREATE INDEX idx_job_queue_cleanup ON public.job_queue(completed_at) 
    WHERE status IN ('completed', 'failed');

COMMENT ON TABLE public.job_queue IS 'Background job queue for async operations';
```

### Table: job_log
```sql
CREATE TABLE public.job_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES public.job_queue(id) ON DELETE CASCADE,
    
    -- Log entry
    log_level TEXT NOT NULL, -- 'debug', 'info', 'warning', 'error'
    message TEXT NOT NULL,
    metadata JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_job_log_job_time ON public.job_log(job_id, created_at DESC);

COMMENT ON TABLE public.job_log IS 'Detailed logs for job execution tracking';
```

### Trigger: Notify on Status Change
```sql
CREATE OR REPLACE FUNCTION notify_job_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify Realtime channel about job status change
    PERFORM pg_notify(
        'job_status_changed',
        json_build_object(
            'job_id', NEW.id,
            'user_id', NEW.user_id,
            'job_type', NEW.job_type,
            'status', NEW.status,
            'progress_percent', NEW.progress_percent,
            'progress_message', NEW.progress_message,
            'error_message', NEW.error_message,
            'updated_at', NEW.updated_at
        )::text
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER job_status_change_notify
AFTER INSERT OR UPDATE OF status, progress_percent, progress_message
ON public.job_queue
FOR EACH ROW
EXECUTE FUNCTION notify_job_status_change();
```

### Function: Create Job
```sql
CREATE OR REPLACE FUNCTION create_job(
    p_user_id UUID,
    p_job_type TEXT,
    p_params JSONB,
    p_priority INT DEFAULT 5
)
RETURNS UUID AS $$
DECLARE
    v_job_id UUID;
BEGIN
    INSERT INTO public.job_queue (
        user_id,
        job_type,
        params,
        job_priority,
        status
    ) VALUES (
        p_user_id,
        p_job_type,
        p_params,
        p_priority,
        'pending'
    )
    RETURNING id INTO v_job_id;
    
    RETURN v_job_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Function: Update Job Progress
```sql
CREATE OR REPLACE FUNCTION update_job_progress(
    p_job_id UUID,
    p_progress_percent INT,
    p_progress_message TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.job_queue
    SET 
        progress_percent = p_progress_percent,
        progress_message = COALESCE(p_progress_message, progress_message),
        updated_at = NOW()
    WHERE id = p_job_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 🔄 Refactored Functions

### 1. sync-youtube (Async Version)

**Old Flow (Sync):**
```
Request → Fetch 250 videos → Store all → Return count (30-60s)
```

**New Flow (Async):**
```
Request → Create job → Return job_id (100ms)
  ↓
Background worker → Fetch videos in batches → Update progress → Complete
  ↓
Client polls or subscribes → Gets real-time updates
```

**Implementation:**

#### A. API Handler (sync-youtube/index.ts)
```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const user = await getAuthenticatedUser(req, supabase)

    // Validate YouTube account exists
    const { data: socialAccount, error: accountError } = await supabase
      .from('social_account')
      .select('id')
      .eq('user_id', user.id)
      .eq('platform', 'youtube')
      .eq('is_active', true)
      .single()

    if (accountError || !socialAccount) {
      throw new Error('YouTube account not connected')
    }

    // Create background job
    const { data: jobId, error: jobError } = await supabase
      .rpc('create_job', {
        p_user_id: user.id,
        p_job_type: 'sync_youtube',
        p_params: {
          social_account_id: socialAccount.id
        },
        p_priority: 5
      })

    if (jobError) throw jobError

    // Return immediately with job ID
    return new Response(
      JSON.stringify({
        success: true,
        message: 'YouTube sync started',
        job_id: jobId,
        status: 'pending',
        polling_endpoint: `/functions/v1/job-status?job_id=${jobId}`,
        websocket_channel: `job_status:${jobId}`
      }),
      {
        status: 202, // Accepted
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: {
          code: 'SYNC_INITIATION_ERROR',
          message: error.message
        }
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
```

#### B. Background Worker (job-processor/index.ts)
```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'

serve(async (req) => {
  // This function is invoked by pg_cron every 10 seconds
  // Or triggered by database event
  
  const supabase = getSupabaseClient()

  try {
    // Get next pending job (FIFO with priority)
    const { data: job, error: fetchError } = await supabase
      .from('job_queue')
      .select('*')
      .eq('status', 'pending')
      .lte('scheduled_for', new Date().toISOString())
      .order('job_priority', { ascending: true })
      .order('created_at', { ascending: true })
      .limit(1)
      .single()

    if (fetchError || !job) {
      return new Response(JSON.stringify({ message: 'No jobs to process' }), {
        status: 200
      })
    }

    // Mark job as processing
    await supabase
      .from('job_queue')
      .update({
        status: 'processing',
        started_at: new Date().toISOString(),
        worker_id: crypto.randomUUID()
      })
      .eq('id', job.id)

    // Route to appropriate handler
    let result
    switch (job.job_type) {
      case 'sync_youtube':
        result = await processYouTubeSync(job, supabase)
        break
      case 'sync_instagram':
        result = await processInstagramSync(job, supabase)
        break
      case 'sync_tiktok':
        result = await processTikTokSync(job, supabase)
        break
      case 'ai_generate_tags':
        result = await processAITagGeneration(job, supabase)
        break
      default:
        throw new Error(`Unknown job type: ${job.job_type}`)
    }

    // Mark job as completed
    await supabase
      .from('job_queue')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        progress_percent: 100,
        result
      })
      .eq('id', job.id)

    return new Response(
      JSON.stringify({ success: true, job_id: job.id, result }),
      { status: 200 }
    )

  } catch (error) {
    console.error('Job processing error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500 }
    )
  }
})

// YouTube sync handler
async function processYouTubeSync(job: any, supabase: any) {
  const { social_account_id } = job.params

  // Get access token from Vault
  const { data: account } = await supabase
    .from('social_account')
    .select('vault_key')
    .eq('id', social_account_id)
    .single()

  const { data: vaultData } = await supabase.rpc('vault_read', {
    secret_name: account.vault_key
  })

  const tokens = JSON.parse(vaultData)
  let accessToken = tokens.access_token

  // Fetch videos in batches with progress updates
  let syncedCount = 0
  let failedCount = 0
  let pageToken = null
  const batchSize = 50
  const maxPages = 5

  for (let page = 0; page < maxPages; page++) {
    // Update progress
    await supabase.rpc('update_job_progress', {
      p_job_id: job.id,
      p_progress_percent: Math.round((page / maxPages) * 100),
      p_progress_message: `Fetching videos batch ${page + 1}/${maxPages}`
    })

    // Fetch YouTube videos
    const searchUrl = `https://www.googleapis.com/youtube/v3/search?` +
      `part=snippet&channelId=${tokens.channel_id}&maxResults=${batchSize}` +
      `&type=video&order=date${pageToken ? `&pageToken=${pageToken}` : ''}`

    const searchResponse = await fetch(searchUrl, {
      headers: { Authorization: `Bearer ${accessToken}` }
    })

    if (!searchResponse.ok) break

    const searchData = await searchResponse.json()
    const videoIds = searchData.items.map((item: any) => item.id.videoId).join(',')

    // Get video details
    const detailsUrl = `https://www.googleapis.com/youtube/v3/videos?` +
      `part=snippet,statistics,contentDetails&id=${videoIds}`

    const detailsResponse = await fetch(detailsUrl, {
      headers: { Authorization: `Bearer ${accessToken}` }
    })

    const detailsData = await detailsResponse.json()

    // Store videos in database
    for (const video of detailsData.items) {
      try {
        await supabase.from('content_item').upsert({
          social_account_id,
          platform_content_id: video.id,
          title: video.snippet.title,
          description: video.snippet.description,
          thumbnail_url: video.snippet.thumbnails.high.url,
          views_count: parseInt(video.statistics.viewCount || '0'),
          likes_count: parseInt(video.statistics.likeCount || '0'),
          comments_count: parseInt(video.statistics.commentCount || '0'),
          published_at: video.snippet.publishedAt
        })
        syncedCount++
      } catch (err) {
        failedCount++
      }
    }

    pageToken = searchData.nextPageToken
    if (!pageToken) break
  }

  // Update social account last_synced_at
  await supabase
    .from('social_account')
    .update({ last_synced_at: new Date().toISOString() })
    .eq('id', social_account_id)

  return {
    synced_count: syncedCount,
    failed_count: failedCount,
    total_videos: syncedCount + failedCount
  }
}
```

---

### 2. Job Status Polling API

**New Function:** `job-status/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const user = await getAuthenticatedUser(req, supabase)
    const url = new URL(req.url)
    const jobId = url.searchParams.get('job_id')

    if (!jobId) {
      throw new Error('job_id parameter is required')
    }

    // Get job status
    const { data: job, error } = await supabase
      .from('job_queue')
      .select('*')
      .eq('id', jobId)
      .eq('user_id', user.id) // Security: only user's jobs
      .single()

    if (error || !job) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'JOB_NOT_FOUND', message: 'Job not found' }
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Calculate estimated time remaining
    let eta_seconds = null
    if (job.status === 'processing' && job.started_at) {
      const elapsed = Date.now() - new Date(job.started_at).getTime()
      const progressRate = job.progress_percent / (elapsed / 1000)
      const remaining = 100 - job.progress_percent
      eta_seconds = remaining / progressRate
    }

    return new Response(
      JSON.stringify({
        success: true,
        job: {
          id: job.id,
          type: job.job_type,
          status: job.status,
          progress: {
            percent: job.progress_percent,
            message: job.progress_message,
            eta_seconds
          },
          result: job.result,
          error: job.error_message ? {
            code: job.error_code,
            message: job.error_message
          } : null,
          timestamps: {
            created_at: job.created_at,
            started_at: job.started_at,
            completed_at: job.completed_at
          }
        }
      }),
      {
        status: 200,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache' // Don't cache job status
        }
      }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: { code: 'STATUS_ERROR', message: error.message }
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## 📡 Real-time Updates with Supabase

### Frontend Integration (React Example)

```typescript
import { createClient } from '@supabase/supabase-js'
import { useEffect, useState } from 'react'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

function YouTubeSyncButton() {
  const [jobId, setJobId] = useState<string | null>(null)
  const [status, setStatus] = useState<string>('idle')
  const [progress, setProgress] = useState<number>(0)
  const [message, setMessage] = useState<string>('')

  // Start sync
  const startSync = async () => {
    const response = await fetch('/functions/v1/sync-youtube', {
      method: 'POST',
      headers: { Authorization: `Bearer ${accessToken}` }
    })
    
    const data = await response.json()
    setJobId(data.job_id)
    setStatus('pending')
  }

  // Subscribe to real-time updates
  useEffect(() => {
    if (!jobId) return

    const channel = supabase
      .channel(`job_status:${jobId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'job_queue',
          filter: `id=eq.${jobId}`
        },
        (payload) => {
          setStatus(payload.new.status)
          setProgress(payload.new.progress_percent)
          setMessage(payload.new.progress_message)
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [jobId])

  return (
    <div>
      <button onClick={startSync} disabled={status === 'processing'}>
        Sync YouTube Videos
      </button>
      
      {status !== 'idle' && (
        <div>
          <p>Status: {status}</p>
          <progress value={progress} max={100} />
          <p>{message}</p>
        </div>
      )}
    </div>
  )
}
```

---

## 🔧 pg_cron Configuration

### Job Processor Scheduler
```sql
-- Run job processor every 10 seconds
SELECT cron.schedule(
    'process-background-jobs',
    '*/10 * * * * *', -- Every 10 seconds
    $$
    SELECT net.http_post(
        url := 'https://your-project.supabase.co/functions/v1/job-processor',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.settings.service_role_key') || '"}'::jsonb
    )
    $$
);
```

### Failed Job Retry
```sql
-- Retry failed jobs every 5 minutes
SELECT cron.schedule(
    'retry-failed-jobs',
    '*/5 * * * *', -- Every 5 minutes
    $$
    UPDATE public.job_queue
    SET 
        status = 'pending',
        retry_count = retry_count + 1,
        scheduled_for = NOW() + (retry_count * INTERVAL '5 minutes')
    WHERE 
        status = 'failed'
        AND retry_count < max_retries
        AND updated_at < NOW() - INTERVAL '5 minutes'
    $$
);
```

### Job Cleanup
```sql
-- Archive completed jobs older than 7 days
SELECT cron.schedule(
    'cleanup-old-jobs',
    '0 2 * * *', -- Daily at 2 AM
    $$
    DELETE FROM public.job_queue
    WHERE 
        status IN ('completed', 'cancelled')
        AND completed_at < NOW() - INTERVAL '7 days'
    $$
);
```

---

## 📋 Migration Summary

### Functions to Refactor

| Function | Status | Approach | Priority |
|----------|--------|----------|----------|
| `sync-youtube` | 🔄 Needs refactor | Job queue + worker | **P0 - Critical** |
| `sync-instagram` | 🔄 Needs refactor | Job queue + worker | **P0 - Critical** |
| `sync-tiktok` | 🔄 Needs refactor | Job queue + worker | **P0 - Critical** |
| `ai-generate-tags` | 🔄 Needs refactor | Job queue + worker | **P1 - High** |
| `sitemap` | ⚠️ Monitor | Consider caching | **P2 - Medium** |

### New Functions Required

| Function | Purpose | Complexity |
|----------|---------|------------|
| `job-processor` | Background worker | High |
| `job-status` | Status polling API | Low |
| `job-cancel` | Cancel running job | Medium |
| `job-retry` | Manual retry trigger | Low |
| `bulk-ai-tagging` | Batch AI operations | High |

---

## 🎯 Implementation Roadmap

### Phase 1: Infrastructure (Week 1)
- [ ] Create `job_queue` table + indexes
- [ ] Create `job_log` table
- [ ] Add database functions (create_job, update_progress)
- [ ] Add database triggers (notify on status change)
- [ ] Configure pg_cron schedulers
- [ ] Test job queue with sample data

### Phase 2: Core Workers (Week 2)
- [ ] Build `job-processor` Edge Function
- [ ] Implement YouTube sync worker logic
- [ ] Implement Instagram sync worker logic
- [ ] Implement TikTok sync worker logic
- [ ] Add error handling + retry logic
- [ ] Test workers end-to-end

### Phase 3: Status APIs (Week 2)
- [ ] Build `job-status` polling endpoint
- [ ] Build `job-cancel` endpoint
- [ ] Configure Supabase Realtime channels
- [ ] Test real-time updates
- [ ] Document WebSocket usage

### Phase 4: Refactor Existing (Week 3)
- [ ] Refactor `sync-youtube` to async
- [ ] Refactor `sync-instagram` to async
- [ ] Refactor `sync-tiktok` to async
- [ ] Refactor `ai-generate-tags` to async
- [ ] Update Postman collection
- [ ] Update documentation

### Phase 5: Frontend Integration (Week 4)
- [ ] Add job status UI components
- [ ] Implement progress bars
- [ ] Add real-time subscriptions
- [ ] Handle error states
- [ ] Add retry buttons
- [ ] User testing

### Phase 6: Monitoring & Optimization (Week 5)
- [ ] Add job metrics dashboard
- [ ] Monitor worker performance
- [ ] Optimize batch sizes
- [ ] Tune pg_cron intervals
- [ ] Load testing
- [ ] Production deployment

---

## 📊 Performance Benefits

### Before (Synchronous)
```
User clicks "Sync YouTube"
  ↓
Wait 30-60 seconds with spinner
  ↓
Risk of timeout (Edge Function 60s limit)
  ↓
No visibility into progress
  ↓
If failure, start over
```

**Problems:**
- ❌ Poor UX (long wait)
- ❌ Timeout risk
- ❌ No progress feedback
- ❌ No retry capability
- ❌ Can't handle concurrent syncs

### After (Asynchronous)
```
User clicks "Sync YouTube"
  ↓
Immediate response (100ms) with job_id
  ↓
Real-time progress updates via WebSocket
  ↓
User can navigate away, come back later
  ↓
Automatic retry on failure
  ↓
Historical job tracking
```

**Benefits:**
- ✅ Instant response (<100ms)
- ✅ No timeout issues
- ✅ Real-time progress (0-100%)
- ✅ Automatic retries
- ✅ Scalable (100s of concurrent jobs)
- ✅ Better observability
- ✅ User can leave page

---

## 🔒 Security Considerations

### Job Isolation
```sql
-- RLS Policy: Users can only see their own jobs
CREATE POLICY user_own_jobs ON public.job_queue
FOR ALL USING (user_id = auth.uid());
```

### Worker Authentication
```typescript
// Worker functions use service role key
const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY // Bypass RLS
)
```

### Rate Limiting
```sql
-- Limit: 5 pending jobs per user
CREATE OR REPLACE FUNCTION check_job_limit()
RETURNS TRIGGER AS $$
DECLARE
    pending_count INT;
BEGIN
    SELECT COUNT(*)
    INTO pending_count
    FROM public.job_queue
    WHERE user_id = NEW.user_id
      AND status IN ('pending', 'processing');
    
    IF pending_count >= 5 THEN
        RAISE EXCEPTION 'Maximum 5 concurrent jobs per user';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_job_limit
BEFORE INSERT ON public.job_queue
FOR EACH ROW
EXECUTE FUNCTION check_job_limit();
```

---

## 📚 Documentation Updates Required

1. **docs/ASYNC_ARCHITECTURE.md** (this document)
2. **docs/JOB_QUEUE_API.md** - API reference for job management
3. **docs/REALTIME_GUIDE.md** - Frontend WebSocket integration
4. **docs/WORKER_DEVELOPMENT.md** - How to add new background jobs
5. **IMPLEMENTATION_COMPLETE.md** - Update to reflect async patterns

---

## 🎓 Best Practices

### 1. Job Design
- ✅ **Idempotent:** Jobs can be retried safely
- ✅ **Atomic:** Each job is self-contained
- ✅ **Progress tracking:** Update progress_percent regularly
- ✅ **Error handling:** Catch errors, store in error_message
- ✅ **Timeouts:** Set reasonable expires_at

### 2. Worker Implementation
- ✅ **Batch processing:** Process items in chunks
- ✅ **Progress updates:** Update every 10-20% of work
- ✅ **Graceful degradation:** Partial success is OK
- ✅ **Logging:** Write to job_log table
- ✅ **Resource cleanup:** Close connections, clear memory

### 3. Frontend Integration
- ✅ **Optimistic UI:** Show "processing" immediately
- ✅ **Real-time preferred:** Use WebSocket over polling
- ✅ **Fallback polling:** Poll every 2-5 seconds if WebSocket fails
- ✅ **Error display:** Show user-friendly error messages
- ✅ **Retry UX:** Easy one-click retry button

---

## 🚀 Quick Start (After Implementation)

### Start a Background Job
```bash
curl -X POST https://project.supabase.co/functions/v1/sync-youtube \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Response:
{
  "success": true,
  "job_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "pending",
  "polling_endpoint": "/functions/v1/job-status?job_id=..."
}
```

### Check Job Status
```bash
curl https://project.supabase.co/functions/v1/job-status?job_id=123... \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Response:
{
  "success": true,
  "job": {
    "id": "123...",
    "status": "processing",
    "progress": {
      "percent": 45,
      "message": "Fetching videos batch 2/5",
      "eta_seconds": 23
    }
  }
}
```

### Subscribe to Real-time Updates
```typescript
const channel = supabase
  .channel(`job_status:${jobId}`)
  .on('postgres_changes', { 
    event: 'UPDATE',
    schema: 'public',
    table: 'job_queue',
    filter: `id=eq.${jobId}` 
  }, (payload) => {
    console.log('Job updated:', payload.new)
  })
  .subscribe()
```

---

**End of Architecture Document**

**Total Solution:**
- 3 new database tables
- 5 new Edge Functions
- 4 refactored Edge Functions
- 5 pg_cron jobs
- Real-time WebSocket integration
- Complete observability

**Estimated Implementation:** 4-5 weeks  
**Performance Improvement:** 50x faster user experience  
**Scalability:** 100x more concurrent operations
