import { supabaseAdmin } from "./auth.ts"

// Functions considered "expensive" (image generation, interpretation, transcription)
const EXPENSIVE_FUNCTIONS = new Set([
  'generate-dream-image',
  'generate-dream-interpretation',
  'transcribe-audio',
])

// Per-user rate limits
const USER_LIMITS: Record<string, { duration_seconds: number; max_requests: number }[]> = {
  'generate-dream-image':          [{ duration_seconds: 60, max_requests: 2 },  { duration_seconds: 3600, max_requests: 8 },  { duration_seconds: 86400, max_requests: 30 }],
  'transcribe-audio':              [{ duration_seconds: 60, max_requests: 3 },  { duration_seconds: 3600, max_requests: 15 }, { duration_seconds: 86400, max_requests: 50 }],
  'generate-dream-interpretation': [{ duration_seconds: 60, max_requests: 3 },  { duration_seconds: 3600, max_requests: 15 }, { duration_seconds: 86400, max_requests: 50 }],
  'generate-dream-questions':      [{ duration_seconds: 60, max_requests: 3 },  { duration_seconds: 3600, max_requests: 15 }, { duration_seconds: 86400, max_requests: 50 }],
  'generate-dream-title':          [{ duration_seconds: 60, max_requests: 5 },  { duration_seconds: 3600, max_requests: 20 }, { duration_seconds: 86400, max_requests: 100 }],
  'delete-dream-image':            [{ duration_seconds: 60, max_requests: 10 }, { duration_seconds: 3600, max_requests: 30 }],
}

// Per-IP rate limits (higher due to NAT/VPN)
const IP_LIMITS: Record<string, { duration_seconds: number; max_requests: number }[]> = {
  'generate-dream-image':          [{ duration_seconds: 60, max_requests: 5 },  { duration_seconds: 3600, max_requests: 20 }],
  'transcribe-audio':              [{ duration_seconds: 60, max_requests: 10 }, { duration_seconds: 3600, max_requests: 40 }],
  'generate-dream-interpretation': [{ duration_seconds: 60, max_requests: 10 }, { duration_seconds: 3600, max_requests: 40 }],
  'generate-dream-questions':      [{ duration_seconds: 60, max_requests: 10 }, { duration_seconds: 3600, max_requests: 40 }],
  'generate-dream-title':          [{ duration_seconds: 60, max_requests: 15 }, { duration_seconds: 3600, max_requests: 60 }],
  'delete-dream-image':            [{ duration_seconds: 60, max_requests: 10 }, { duration_seconds: 3600, max_requests: 30 }],
}

function getClientIP(req: Request): string {
  const forwarded = req.headers.get('x-forwarded-for')
  if (forwarded) {
    // x-forwarded-for can contain multiple IPs: client, proxy1, proxy2
    return forwarded.split(',')[0].trim()
  }
  return req.headers.get('x-real-ip') || 'unknown'
}

interface RateLimitResult {
  window_duration_seconds: number
  current_count: number
  max_requests: number
  is_exceeded: boolean
}

type CheckResult =
  | { kind: 'ok' }
  | { kind: 'exceeded'; result: RateLimitResult }
  | { kind: 'unavailable' }

async function checkIdentifierLimits(
  identifier: string,
  functionName: string,
  windows: { duration_seconds: number; max_requests: number }[],
): Promise<CheckResult> {
  try {
    const { data, error } = await supabaseAdmin.rpc('check_rate_limits', {
      p_identifier: identifier,
      p_function_name: functionName,
      p_windows: windows,
    })

    if (error) {
      console.error(`Rate limit RPC error for ${identifier}: ${error.message}`)
      return { kind: 'unavailable' }
    }

    const exceeded = (data as RateLimitResult[])?.find((r) => r.is_exceeded)
    return exceeded ? { kind: 'exceeded', result: exceeded } : { kind: 'ok' }
  } catch (err) {
    console.error(`Rate limit check failed for ${identifier}: ${err}`)
    return { kind: 'unavailable' }
  }
}

function windowLabel(seconds: number): string {
  if (seconds <= 60) return 'minute'
  if (seconds <= 3600) return 'hour'
  return 'day'
}

export async function checkRateLimit(
  userId: string,
  functionName: string,
  req: Request,
  corsHeaders: Record<string, string>,
): Promise<Response | null> {
  // Kill switch: immediately reject expensive functions
  const killSwitch = Deno.env.get('RATE_LIMIT_KILL_SWITCH')
  if (killSwitch === 'true' && EXPENSIVE_FUNCTIONS.has(functionName)) {
    console.warn(`[KILL_SWITCH] Rejected ${functionName} for user ${userId}`)
    return new Response(
      JSON.stringify({ error: 'Service temporarily unavailable' }),
      { status: 503, headers: corsHeaders },
    )
  }

  const userWindows = USER_LIMITS[functionName]
  const ipWindows = IP_LIMITS[functionName]
  if (!userWindows && !ipWindows) return null // no limits configured

  // Check per-user limits
  if (userWindows) {
    const userCheck = await checkIdentifierLimits(userId, functionName, userWindows)
    if (userCheck.kind === 'exceeded') {
      const retryAfter = userCheck.result.window_duration_seconds
      const window = windowLabel(userCheck.result.window_duration_seconds)
      console.warn(
        `[RATE_LIMIT] User ${userId} exceeded ${functionName} limit: ${userCheck.result.current_count}/${userCheck.result.max_requests} per ${window}`,
      )
      return new Response(
        JSON.stringify({
          error: `Rate limit exceeded. Try again later.`,
          retryAfter,
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            'Retry-After': String(retryAfter),
            'X-RateLimit-Limit': String(userCheck.result.max_requests),
            'X-RateLimit-Remaining': '0',
          },
        },
      )
    }
    if (userCheck.kind === 'unavailable' && EXPENSIVE_FUNCTIONS.has(functionName)) {
      console.warn(`[RATE_LIMIT_FAIL_CLOSED] DB unavailable, blocking ${functionName} for user ${userId}`)
      return new Response(
        JSON.stringify({ error: 'Service temporarily unavailable' }),
        { status: 503, headers: { ...corsHeaders, 'Retry-After': '60' } },
      )
    }
  }

  // Check per-IP limits
  const clientIP = getClientIP(req)
  if (ipWindows && clientIP !== 'unknown') {
    const ipIdentifier = `ip:${clientIP}`
    const ipCheck = await checkIdentifierLimits(ipIdentifier, functionName, ipWindows)
    if (ipCheck.kind === 'exceeded') {
      const retryAfter = ipCheck.result.window_duration_seconds
      const window = windowLabel(ipCheck.result.window_duration_seconds)
      console.warn(
        `[RATE_LIMIT] IP ${clientIP} exceeded ${functionName} limit: ${ipCheck.result.current_count}/${ipCheck.result.max_requests} per ${window}`,
      )
      return new Response(
        JSON.stringify({
          error: `Rate limit exceeded. Try again later.`,
          retryAfter,
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            'Retry-After': String(retryAfter),
            'X-RateLimit-Limit': String(ipCheck.result.max_requests),
            'X-RateLimit-Remaining': '0',
          },
        },
      )
    }
    if (ipCheck.kind === 'unavailable' && EXPENSIVE_FUNCTIONS.has(functionName)) {
      console.warn(`[RATE_LIMIT_FAIL_CLOSED] DB unavailable, blocking ${functionName} for IP ${clientIP}`)
      return new Response(
        JSON.stringify({ error: 'Service temporarily unavailable' }),
        { status: 503, headers: { ...corsHeaders, 'Retry-After': '60' } },
      )
    }
  }

  // Probabilistic cleanup (1% of requests) as fallback to pg_cron
  if (Math.random() < 0.01) {
    supabaseAdmin.rpc('cleanup_rate_limits').then(() => {}).catch(() => {})
  }

  return null
}
