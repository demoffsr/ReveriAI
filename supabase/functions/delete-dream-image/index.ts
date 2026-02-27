import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { validateAuth, isAuthError, supabaseAdmin } from "../_shared/auth.ts"

const corsHeaders = {
  'Content-Type': 'application/json',
}

// Full UUID v4 format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.png
const imagePathRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$/

Deno.serve(async (req) => {
  const requestId = crypto.randomUUID().slice(0, 8)

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed', requestId }), { status: 405, headers: corsHeaders })
    }

    const auth = await validateAuth(req, corsHeaders)
    if (isAuthError(auth)) return auth

    const { imagePath } = await req.json()
    if (!imagePath || typeof imagePath !== 'string') {
      return new Response(JSON.stringify({ error: 'Missing imagePath', requestId }), { status: 400, headers: corsHeaders })
    }

    if (!imagePathRegex.test(imagePath)) {
      return new Response(JSON.stringify({ error: 'Invalid imagePath format', requestId }), { status: 400, headers: corsHeaders })
    }

    console.log(`[delete-dream-image][${requestId}] userId=${auth.userId} imagePath=${imagePath}`)

    const { error } = await supabaseAdmin.storage
      .from('dream-images')
      .remove([imagePath])

    if (error) {
      console.error(`[delete-dream-image][${requestId}] Storage error: ${error.message}`)
      return new Response(JSON.stringify({ error: 'Image deletion failed', requestId }), { status: 500, headers: corsHeaders })
    }

    return new Response(JSON.stringify({ success: true }), { headers: corsHeaders })
  } catch (err) {
    console.error(`[delete-dream-image][${requestId}] Unhandled error:`, err)
    return new Response(JSON.stringify({ error: 'Internal error', requestId }), { status: 500, headers: corsHeaders })
  }
})
