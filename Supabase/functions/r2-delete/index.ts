// Supabase Edge Function: Delete file from Cloudflare R2
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.19";
import { requireAuthenticatedUser } from "../_shared/auth.ts";

const R2_ACCOUNT_ID = Deno.env.get("R2_ACCOUNT_ID")!;
const R2_ACCESS_KEY_ID = Deno.env.get("R2_ACCESS_KEY_ID")!;
const R2_SECRET_ACCESS_KEY = Deno.env.get("R2_SECRET_ACCESS_KEY")!;
const R2_BUCKET = Deno.env.get("R2_BUCKET") || "game-night-storage";

const r2 = new AwsClient({
  accessKeyId: R2_ACCESS_KEY_ID,
  secretAccessKey: R2_SECRET_ACCESS_KEY,
  service: "s3",
  region: "auto",
});

serve(async (req) => {
  try {
    await requireAuthenticatedUser(req);

    const { path } = await req.json();
    if (!path) {
      return new Response(
        JSON.stringify({ error: "Missing 'path'" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const endpoint = `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${R2_BUCKET}/${path}`;
    const signed = await r2.sign(new Request(endpoint, { method: "DELETE" }));
    const response = await fetch(signed);

    if (!response.ok) {
      throw new Error(`R2 delete failed: ${response.status}`);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("R2 delete error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
