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

  const { dreamText, locale } = await req.json()
  if (!dreamText || dreamText.trim().length === 0) {
    return new Response(JSON.stringify({ error: 'Empty dream text' }), { status: 400, headers: corsHeaders })
  }

  const openaiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiKey) {
    return new Response(JSON.stringify({ error: 'OpenAI key not configured' }), { status: 500, headers: corsHeaders })
  }

  const isRussian = (locale || '').startsWith('ru')
  const systemPrompt = isRussian
    ? `На основе текста сна сформулируй ровно 3 коротких уточняющих вопроса, которые помогут создать более детальную визуализацию этого сна. Вопросы должны касаться визуальных деталей: цвета, освещение, окружение, атмосфера, детали персонажей/объектов. Формат ответа: JSON массив из 3 строк. Пример: ["Какого цвета было небо?", "Как выглядело здание?", "Какая была атмосфера?"]. ТОЛЬКО JSON массив, без пояснений.`
    : `Based on the dream text, formulate exactly 3 short follow-up questions that will help create a more detailed visualization of this dream. Questions should focus on visual details: colors, lighting, surroundings, atmosphere, character/object details. Response format: JSON array of 3 strings. Example: ["What color was the sky?", "What did the building look like?", "What was the atmosphere like?"]. ONLY the JSON array, no explanations.`

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
      max_tokens: 200,
      temperature: 0.7,
    }),
  })

  if (!response.ok) {
    const error = await response.text()
    return new Response(JSON.stringify({ error: `OpenAI error: ${error}` }), { status: 502, headers: corsHeaders })
  }

  const data = await response.json()
  let content = data.choices?.[0]?.message?.content || '[]'

  // Parse JSON array from response
  content = content.trim()
  // Strip markdown code fences if present
  if (content.startsWith('```')) {
    content = content.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim()
  }

  let questions: string[]
  try {
    questions = JSON.parse(content)
    if (!Array.isArray(questions)) {
      questions = []
    }
  } catch {
    questions = []
  }

  // Ensure exactly 3 questions
  while (questions.length < 3) {
    questions.push(isRussian ? "Опишите атмосферу сна" : "Describe the dream atmosphere")
  }
  questions = questions.slice(0, 3)

  return new Response(JSON.stringify({ questions }), { headers: corsHeaders })
})
