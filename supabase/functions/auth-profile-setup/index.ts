import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { getSupabaseClient, getAuthenticatedUser } from '../_shared/supabase-client.ts'
import type { ProfileSetupRequest, ProfileSetupResponse, ErrorResponse } from '../_shared/types.ts'

console.log('Profile setup function started')

serve(async (req) => {
  // Handle CORS
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // Get Supabase client
    const supabase = getSupabaseClient()

    // Authenticate user
    const user = await getAuthenticatedUser(req, supabase)

    // Parse request body
    const body: ProfileSetupRequest = await req.json()

    // Validate required fields
    if (!body.display_name || body.display_name.trim().length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: 'INVALID_INPUT',
            message: 'display_name is required',
          },
        } as ErrorResponse),
        { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Generate profile slug
    const { data: slugData, error: slugError } = await supabase.rpc(
      'generate_profile_slug',
      {
        p_display_name: body.display_name,
        p_user_id: user.id,
      }
    )

    if (slugError) {
      console.error('Error generating slug:', slugError)
      throw new Error('Failed to generate profile slug')
    }

    const profileSlug = slugData as string

    // Update user profile
    const { data: userData, error: updateError } = await supabase
      .from('users')
      .update({
        display_name: body.display_name,
        bio: body.bio || null,
        avatar_url: body.avatar_url || null,
        website_url: body.website_url || null,
        location: body.location || null,
        primary_category: body.primary_category || null,
        profile_slug: profileSlug,
        is_public: true,
        updated_at: new Date().toISOString(),
      })
      .eq('id', user.id)
      .select()
      .single()

    if (updateError) {
      console.error('Error updating profile:', updateError)
      throw new Error('Failed to update profile')
    }

    // Generate profile URL
    const baseUrl = Deno.env.get('APP_BASE_URL') || 'https://streamvibe.com'
    const profileUrl = `${baseUrl}/c/${profileSlug}`

    // Return success response
    const response: ProfileSetupResponse = {
      success: true,
      profile: {
        user_id: user.id,
        display_name: body.display_name,
        profile_slug: profileSlug,
        profile_url: profileUrl,
      },
    }

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Error in profile-setup:', error)

    const errorResponse: ErrorResponse = {
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: error instanceof Error ? error.message : 'An unknown error occurred',
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
