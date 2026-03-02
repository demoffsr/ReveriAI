import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { supabaseAdmin, validateAuth, isAuthError } from "../_shared/auth.ts"

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
    // Authenticate user via Supabase JWT
    const authResult = await validateAuth(req, jsonHeaders)
    if (isAuthError(authResult)) return authResult
    const userId = authResult.userId

    const body = await req.json()

    // Support both single event and batch
    const events: EventPayload[] = Array.isArray(body.events) ? body.events : [body]

    if (events.length === 0) {
      return new Response(JSON.stringify({ error: 'No events' }), { status: 400, headers: jsonHeaders })
    }

    if (events.length > 50) {
      return new Response(JSON.stringify({ error: 'Too many events (max 50)' }), { status: 400, headers: jsonHeaders })
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
      rows.push({
        user_id: userId,
        event_type: evt.event_type,
        session_id: evt.session_id,
        metadata: evt.metadata || null,
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
      console.error('[track-event] Insert failed:', error.message)
      return new Response(JSON.stringify({ error: 'Insert failed' }), { status: 500, headers: jsonHeaders })
    }

    return new Response(JSON.stringify({ ok: true, count: rows.length }), { headers: jsonHeaders })

  } catch (err) {
    console.error('[track-event] Error:', err)
    return new Response(JSON.stringify({ error: 'Internal error' }), { status: 500, headers: jsonHeaders })
  }
})
