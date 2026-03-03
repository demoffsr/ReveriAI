import { supabaseAdmin } from "./auth.ts"

// --- Token generation (256 bits of entropy) ---
export function generateToken(): string {
  const bytes = new Uint8Array(32)
  crypto.getRandomValues(bytes)
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('')
}

// --- Token hashing for DB storage (SHA-256 → hex) ---
export async function hashToken(token: string): Promise<string> {
  const data = new TextEncoder().encode(token)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('')
}

// --- IP hashing with HMAC (NOT raw SHA-256 — rainbow table resistant) ---
export async function hashIP(ip: string): Promise<string> {
  const secret = Deno.env.get('ANALYTICS_SECRET')
  if (!secret) {
    console.error('[analytics-auth] ANALYTICS_SECRET not set')
    return 'no-secret'
  }
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(ip))
  return Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('')
}

// --- DB-based token validation (server extracts user_id — ignores client-provided) ---
export async function validateAnalyticsToken(
  token: string,
): Promise<{ valid: true; userId: string } | { valid: false }> {
  try {
    const tokenHash = await hashToken(token)
    const { data, error } = await supabaseAdmin
      .from('analytics_devices')
      .select('user_id')
      .eq('token_hash', tokenHash)
      .single()

    if (error || !data) return { valid: false }
    return { valid: true, userId: data.user_id }
  } catch {
    return { valid: false }
  }
}

// --- API key validation (constant-time, dual-key for rotation) ---
export function validateAPIKey(
  req: Request,
  corsHeaders: Record<string, string>,
): Response | null {
  const provided = req.headers.get('X-Analytics-API-Key')
  if (!provided) {
    return new Response(
      JSON.stringify({ error: 'Missing API key' }),
      { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } },
    )
  }

  const current = Deno.env.get('ANALYTICS_API_KEY') ?? ''
  const prev = Deno.env.get('ANALYTICS_API_KEY_PREV') ?? ''

  if (timingSafeEqual(provided, current)) return null
  if (prev && timingSafeEqual(provided, prev)) return null

  return new Response(
    JSON.stringify({ error: 'Invalid API key' }),
    { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } },
  )
}

// --- last_seen_at update (fire-and-forget, throttled to 1h) ---
export function touchDevice(userId: string): void {
  supabaseAdmin
    .from('analytics_devices')
    .update({ last_seen_at: new Date().toISOString() })
    .eq('user_id', userId)
    .lt('last_seen_at', new Date(Date.now() - 3600_000).toISOString())
    .then(() => {})
    .catch(() => {})
}

// --- Constant-time string comparison ---
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) {
    // Still do work to avoid length-based timing leak
    const dummy = new Uint8Array(32)
    const dummyB = new Uint8Array(32)
    crypto.getRandomValues(dummy)
    crypto.getRandomValues(dummyB)
    let xor = 0
    for (let i = 0; i < 32; i++) xor |= dummy[i] ^ dummyB[i]
    return false
  }
  const encoder = new TextEncoder()
  const bufA = encoder.encode(a)
  const bufB = encoder.encode(b)
  let xor = 0
  for (let i = 0; i < bufA.length; i++) {
    xor |= bufA[i] ^ bufB[i]
  }
  return xor === 0
}
