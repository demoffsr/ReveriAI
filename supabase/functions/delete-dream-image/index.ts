import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { validateAuth, isAuthError, supabaseAdmin } from "../_shared/auth.ts"

const corsHeaders = {
  'Content-Type': 'application/json',
}

// Full UUID v4 format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.png
const imagePathRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$/

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders })
  }

  const auth = await validateAuth(req, corsHeaders)
  if (isAuthError(auth)) return auth

  const { imagePath } = await req.json()
  if (!imagePath || typeof imagePath !== 'string') {
    return new Response(JSON.stringify({ error: 'Missing imagePath' }), { status: 400, headers: corsHeaders })
  }

  if (!imagePathRegex.test(imagePath)) {
    return new Response(JSON.stringify({ error: 'Invalid imagePath format' }), { status: 400, headers: corsHeaders })
  }

  console.log(`[delete-dream-image] userId=${auth.userId} imagePath=${imagePath}`)

  const { error } = await supabaseAdmin.storage
    .from('dream-images')
    .remove([imagePath])

  if (error) {
    console.error(`[delete-dream-image] Storage error: ${error.message}`)
    return new Response(JSON.stringify({ error: `Storage error: ${error.message}` }), { status: 500, headers: corsHeaders })
  }

  return new Response(JSON.stringify({ success: true }), { headers: corsHeaders })
})
