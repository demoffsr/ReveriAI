-- Lock down the dream-images bucket so only service_role can mutate objects.
-- Public SELECT (read) remains for serving images via public URL.
-- Edge functions use service_role key and bypass RLS.

-- Ensure bucket exists and is public (read-only for anonymous)
INSERT INTO storage.buckets (id, name, public)
VALUES ('dream-images', 'dream-images', true)
ON CONFLICT (id) DO NOTHING;

-- Remove any existing permissive policies on storage.objects for this bucket
DROP POLICY IF EXISTS "Allow public read" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated delete" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated insert" ON storage.objects;

-- Only allow public SELECT (for serving images via public URL)
CREATE POLICY "dream-images: public read"
ON storage.objects FOR SELECT
USING (bucket_id = 'dream-images');

-- No INSERT/UPDATE/DELETE policies for authenticated users.
-- Only service_role (used by edge functions) bypasses RLS.
