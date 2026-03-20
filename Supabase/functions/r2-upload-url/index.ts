// Supabase Edge Function: Generate Cloudflare R2 pre-signed upload URLs
// This avoids Supabase storage egress costs by uploading directly to R2
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireAuthenticatedUser } from "../_shared/auth.ts";

const R2_ACCOUNT_ID = Deno.env.get("R2_ACCOUNT_ID")!;
const R2_ACCESS_KEY_ID = Deno.env.get("R2_ACCESS_KEY_ID")!;
const R2_SECRET_ACCESS_KEY = Deno.env.get("R2_SECRET_ACCESS_KEY")!;
const R2_BUCKET = Deno.env.get("R2_BUCKET") || "game-night-storage";
const R2_PUBLIC_URL = Deno.env.get("R2_PUBLIC_URL")!;

async function hmac(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw", key instanceof Uint8Array ? key : new Uint8Array(key),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  return crypto.subtle.sign("HMAC", cryptoKey, new TextEncoder().encode(data));
}

async function sha256hex(data: string): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(data));
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, "0")).join("");
}

function toHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

async function getPresignedPutUrl(key: string, expiresIn: number): Promise<string> {
  const region = "auto";
  const service = "s3";
  const host = `${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`;

  const now = new Date();
  const dateStr = now.toISOString().slice(0, 10).replace(/-/g, "");
  const amzDate = dateStr + "T" + now.toISOString().slice(11, 19).replace(/:/g, "") + "Z";

  const credential = `${R2_ACCESS_KEY_ID}/${dateStr}/${region}/${service}/aws4_request`;

  const queryParams = new URLSearchParams({
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": credential,
    "X-Amz-Date": amzDate,
    "X-Amz-Expires": String(expiresIn),
    "X-Amz-SignedHeaders": "host",
  });

  // Sort query params for canonical request
  const sortedQuery = Array.from(queryParams.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join("&");

  const canonicalRequest = [
    "PUT",
    `/${R2_BUCKET}/${key}`,
    sortedQuery,
    `host:${host}\n`,
    "host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");

  const canonicalHash = await sha256hex(canonicalRequest);

  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    `${dateStr}/${region}/${service}/aws4_request`,
    canonicalHash,
  ].join("\n");

  // Derive signing key
  const kDate = await hmac(new TextEncoder().encode(`AWS4${R2_SECRET_ACCESS_KEY}`), dateStr);
  const kRegion = await hmac(kDate, region);
  const kService = await hmac(kRegion, service);
  const kSigning = await hmac(kService, "aws4_request");

  const signature = toHex(await hmac(kSigning, stringToSign));

  queryParams.set("X-Amz-Signature", signature);

  return `https://${host}/${R2_BUCKET}/${key}?${queryParams.toString()}`;
}

interface UploadRequest {
  path: string;
  content_type: string;
}

serve(async (req) => {
  try {
    await requireAuthenticatedUser(req);

    const { path, content_type }: UploadRequest = await req.json();
    if (!path || !content_type) {
      return new Response(
        JSON.stringify({ error: "Missing 'path' or 'content_type'" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const uploadUrl = await getPresignedPutUrl(path, 900);
    const publicUrl = `${R2_PUBLIC_URL.trimEnd()}/${path}`;

    return new Response(
      JSON.stringify({ upload_url: uploadUrl, public_url: publicUrl }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("R2 upload URL error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
