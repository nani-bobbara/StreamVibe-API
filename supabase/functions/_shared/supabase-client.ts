import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

let _supabaseClient: SupabaseClient | null = null

export function getSupabaseClient(authToken?: string): SupabaseClient {
  if (_supabaseClient) {
    return _supabaseClient
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') // Use service role for Edge Functions

  if (!supabaseUrl || !supabaseKey) {
    throw new Error('Missing Supabase environment variables')
  }

  _supabaseClient = createClient(supabaseUrl, supabaseKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    global: {
      headers: authToken ? { Authorization: `Bearer ${authToken}` } : {},
    },
  })

  return _supabaseClient
}

export async function getAuthenticatedUser(req: Request, supabase: SupabaseClient) {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    throw new Error('Missing authorization header')
  }

  const token = authHeader.replace('Bearer ', '')
  const { data: { user }, error } = await supabase.auth.getUser(token)

  if (error || !user) {
    throw new Error('Invalid or expired token')
  }

  return user
}
