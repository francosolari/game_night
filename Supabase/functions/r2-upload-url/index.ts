// Supabase Edge Function: Generate Cloudflare R2 pre-signed upload URLs
// This avoids Supabase storage egress costs by uploading directly to R2
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { S3Client, PutObjectCommand, GetObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3.400.0";
import { getSignedUrl } from "https://esm.sh/@aws-sdk/s3-request-presigner@3.400.0";

const R2_ACCOUNT_ID = Deno.env.get("R2_ACCOUNT_ID")!;
const R2_ACCESS_KEY_ID = Deno.env.get("R2_ACCESS_KEY_ID")!;
const R2_SECRET_ACCESS_KEY = Deno.env.get("R2_SECRET_ACCESS_KEY")!;
const R2_BUCKET = Deno.env.get("R2_BUCKET") || "gamenight";
const R2_PUBLIC_URL = Deno.env.get("R2_PUBLIC_URL")!; // e.g. https://assets.gamenight.app

const s3 = new S3Client({
  region: "auto",
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
  },
});

interface UploadRequest {
  path: string;
  content_type: string;
}

serve(async (req) => {
  try {
    const { path, content_type }: UploadRequest = await req.json();

    if (!path || !content_type) {
      return new Response(
        JSON.stringify({ error: "Missing 'path' or 'content_type'" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Generate pre-signed upload URL (valid for 15 minutes)
    const command = new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: path,
      ContentType: content_type,
    });

    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 900 });

    // Public URL for accessing the file after upload
    const publicUrl = `${R2_PUBLIC_URL}/${path}`;

    return new Response(
      JSON.stringify({
        upload_url: uploadUrl,
        public_url: publicUrl,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("R2 upload URL error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
