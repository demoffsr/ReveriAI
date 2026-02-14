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

  const { dreamText, locale } = await req.json()
  if (!dreamText || dreamText.trim().length === 0) {
    return new Response(JSON.stringify({ error: 'Empty dream text' }), { status: 400, headers: corsHeaders })
  }

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
      max_tokens: 25,
      temperature: 0.7,
    }),
  })

  if (!response.ok) {
    const error = await response.text()
    return new Response(JSON.stringify({ error: `OpenAI error: ${error}` }), { status: 502, headers: corsHeaders })
  }

  const data = await response.json()
  let title = data.choices?.[0]?.message?.content || ''

  // Post-processing: trim, strip quotes and trailing period
  title = title.trim()
  title = title.replace(/^["«'"']+|["»'"']+$/g, '')
  title = title.replace(/\.$/, '')
  title = title.trim()

  return new Response(JSON.stringify({ title }), { headers: corsHeaders })
})
