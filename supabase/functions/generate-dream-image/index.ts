import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "jsr:@supabase/supabase-js@2"

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

  const { dreamText, locale, answers } = await req.json()
  if (!dreamText || dreamText.trim().length === 0) {
    return new Response(JSON.stringify({ error: 'Empty dream text' }), { status: 400, headers: corsHeaders })
  }

  const openaiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiKey) {
    return new Response(JSON.stringify({ error: 'OpenAI key not configured' }), { status: 500, headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(JSON.stringify({ error: 'Supabase not configured' }), { status: 500, headers: corsHeaders })
  }

  // Step 1: Build enriched dream description
  let enrichedDescription = dreamText
  if (Array.isArray(answers) && answers.length > 0) {
    const answersText = answers.filter(a => a && a.trim().length > 0).join('. ')
    if (answersText) {
      enrichedDescription = `${dreamText}. Additional visual details: ${answersText}`
    }
  }

  // Step 2: Generate detailed art prompt via GPT-4o-mini
  const artDirectorPrompt = `You are an expert art director specializing in dream visualization. Given a dream description, create a detailed visual prompt (150-200 words, in English) for an AI image generator.

Your prompt must describe:
- **Composition**: camera angle, framing, focal point, depth of field
- **Lighting**: light sources, quality (soft/hard), color temperature, time of day
- **Color palette**: dominant colors, accent colors, overall mood
- **Atmosphere**: fog, particles, bokeh, volumetric light, weather
- **Key subjects**: describe each element with vivid detail — textures, materials, scale, position
- **Surreal elements**: dreamlike distortions, impossible geometry, scale shifts, floating objects
- **Art style**: contemporary digital surrealism, painterly brushstrokes, cinematic quality

Rules:
- Write ONLY the visual prompt, no explanations or preamble
- Always in English regardless of input language
- Never include text/words/letters in the image
- Make it feel like a scene from a surreal art film — emotionally evocative, visually striking
- Emphasize the most vivid and unusual elements of the dream
- Add unexpected surreal details that enhance the dreamlike quality`

  const promptResponse = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: artDirectorPrompt },
        { role: 'user', content: enrichedDescription },
      ],
      max_tokens: 350,
      temperature: 0.9,
    }),
  })

  if (!promptResponse.ok) {
    const error = await promptResponse.text()
    return new Response(JSON.stringify({ error: `Prompt generation error: ${error}` }), { status: 502, headers: corsHeaders })
  }

  const promptData = await promptResponse.json()
  const artPrompt = promptData.choices?.[0]?.message?.content || enrichedDescription

  // Step 3: Generate image with gpt-image-1 using the detailed art prompt
  const openaiResponse = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-image-1',
      prompt: artPrompt,
      n: 1,
      size: '1024x1024',
      quality: 'high',
      moderation: 'low',
    }),
  })

  if (!openaiResponse.ok) {
    const error = await openaiResponse.text()
    return new Response(JSON.stringify({ error: `OpenAI error: ${error}` }), { status: 502, headers: corsHeaders })
  }

  const openaiData = await openaiResponse.json()
  const b64Image = openaiData.data?.[0]?.b64_json
  if (!b64Image) {
    return new Response(JSON.stringify({ error: 'No image data returned' }), { status: 502, headers: corsHeaders })
  }

  // Decode base64 to binary
  const binaryString = atob(b64Image)
  const bytes = new Uint8Array(binaryString.length)
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }

  // Upload to Supabase Storage
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const fileName = `${crypto.randomUUID()}.png`

  const { error: uploadError } = await supabase.storage
    .from('dream-images')
    .upload(fileName, bytes, {
      contentType: 'image/png',
      upsert: false,
    })

  if (uploadError) {
    return new Response(JSON.stringify({ error: `Storage error: ${uploadError.message}` }), { status: 500, headers: corsHeaders })
  }

  const { data: urlData } = supabase.storage
    .from('dream-images')
    .getPublicUrl(fileName)

  return new Response(JSON.stringify({ imageURL: urlData.publicUrl }), { headers: corsHeaders })
})
