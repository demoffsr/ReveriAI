export const MAX_DREAM_TEXT_LENGTH = 10_000
export const MAX_AUDIO_SIZE_BYTES = 25 * 1024 * 1024 // 25 MB
export const MAX_ANSWERS_COUNT = 10
export const MAX_ANSWER_LENGTH = 1_000
export const MAX_EMOTIONS_COUNT = 20

export function validateTextSize(
  text: string,
  corsHeaders: Record<string, string>,
): Response | null {
  if (text.length > MAX_DREAM_TEXT_LENGTH) {
    return new Response(
      JSON.stringify({
        error: `Text too long: ${text.length} characters (max ${MAX_DREAM_TEXT_LENGTH})`,
      }),
      { status: 413, headers: corsHeaders },
    )
  }
  return null
}

export function validateAudioSize(
  data: Uint8Array,
  corsHeaders: Record<string, string>,
): Response | null {
  if (data.length > MAX_AUDIO_SIZE_BYTES) {
    const sizeMB = (data.length / (1024 * 1024)).toFixed(1)
    const maxMB = MAX_AUDIO_SIZE_BYTES / (1024 * 1024)
    return new Response(
      JSON.stringify({
        error: `Audio too large: ${sizeMB} MB (max ${maxMB} MB)`,
      }),
      { status: 413, headers: corsHeaders },
    )
  }
  return null
}

export function validateAnswers(
  answers: unknown,
  corsHeaders: Record<string, string>,
): Response | null {
  if (!Array.isArray(answers)) return null
  if (answers.length > MAX_ANSWERS_COUNT) {
    return new Response(
      JSON.stringify({
        error: `Too many answers: ${answers.length} (max ${MAX_ANSWERS_COUNT})`,
      }),
      { status: 413, headers: corsHeaders },
    )
  }
  for (const a of answers) {
    if (typeof a === 'string' && a.length > MAX_ANSWER_LENGTH) {
      return new Response(
        JSON.stringify({
          error: `Answer too long: ${a.length} characters (max ${MAX_ANSWER_LENGTH})`,
        }),
        { status: 413, headers: corsHeaders },
      )
    }
  }
  return null
}

export function validateEmotions(
  emotions: unknown,
  corsHeaders: Record<string, string>,
): Response | null {
  if (!Array.isArray(emotions)) return null
  if (emotions.length > MAX_EMOTIONS_COUNT) {
    return new Response(
      JSON.stringify({
        error: `Too many emotions: ${emotions.length} (max ${MAX_EMOTIONS_COUNT})`,
      }),
      { status: 413, headers: corsHeaders },
    )
  }
  return null
}
