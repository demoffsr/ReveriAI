-- Make dream-images bucket private and add user-scoped RLS
--
-- Previously the bucket was public (anyone with a UUID-based URL could view images).
-- Now: bucket is private, authenticated users can SELECT only their own folder,
-- service_role can still do anything (edge functions).
--
-- Edge function returns signed URLs (1h validity) instead of public URLs.
-- iOS app caches images locally on first download — no ongoing network dependency.

-- 1. Make bucket private
UPDATE storage.buckets SET public = false WHERE id = 'dream-images';

-- 2. Drop the old "anyone can read" policy
DROP POLICY IF EXISTS "dream-images: public read" ON storage.objects;

-- 3. Authenticated users can read only their own images
--    Path format: {auth.uid()}/{uuid}.png
--    storage.foldername(name) returns array of path segments
CREATE POLICY "dream-images: user read own"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'dream-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- No INSERT/UPDATE/DELETE policies — only service_role (edge functions) can write/delete.
