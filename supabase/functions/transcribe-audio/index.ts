import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  'Content-Type': 'application/json',
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing authorization' }), { status: 401, headers: corsHeaders })
  }

  const contentType = req.headers.get('Content-Type') || ''

  // Support both multipart/form-data and raw binary with locale in header
  let audioData: Uint8Array
  let locale: string

  if (contentType.includes('multipart/form-data')) {
    const formData = await req.formData()
    const file = formData.get('file')
    locale = (formData.get('locale') as string) || 'en-US'

    if (!file || !(file instanceof File)) {
      return new Response(JSON.stringify({ error: 'Missing audio file' }), { status: 400, headers: corsHeaders })
    }

    audioData = new Uint8Array(await file.arrayBuffer())
  } else {
    // Raw binary body, locale from header
    locale = req.headers.get('X-Locale') || 'en-US'
    audioData = new Uint8Array(await req.arrayBuffer())
  }

  if (audioData.length === 0) {
    return new Response(JSON.stringify({ error: 'Empty audio data' }), { status: 400, headers: corsHeaders })
  }

  const openaiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiKey) {
    return new Response(JSON.stringify({ error: 'OpenAI key not configured' }), { status: 500, headers: corsHeaders })
  }

  const language = locale.substring(0, 2).toLowerCase()
  const isRussian = language === 'ru'
  const prompt = isRussian
    ? 'Это запись сна, рассказанная утром после пробуждения.'
    : 'This is a dream recording narrated in the morning after waking up.'

  // Build multipart form for OpenAI Whisper API
  const formData = new FormData()
  formData.append('file', new Blob([audioData], { type: 'audio/mp4' }), 'recording.m4a')
  formData.append('model', 'whisper-1')
  formData.append('language', language)
  formData.append('response_format', 'text')
  formData.append('prompt', prompt)

  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
    },
    body: formData,
  })

  if (!response.ok) {
    const error = await response.text()
    return new Response(JSON.stringify({ error: `Whisper error: ${error}` }), { status: 502, headers: corsHeaders })
  }

  // response_format=text returns plain text, not JSON
  const transcript = (await response.text()).trim()

  return new Response(JSON.stringify({ transcript }), { headers: corsHeaders })
})
