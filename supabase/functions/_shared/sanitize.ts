/**
 * Prompt injection defense utilities.
 *
 * Strategy: delimiter-based input isolation + emotion allowlist.
 * We wrap user content in XML tags so the model distinguishes
 * instructions from user-provided dream text. Angle brackets
 * inside user text are escaped to fullwidth variants to prevent
 * delimiter breakout.
 */

/**
 * Escape angle brackets to prevent delimiter breakout.
 * Fullwidth brackets (＜＞) are visually similar but structurally inert.
 * Dream text has no legitimate need for < or >.
 */
function escapeAngleBrackets(text: string): string {
  return text.replace(/</g, '＜').replace(/>/g, '＞')
}

/**
 * Wrap user text in XML delimiters so the model distinguishes
 * instructions from content.
 */
export function wrapUserInput(text: string, tag = 'dream_text'): string {
  return `<${tag}>${escapeAngleBrackets(text)}</${tag}>`
}

/** Known DreamEmotion raw values (mirrors DreamEmotion.swift) */
const ALLOWED_EMOTIONS = new Set([
  'joyful', 'inLove', 'calm', 'confused', 'anxious', 'scared', 'angry',
])

/** Validate emotions against known allowlist */
export function sanitizeEmotions(emotions: string[]): string[] {
  return emotions.filter(e => ALLOWED_EMOTIONS.has(e))
}
