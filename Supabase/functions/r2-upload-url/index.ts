// Supabase Edge Function: Generate Cloudflare R2 pre-signed upload URLs
// This avoids Supabase storage egress costs by uploading directly to R2
import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { S3Client, PutObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3.400.0";
import { getSignedUrl } from "https://esm.sh/@aws-sdk/s3-request-presigner@3.400.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const R2_ACCOUNT_ID = Deno.env.get("R2_ACCOUNT_ID")!;
const R2_ACCESS_KEY_ID = Deno.env.get("R2_ACCESS_KEY_ID")!;
const R2_SECRET_ACCESS_KEY = Deno.env.get("R2_SECRET_ACCESS_KEY")!;
const R2_BUCKET = Deno.env.get("R2_BUCKET") || "game-night-storage";
const R2_PUBLIC_URL = Deno.env.get("R2_PUBLIC_URL")!;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SB_PUBLISHABLE_KEY")!
);

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

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return Response.json({ error: "Missing Authorization header" }, { status: 401 });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data, error } = await supabase.auth.getClaims(token);
    if (error || !data?.claims) {
      return Response.json({ error: "Invalid JWT" }, { status: 401 });
    }

    const { path, content_type }: UploadRequest = await req.json();
    if (!path || !content_type) {
      return Response.json({ error: "Missing 'path' or 'content_type'" }, { status: 400 });
    }

    const command = new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: path,
      ContentType: content_type,
    });

    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 900 });
    const publicUrl = `${R2_PUBLIC_URL}/${path}`;

    return Response.json({ upload_url: uploadUrl, public_url: publicUrl });
  } catch (error) {
    console.error("R2 upload URL error:", error);
    return Response.json({ error: error.message }, { status: 500 });
  }
});
