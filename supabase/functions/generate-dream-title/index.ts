import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { validateAuth, isAuthError } from "../_shared/auth.ts"
import { checkRateLimit } from "../_shared/rate-limit.ts"
import { validateTextSize } from "../_shared/validation.ts"

const corsHeaders = {
  'Content-Type': 'application/json',
}

Deno.serve(async (req) => {
  const requestId = crypto.randomUUID().slice(0, 8)

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed', requestId }), { status: 405, headers: corsHeaders })
    }

    const { dreamText, locale, warmup } = await req.json()

    // Warmup check BEFORE auth — warmup doesn't do anything expensive
    if (warmup) {
      return new Response(JSON.stringify({ ok: true }), { headers: corsHeaders })
    }

    const auth = await validateAuth(req, corsHeaders)
    if (isAuthError(auth)) return auth

    const rateLimitErr = await checkRateLimit(auth.userId, 'generate-dream-title', req, corsHeaders)
    if (rateLimitErr) return rateLimitErr

    if (!dreamText || dreamText.trim().length === 0) {
      return new Response(JSON.stringify({ error: 'Empty dream text', requestId }), { status: 400, headers: corsHeaders })
    }

    const textSizeErr = validateTextSize(dreamText, corsHeaders)
    if (textSizeErr) return textSizeErr

    const isRussian = (locale || '').startsWith('ru')
    const systemPrompt = isRussian
      ? `Придумай короткий заголовок сна (3-5 слов).
Правила:
- Выбери самый яркий, конкретный образ или событие из сна
- Используй конкретные существительные, не абстракции
- Заголовок должен помочь вспомнить сон через неделю
- Стиль: как название короткой сцены фильма
- Никогда не используй слова: сон, мистический, путешествие, загадочный, эфемерный, таинственный
- ТОЛЬКО заголовок, без кавычек, без точки, без пояснений`
      : `Generate a short dream title (3-5 words).
Rules:
- Pick the most vivid, specific image or event from the dream
- Use concrete nouns, not abstract concepts
- The title should help recall the dream weeks later
- Style: like a short movie scene title
- Never use words: dream, ethereal, ephemeral, mystical, journey, subconscious
- ONLY the title, no quotes, no period, no explanation`

    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiKey) {
      console.error(`[generate-dream-title][${requestId}] Missing required configuration`)
      return new Response(JSON.stringify({ error: 'Service configuration error', requestId }), { status: 500, headers: corsHeaders })
    }

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: dreamText },
        ],
        max_tokens: 25,
        temperature: 0.7,
      }),
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error(`[generate-dream-title][${requestId}] AI service error (${response.status}): ${errorText}`)
      return new Response(JSON.stringify({ error: 'AI service temporarily unavailable', requestId }), { status: 502, headers: corsHeaders })
    }

    const data = await response.json()
    let title = data.choices?.[0]?.message?.content || ''

    // Post-processing: trim, strip quotes and trailing period
    title = title.trim()
    title = title.replace(/^["«'"']+|["»'"']+$/g, '')
    title = title.replace(/\.$/, '')
    title = title.trim()

    return new Response(JSON.stringify({ title }), { headers: corsHeaders })
  } catch (err) {
    console.error(`[generate-dream-title][${requestId}] Unhandled error:`, err)
    return new Response(JSON.stringify({ error: 'Internal error', requestId }), { status: 500, headers: corsHeaders })
  }
})
