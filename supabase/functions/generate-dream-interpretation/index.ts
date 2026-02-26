import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { validateAuth } from "../_shared/auth.ts"

const corsHeaders = {
  'Content-Type': 'application/json',
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders })
  }

  const authErr = await validateAuth(req, corsHeaders)
  if (authErr) return authErr

  const { dreamText, locale, emotions } = await req.json()
  if (!dreamText || dreamText.trim().length < 10) {
    return new Response(JSON.stringify({ error: 'Dream text too short (min 10 characters)' }), { status: 400, headers: corsHeaders })
  }

  const isRussian = (locale || '').startsWith('ru')
  const emotionList = (emotions || []).join(', ')

  const systemPrompt = isRussian
    ? `Ты — юнгианский аналитик снов. Интерпретируй сон глубоко и проницательно.

Структура ответа:
1. Краткий обзор (2-3 предложения): основная тема и послание сна
2. Архетипический анализ: определи присутствующие архетипы (Тень, Анима/Анимус, Самость, Трикстер, Мудрый Старец и др.)
3. Символический разбор: разбери ключевые символы и их значение в контексте коллективного бессознательного
4. Эмоциональный контекст: как эмоции сна (${emotionList || 'не указаны'}) связаны с внутренними процессами
5. Ключевые символы (3-5 пунктов):
• Символ — значение

Стиль: тёплый, но профессиональный. Без банальностей. Конкретные инсайты, а не общие фразы.
Не используй слова: "интересно", "любопытно", "возможно это значит".
Пиши на русском.`
    : `You are a Jungian dream analyst. Interpret the dream with depth and insight.

Response structure:
1. Brief overview (2-3 sentences): core theme and message of the dream
2. Archetypal analysis: identify present archetypes (Shadow, Anima/Animus, Self, Trickster, Wise Old Man, etc.)
3. Symbolic breakdown: analyze key symbols and their meaning in the context of the collective unconscious
4. Emotional context: how the dream's emotions (${emotionList || 'not specified'}) relate to inner processes
5. Key symbols (3-5 bullet points):
• Symbol — meaning

Style: warm but professional. No platitudes. Specific insights, not generic statements.
Avoid words: "interesting", "curious", "this might mean".
Write in English.`

  const openaiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiKey) {
    return new Response(JSON.stringify({ error: 'OpenAI key not configured' }), { status: 500, headers: corsHeaders })
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
      max_tokens: 1500,
      temperature: 0.7,
    }),
  })

  if (!response.ok) {
    const error = await response.text()
    return new Response(JSON.stringify({ error: `OpenAI error: ${error}` }), { status: 502, headers: corsHeaders })
  }

  const data = await response.json()
  const interpretation = data.choices?.[0]?.message?.content || ''

  return new Response(JSON.stringify({ interpretation }), { headers: corsHeaders })
})
