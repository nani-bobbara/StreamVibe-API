import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'
import type { ErrorResponse } from '../_shared/types.ts'

console.log('AI tag generation function started')

interface AITagRequest {
  content_id: string
  regenerate?: boolean // Force regenerate even if tags exist
}

interface AITagResponse {
  success: boolean
  content_id: string
  tags_generated: number
  seo_updated: boolean
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = getSupabaseClient()
    const user = await getAuthenticatedUser(req, supabase)

    const body: AITagRequest = await req.json()

    if (!body.content_id) {
      throw new Error('content_id is required')
    }

    // Get content item
    const { data: content, error: contentError } = await supabase
      .from('content_item')
      .select('*')
      .eq('id', body.content_id)
      .eq('user_id', user.id)
      .single()

    if (contentError || !content) {
      throw new Error('Content not found or access denied')
    }

    // Check if AI tags already exist (unless regenerate flag is set)
    if (!body.regenerate) {
      const { data: existingTags } = await supabase
        .from('content_tag')
        .select('id')
        .eq('content_id', content.id)
        .eq('source', 'ai_generated')
        .limit(1)

      if (existingTags && existingTags.length > 0) {
        throw new Error('AI tags already generated. Use regenerate=true to force regeneration')
      }
    }

    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiKey) {
      throw new Error('OpenAI API key not configured')
    }

    // Prepare prompt for GPT-4
    const prompt = `Analyze this content and generate SEO-optimized tags and metadata:

Title: ${content.title}
Description: ${content.description || 'No description'}
Platform: ${content.content_type}

Generate a JSON response with:
1. tags: Array of 10-15 relevant keywords/tags (single words or short phrases)
2. tag_types: Map each tag to a type (keyword, topic, entity, emotion, trend)
3. confidence_scores: Confidence score for each tag (0.0-1.0)
4. seo_title: Optimized title (50-60 characters, include main keyword)
5. seo_description: Meta description (150-160 characters, compelling, include keywords)

Focus on discoverability, search intent, and relevance.`

    // Call OpenAI GPT-4
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4',
        messages: [
          {
            role: 'system',
            content: 'You are an SEO expert specializing in content tagging and metadata optimization. Always respond with valid JSON.',
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        temperature: 0.7,
        max_tokens: 1000,
        response_format: { type: 'json_object' },
      }),
    })

    if (!openaiResponse.ok) {
      const errorData = await openaiResponse.text()
      console.error('OpenAI API error:', errorData)
      throw new Error('Failed to generate AI tags')
    }

    const openaiData = await openaiResponse.json()
    const aiResult = JSON.parse(openaiData.choices[0].message.content)

    // Delete existing AI-generated tags if regenerating
    if (body.regenerate) {
      await supabase
        .from('content_tag')
        .delete()
        .eq('content_id', content.id)
        .eq('source', 'ai_generated')
    }

    // Insert AI-generated tags
    const tagInserts = aiResult.tags.map((tag: string, index: number) => ({
      content_id: content.id,
      tag: tag.toLowerCase(),
      source: 'ai_generated',
      confidence_score: aiResult.confidence_scores?.[index] || 0.85,
      tag_type: aiResult.tag_types?.[index] || 'keyword',
      created_by: user.id,
    }))

    const { error: tagError } = await supabase
      .from('content_tag')
      .insert(tagInserts)

    if (tagError) {
      console.error('Failed to insert tags:', tagError)
      throw new Error('Failed to save AI-generated tags')
    }

    // Update content with SEO metadata
    const { error: updateError } = await supabase
      .from('content_item')
      .update({
        seo_title: aiResult.seo_title,
        seo_description: aiResult.seo_description,
        ai_description: aiResult.seo_description, // Store AI description
        updated_at: new Date().toISOString(),
      })
      .eq('id', content.id)

    if (updateError) {
      console.error('Failed to update SEO metadata:', updateError)
    }

    const response: AITagResponse = {
      success: true,
      content_id: content.id,
      tags_generated: tagInserts.length,
      seo_updated: !updateError,
    }

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Error in ai-generate-tags:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'AI_GENERATION_ERROR',
        message: error instanceof Error ? error.message : 'Failed to generate AI tags',
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
