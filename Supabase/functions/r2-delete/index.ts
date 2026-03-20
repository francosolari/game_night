// Supabase Edge Function: Delete file from Cloudflare R2
import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { S3Client, DeleteObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3.400.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const R2_ACCOUNT_ID = Deno.env.get("R2_ACCOUNT_ID")!;
const R2_ACCESS_KEY_ID = Deno.env.get("R2_ACCESS_KEY_ID")!;
const R2_SECRET_ACCESS_KEY = Deno.env.get("R2_SECRET_ACCESS_KEY")!;
const R2_BUCKET = Deno.env.get("R2_BUCKET") || "game-night-storage";

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

    const { path } = await req.json();
    if (!path) {
      return Response.json({ error: "Missing 'path'" }, { status: 400 });
    }

    await s3.send(new DeleteObjectCommand({ Bucket: R2_BUCKET, Key: path }));

    return Response.json({ success: true });
  } catch (error) {
    console.error("R2 delete error:", error);
    return Response.json({ error: error.message }, { status: 500 });
  }
});
