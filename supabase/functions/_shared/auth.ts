import { createClient } from "jsr:@supabase/supabase-js@2"

export interface AuthResult {
  userId: string
}

// One client at cold start, reused across warm invocations
export const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

export function isAuthError(result: Response | AuthResult): result is Response {
  return result instanceof Response
}

export async function validateAuth(req: Request, corsHeaders: Record<string, string>): Promise<Response | AuthResult> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing authorization' }), { status: 401, headers: corsHeaders })
  }

  const token = authHeader.replace('Bearer ', '')
  const { data, error } = await supabaseAdmin.auth.getUser(token)

  if (error || !data.user) {
    return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401, headers: corsHeaders })
  }

  return { userId: data.user.id }
}
