import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { supabaseAdmin } from "../_shared/auth.ts"
import { validateAnalyticsToken, touchDevice } from "../_shared/analytics-auth.ts"

// Allowed event types (whitelist to prevent garbage data)
const ALLOWED_EVENTS = new Set([
  // Session
  'session_start',
  'app_foreground',
  'app_background',

  // Recording
  'record_started',
  'record_stopped',
  'record_paused',
  'record_resumed',
  'record_deleted',
  'mode_switched',

  // Dream saving
  'dream_recorded',
  'review_saved_audio',

  // Emotions
  'emotions_selected',
  'emotion_filter_changed',

  // AI features
  'ai_title_started',
  'ai_title_completed',
  'ai_title_failed',
  'ai_image_started',
  'ai_image_completed',
  'ai_image_failed',
  'ai_interpretation_started',
  'ai_interpretation_completed',
  'ai_interpretation_failed',
  'ai_transcription_started',
  'ai_transcription_completed',
  'ai_transcription_failed',
  'ai_title_regenerated',

  // Navigation
  'tab_switched',
  'deep_link_record',
  'deep_link_write',
  'dream_detail_opened',
  'dream_detail_tab_switched',
  'profile_opened',
  'search_opened',
  'search_result_tapped',

  // Reminder
  'reminder_started',
  'reminder_ended',

  // Journal actions
  'folder_created',
  'folder_deleted',
  'folder_opened',
  'dream_moved_to_folder',
  'dream_deleted',
  'dream_shared',
  'dream_edited',
  'dream_emotions_changed',
  'time_range_changed',
  'journal_tab_switched',

  // Playback
  'audio_playback_started',
  'audio_playback_skip',

  // Profile settings
  'language_changed',
  'reminder_toggled',
  'reminder_time_changed',
  'theme_changed',
  'cache_cleared',
  'rate_app_tapped',
  'contact_us_tapped',
])

interface EventPayload {
  event_type: string
  session_id: string
  user_id?: string
  metadata?: Record<string, unknown>
  device?: string
  app_version?: string
  os_version?: string
  locale?: string
  created_at?: string
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
    const body = await req.json()

    // Support both single event and batch
    const events: EventPayload[] = Array.isArray(body.events) ? body.events : [body]

    if (events.length === 0) {
      return new Response(JSON.stringify({ error: 'No events' }), { status: 400, headers: jsonHeaders })
    }

    if (events.length > 50) {
      return new Response(JSON.stringify({ error: 'Too many events (max 50)' }), { status: 400, headers: jsonHeaders })
    }

    // --- Authentication ---
    const requireAuth = Deno.env.get('REQUIRE_AUTH') !== 'false'
    let isVerified = false
    let verifiedUserId: string | null = null

    if (requireAuth) {
      const token = req.headers.get('X-Analytics-Token')

      if (token) {
        const result = await validateAnalyticsToken(token)
        if (!result.valid) {
          return new Response(
            JSON.stringify({ error: 'Invalid analytics token' }),
            { status: 401, headers: jsonHeaders },
          )
        }
        isVerified = true
        verifiedUserId = result.userId
        // Fire-and-forget last_seen_at update
        touchDevice(result.userId)
      } else {
        // No token — check grace period (fail-closed)
        const gracePeriodEnd = Deno.env.get('GRACE_PERIOD_END')
        if (!gracePeriodEnd) {
          // No grace period configured → fail closed
          return new Response(
            JSON.stringify({ error: 'Authentication required' }),
            { status: 401, headers: jsonHeaders },
          )
        }
        const deadline = new Date(gracePeriodEnd)
        if (isNaN(deadline.getTime()) || Date.now() > deadline.getTime()) {
          // Invalid date OR past deadline → fail closed
          return new Response(
            JSON.stringify({ error: 'Authentication required' }),
            { status: 401, headers: jsonHeaders },
          )
        }
        // Valid date, before deadline → accept as unverified
      }
    }

    // Validate and build rows
    const rows = []
    for (const evt of events) {
      if (!evt.event_type || !evt.session_id) {
        continue // skip malformed events silently
      }
      if (!ALLOWED_EVENTS.has(evt.event_type)) {
        console.warn(`[track-event] Unknown event type: ${evt.event_type}`)
        continue
      }

      // Server-side user_id: use verified ID from token, ignore client-provided
      const userId = isVerified
        ? verifiedUserId!
        : (evt.user_id || '00000000-0000-0000-0000-000000000000')

      // Flag unverified events in metadata
      let metadata = evt.metadata || null
      if (!isVerified) {
        metadata = { ...(metadata || {}), _unverified: true }
      }

      rows.push({
        user_id: userId,
        event_type: evt.event_type,
        session_id: evt.session_id,
        metadata,
        device: evt.device || null,
        app_version: evt.app_version || '1.0',
        os_version: evt.os_version || 'unknown',
        locale: evt.locale || 'unknown',
        created_at: evt.created_at || new Date().toISOString(),
      })
    }

    if (rows.length === 0) {
      return new Response(JSON.stringify({ error: 'No valid events' }), { status: 400, headers: jsonHeaders })
    }

    const { error } = await supabaseAdmin
      .from('app_events')
      .insert(rows)

    if (error) {
      console.error('[track-event] Insert failed:', error.message, error.details, error.hint)
      return new Response(JSON.stringify({ error: 'Insert failed', details: error.message }), { status: 500, headers: jsonHeaders })
    }

    return new Response(JSON.stringify({ ok: true, count: rows.length }), { headers: jsonHeaders })

  } catch (err) {
    console.error('[track-event] Error:', err)
    return new Response(JSON.stringify({ error: 'Internal error' }), { status: 500, headers: jsonHeaders })
  }
})
