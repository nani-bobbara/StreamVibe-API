import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('Track click function started')

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    
    const body = await req.json()
    const { content_id } = body

    if (!content_id) {
      throw new Error('content_id is required')
    }

    // Get user ID if authenticated (optional)
    const authHeader = req.headers.get('Authorization')
    let userId = null
    
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '')
      const { data: { user } } = await supabase.auth.getUser(token)
      userId = user?.id
    }

    // Get request metadata
    const userAgent = req.headers.get('user-agent') || ''
    const referer = req.headers.get('referer') || ''
    
    // Insert click record
    const { error: insertError } = await supabase
      .from('content_click')
      .insert({
        content_id,
        user_id: userId,
        referrer: referer,
        user_agent: userAgent,
      })

    if (insertError) {
      console.error('Failed to insert click:', insertError)
    }

    // Increment click counters
    await supabase.rpc('increment_content_clicks', { p_content_id: content_id })

    // Get redirect URL
    const { data: content, error: contentError } = await supabase
      .from('content_item')
      .select('content_url')
      .eq('id', content_id)
      .single()

    if (contentError || !content) {
      throw new Error('Content not found')
    }

    return new Response(
      JSON.stringify({
        success: true,
        redirect_url: content.content_url,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Error in track-click:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'TRACK_CLICK_ERROR',
        message: error instanceof Error ? error.message : 'Failed to track click',
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
