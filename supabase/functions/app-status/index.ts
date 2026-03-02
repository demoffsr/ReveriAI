import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { supabaseAdmin } from "../_shared/auth.ts"

// --- Config ---
const THRESHOLDS = {
  green:  { errors_1h: 5,  affected_users_1h: 3  },
  yellow: { errors_1h: 20, affected_users_1h: 10 },
}

const CATEGORY_LABELS: Record<string, { label: string, icon: string }> = {
  aiService:    { label: 'AI Services',        icon: '\u2728' },
  audio:        { label: 'Audio',              icon: '\uD83C\uDFA4' },
  speech:       { label: 'Speech Recognition', icon: '\uD83D\uDDE3' },
  data:         { label: 'Data Storage',       icon: '\uD83D\uDCBE' },
  network:      { label: 'Network',            icon: '\uD83C\uDF10' },
  liveActivity: { label: 'Live Activity',      icon: '\uD83D\uDFE2' },
}

const ALL_CATEGORIES = ['aiService', 'audio', 'speech', 'data', 'network', 'liveActivity']

interface WindowData {
  total: number
  affected_users: number
  by_category: Record<string, number>
}

// --- Crypto helpers (Web Crypto API) ---
const encoder = new TextEncoder()

async function sha256(input: string): Promise<string> {
  const data = encoder.encode(input)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('')
}

async function getHmacKey(): Promise<CryptoKey> {
  const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || 'fallback-key'
  return crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify'])
}

function base64url(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function base64urlDecode(str: string): Uint8Array {
  const padded = str.replace(/-/g, '+').replace(/_/g, '/') + '=='.slice(0, (4 - str.length % 4) % 4)
  const binary = atob(padded)
  return Uint8Array.from(binary, c => c.charCodeAt(0))
}

async function createToken(sub: string, ttlHours: number = 24): Promise<string> {
  const payload = { sub, exp: Math.floor(Date.now() / 1000) + ttlHours * 3600 }
  const payloadBytes = encoder.encode(JSON.stringify(payload))
  const payloadB64 = base64url(payloadBytes)

  const key = await getHmacKey()
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(payloadB64))
  const sigB64 = base64url(new Uint8Array(sig))

  return `${payloadB64}.${sigB64}`
}

async function validateToken(token: string): Promise<{ valid: boolean, sub?: string }> {
  try {
    const [payloadB64, sigB64] = token.split('.')
    if (!payloadB64 || !sigB64) return { valid: false }

    const key = await getHmacKey()
    const valid = await crypto.subtle.verify('HMAC', key, base64urlDecode(sigB64), encoder.encode(payloadB64))
    if (!valid) return { valid: false }

    const payload = JSON.parse(new TextDecoder().decode(base64urlDecode(payloadB64)))
    if (payload.exp < Math.floor(Date.now() / 1000)) return { valid: false }

    return { valid: true, sub: payload.sub }
  } catch {
    return { valid: false }
  }
}

async function isAdminRequest(req: Request): Promise<boolean> {
  const auth = req.headers.get('Authorization')
  if (!auth?.startsWith('Bearer ')) return false
  const result = await validateToken(auth.slice(7))
  return result.valid && result.sub === 'admin'
}

// --- Status logic ---
function getStatus(h1: WindowData): string {
  if (h1.total > THRESHOLDS.yellow.errors_1h ||
      h1.affected_users > THRESHOLDS.yellow.affected_users_1h) return 'red'
  if (h1.total > THRESHOLDS.green.errors_1h ||
      h1.affected_users > THRESHOLDS.green.affected_users_1h) return 'yellow'
  return 'green'
}

function getCategoryStatus(count: number): string {
  if (count === 0) return 'ok'
  if (count <= 3) return 'warn'
  return 'error'
}

// --- Main handler ---
Deno.serve(async (req) => {
  const corsHeaders: Record<string, string> = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': '*',
  }

  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  const jsonHeaders = { 'Content-Type': 'application/json', ...corsHeaders, 'Cache-Control': 'public, max-age=30' }

  try {
    const url = new URL(req.url)

    // ========================
    // POST — Admin login
    // ========================
    if (req.method === 'POST') {
      const body = await req.json()
      const { user, password } = body

      if (!user || !password) {
        return new Response(JSON.stringify({ error: 'Missing credentials' }), { status: 400, headers: jsonHeaders })
      }

      const expectedUser = Deno.env.get('DASHBOARD_ADMIN_USER')
      const expectedHash = Deno.env.get('DASHBOARD_ADMIN_PASS_HASH')

      if (!expectedUser || !expectedHash) {
        console.error('[app-status] Admin secrets not configured')
        return new Response(JSON.stringify({ error: 'Auth not configured' }), { status: 500, headers: jsonHeaders })
      }

      const inputHash = await sha256(password)

      if (user !== expectedUser || inputHash !== expectedHash) {
        return new Response(JSON.stringify({ error: 'Invalid credentials' }), { status: 401, headers: jsonHeaders })
      }

      const token = await createToken('admin', 24)
      return new Response(JSON.stringify({ token, expires_in: 86400 }), { headers: { ...jsonHeaders, 'Cache-Control': 'no-store' } })
    }

    // ========================
    // GET — data endpoints
    // ========================
    if (req.method !== 'GET') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: jsonHeaders })
    }

    const view = url.searchParams.get('view')

    // --- Admin-only detail views ---
    if (view) {
      const isAdmin = await isAdminRequest(req)
      if (!isAdmin) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...jsonHeaders, 'Cache-Control': 'no-store' } })
      }

      const hours = parseInt(url.searchParams.get('hours') || '24')
      const category = url.searchParams.get('category') || null
      const code = url.searchParams.get('code') || null

      let rpcName: string
      let rpcParams: Record<string, unknown>

      switch (view) {
        case 'timeline':
          rpcName = 'error_timeline'
          rpcParams = { p_hours: hours, p_category: category, p_error_code: code }
          break
        case 'details':
          rpcName = 'error_details'
          rpcParams = {
            p_hours: hours, p_category: category, p_error_code: code,
            p_limit: parseInt(url.searchParams.get('limit') || '50'),
            p_offset: parseInt(url.searchParams.get('offset') || '0'),
          }
          break
        case 'devices':
          rpcName = 'error_device_breakdown'
          rpcParams = { p_hours: hours, p_category: category, p_error_code: code }
          break
        case 'trends':
          rpcName = 'error_trends'
          rpcParams = { p_category: category, p_error_code: code }
          break

        // --- Analytics views ---
        case 'analytics_summary':
          rpcName = 'analytics_summary'
          rpcParams = {}
          break
        case 'analytics_dau':
          rpcName = 'analytics_dau_mau'
          rpcParams = { p_days: parseInt(url.searchParams.get('days') || '30') }
          break
        case 'analytics_retention':
          rpcName = 'analytics_retention'
          rpcParams = {
            p_cohort_start: url.searchParams.get('cohort_start') || null,
            p_days: parseInt(url.searchParams.get('days') || '30'),
          }
          break
        case 'analytics_features':
          rpcName = 'analytics_feature_usage'
          rpcParams = { p_hours: hours }
          break
        case 'analytics_content':
          rpcName = 'analytics_content_metrics'
          rpcParams = { p_hours: hours }
          break
        case 'analytics_sessions':
          rpcName = 'analytics_session_stats'
          rpcParams = { p_hours: hours }
          break
        case 'analytics_timeline':
          rpcName = 'analytics_timeline'
          rpcParams = {
            p_hours: hours,
            p_event_type: url.searchParams.get('event_type') || null,
          }
          break

        // --- Flow analysis views ---
        case 'analytics_session_list':
          rpcName = 'analytics_session_list'
          rpcParams = {
            p_hours: hours,
            p_limit: parseInt(url.searchParams.get('limit') || '50'),
            p_offset: parseInt(url.searchParams.get('offset') || '0'),
          }
          break
        case 'analytics_user_flow':
          rpcName = 'analytics_user_flow'
          rpcParams = {
            p_session_id: url.searchParams.get('session_id') || '',
          }
          break
        case 'analytics_funnel': {
          const stepsParam = url.searchParams.get('steps') || ''
          rpcName = 'analytics_funnel'
          rpcParams = {
            p_steps: stepsParam.split(',').filter(Boolean),
            p_hours: hours,
          }
          break
        }
        case 'analytics_transitions':
          rpcName = 'analytics_flow_transitions'
          rpcParams = {
            p_hours: hours,
            p_limit: parseInt(url.searchParams.get('limit') || '50'),
          }
          break
        case 'analytics_screen_time':
          rpcName = 'analytics_screen_time'
          rpcParams = { p_hours: hours }
          break

        // --- Analytics V2 views ---
        case 'analytics_heatmap':
          rpcName = 'analytics_activity_heatmap'
          rpcParams = { p_days: parseInt(url.searchParams.get('days') || '30') }
          break
        case 'analytics_retention_action':
          rpcName = 'analytics_retention_by_action'
          rpcParams = {
            p_action: url.searchParams.get('action') || 'dream_recorded',
            p_threshold: parseInt(url.searchParams.get('threshold') || '3'),
            p_days: parseInt(url.searchParams.get('days') || '30'),
          }
          break
        case 'analytics_ai_perf':
          rpcName = 'analytics_ai_performance'
          rpcParams = { p_hours: hours }
          break
        case 'analytics_reminders':
          rpcName = 'analytics_reminder_stats'
          rpcParams = { p_days: parseInt(url.searchParams.get('days') || '30') }
          break
        case 'analytics_dreams':
          rpcName = 'analytics_dream_stats'
          rpcParams = { p_hours: hours }
          break
        case 'analytics_live':
          rpcName = 'analytics_live_events'
          rpcParams = { p_limit: parseInt(url.searchParams.get('limit') || '50') }
          break

        // --- Per-user analytics views ---
        case 'analytics_user_list':
          rpcName = 'analytics_user_list'
          rpcParams = {
            p_days: parseInt(url.searchParams.get('days') || '30'),
            p_limit: parseInt(url.searchParams.get('limit') || '50'),
            p_offset: parseInt(url.searchParams.get('offset') || '0'),
          }
          break
        case 'analytics_user_profile':
          rpcName = 'analytics_user_profile'
          rpcParams = { p_user_id: url.searchParams.get('user_id') || '' }
          break
        case 'analytics_user_events':
          rpcName = 'analytics_user_events'
          rpcParams = {
            p_user_id: url.searchParams.get('user_id') || '',
            p_hours: hours,
            p_limit: parseInt(url.searchParams.get('limit') || '50'),
            p_offset: parseInt(url.searchParams.get('offset') || '0'),
          }
          break

        // --- Cost analytics ---
        case 'analytics_costs':
          rpcName = 'analytics_user_costs'
          rpcParams = {
            p_user_id: url.searchParams.get('user_id') || null,
            p_days: parseInt(url.searchParams.get('days') || '30'),
          }
          break

        default:
          return new Response(JSON.stringify({ error: 'Unknown view' }), { status: 400, headers: jsonHeaders })
      }

      console.log(`[app-status] RPC ${rpcName} params:`, JSON.stringify(rpcParams))
      const { data, error } = await supabaseAdmin.rpc(rpcName, rpcParams)
      if (error) {
        console.error(`[app-status] RPC ${rpcName} failed:`, error.message, error.details, error.hint, error.code)
        return new Response(JSON.stringify({ error: 'Query failed', detail: error.message, hint: error.hint }), { status: 500, headers: jsonHeaders })
      }
      return new Response(JSON.stringify(data, null, 2), { headers: jsonHeaders })
    }

    // --- Health summary (public + admin) ---
    const { data, error } = await supabaseAdmin.rpc('error_health_summary')

    if (error) {
      console.error('[app-status] RPC failed:', error.message)
      return new Response(JSON.stringify({ error: 'DB query failed' }), { status: 500, headers: jsonHeaders })
    }

    const h1: WindowData = data?.windows?.['1h'] || { total: 0, affected_users: 0, by_category: {} }
    const status = getStatus(h1)
    const checkedAt = new Date().toISOString()

    const isAdmin = await isAdminRequest(req)

    if (isAdmin) {
      // Full data for admin
      const emoji: Record<string, string> = { green: '\u2705', yellow: '\u26A0\uFE0F', red: '\u274C' }
      return new Response(JSON.stringify({
        status, emoji: emoji[status], summary: data, checked_at: checkedAt,
      }, null, 2), { headers: jsonHeaders })
    }

    // Public: only status + category health (no counts)
    const statusLabels: Record<string, string> = {
      green: 'All Systems Operational',
      yellow: 'Degraded Performance',
      red: 'Major Issues Detected',
    }

    const categories: Record<string, { status: string, label: string, icon: string }> = {}
    for (const cat of ALL_CATEGORIES) {
      const count1h = h1.by_category?.[cat] || 0
      const info = CATEGORY_LABELS[cat] || { label: cat, icon: '\u2753' }
      categories[cat] = {
        status: getCategoryStatus(count1h),
        label: info.label,
        icon: info.icon,
      }
    }

    return new Response(JSON.stringify({
      status,
      label: statusLabels[status],
      categories,
      checked_at: checkedAt,
    }, null, 2), { headers: jsonHeaders })

  } catch (err) {
    console.error('[app-status] Error:', err)
    return new Response(JSON.stringify({ error: 'Internal error' }), { status: 500, headers: jsonHeaders })
  }
})
