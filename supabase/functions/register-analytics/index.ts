import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { supabaseAdmin } from "../_shared/auth.ts"
import { checkRateLimit } from "../_shared/rate-limit.ts"
import { generateToken, hashToken, hashIP, validateAPIKey } from "../_shared/analytics-auth.ts"

interface RegisterBody {
  device?: string
  os_version?: string
  app_version?: string
}

function truncate(s: string | undefined, max: number): string | null {
  if (!s) return null
  return s.slice(0, max)
}

function getClientIP(req: Request): string {
  const forwarded = req.headers.get('x-forwarded-for')
  if (forwarded) return forwarded.split(',')[0].trim()
  return req.headers.get('x-real-ip') || 'unknown'
}

Deno.serve(async (req) => {
  const corsHeaders: Record<string, string> = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
  }

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  const jsonHeaders = { 'Content-Type': 'application/json', ...corsHeaders }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: jsonHeaders })
  }

  try {
    // Validate API key
    const keyError = validateAPIKey(req, corsHeaders)
    if (keyError) return keyError

    // Rate limit by IP (anti-spam — normal usage is 1 call per device lifetime)
    const rateLimitResponse = await checkRateLimit('anon', 'register-analytics', req, corsHeaders)
    if (rateLimitResponse) return rateLimitResponse

    // Parse body
    const body: RegisterBody = await req.json()

    // Generate identity
    const userId = crypto.randomUUID()
    const token = generateToken()
    const tokenHash = await hashToken(token)

    // Hash IP
    const clientIP = getClientIP(req)
    const ipHash = clientIP !== 'unknown' ? await hashIP(clientIP) : null

    // Insert device record
    const { error } = await supabaseAdmin
      .from('analytics_devices')
      .insert({
        user_id: userId,
        token_hash: tokenHash,
        device: truncate(body.device, 100),
        os_version: truncate(body.os_version, 50),
        app_version: truncate(body.app_version, 20),
        ip_hash: ipHash,
      })

    if (error) {
      console.error('[register-analytics] Insert failed:', error.message)
      return new Response(JSON.stringify({ error: 'Registration failed' }), { status: 500, headers: jsonHeaders })
    }

    console.log(`[register-analytics] New device: ${userId.slice(0, 8)}`)

    return new Response(
      JSON.stringify({ user_id: userId, token }),
      { headers: jsonHeaders },
    )
  } catch (err) {
    console.error('[register-analytics] Error:', err)
    return new Response(JSON.stringify({ error: 'Internal error' }), { status: 500, headers: jsonHeaders })
  }
})
