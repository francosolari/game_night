// Supabase Edge Function: Send push notification via APNs
// Called via Database Webhook on notifications INSERT
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient } from "../_shared/auth.ts";

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") || "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") || "";
const APNS_KEY_P8 = Deno.env.get("APNS_KEY_P8") || "";
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") || "com.cardboardwithme.app";
const APNS_ENVIRONMENT = Deno.env.get("APNS_ENVIRONMENT") || "development"; // "production" for App Store

interface WebhookPayload {
  type: "INSERT";
  table: string;
  record: {
    id: string;
    user_id: string;
    type: string;
    title: string;
    body: string | null;
    metadata: Record<string, unknown>;
    event_id: string | null;
    invite_id: string | null;
    group_id: string | null;
    conversation_id: string | null;
  };
}

// Map notification type to preference field
const TYPE_TO_PREFERENCE: Record<string, string> = {
  invite_received: "invites_enabled",
  rsvp_update: "rsvp_updates_enabled",
  group_invite: "invites_enabled",
  time_confirmed: "invites_enabled",
  bench_promoted: "invites_enabled",
  dm_received: "dms_enabled",
  text_blast: "text_blasts_enabled",
  game_confirmed: "invites_enabled",
  event_cancelled: "invites_enabled",
};

// Generate JWT for APNs authentication
async function generateAPNsJWT(): Promise<string> {
  if (!APNS_KEY_P8 || !APNS_KEY_ID || !APNS_TEAM_ID) {
    throw new Error("APNs credentials not configured");
  }

  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const now = Math.floor(Date.now() / 1000);
  const claims = { iss: APNS_TEAM_ID, iat: now };

  const encoder = new TextEncoder();

  // Base64URL encode
  const b64url = (data: Uint8Array) =>
    btoa(String.fromCharCode(...data))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const headerB64 = b64url(encoder.encode(JSON.stringify(header)));
  const claimsB64 = b64url(encoder.encode(JSON.stringify(claims)));
  const signingInput = `${headerB64}.${claimsB64}`;

  // Import the .p8 key (PEM PKCS8 EC private key)
  const pemContents = APNS_KEY_P8
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const keyData = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput)
  );

  // Convert DER signature to raw r||s format for JWT
  const sigB64 = b64url(new Uint8Array(signature));

  return `${signingInput}.${sigB64}`;
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    const notification = payload.record;

    if (!notification) {
      return new Response(
        JSON.stringify({ error: "No notification record in payload" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createServiceClient();

    // Check user's notification preferences
    const { data: prefs } = await supabase
      .from("notification_preferences")
      .select("*")
      .eq("user_id", notification.user_id)
      .maybeSingle();

    if (prefs) {
      const prefField = TYPE_TO_PREFERENCE[notification.type];
      if (prefField && prefs[prefField] === false) {
        return new Response(
          JSON.stringify({ message: "Notification type disabled by user preferences" }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }
    }

    // Fetch user's push tokens
    const { data: tokens } = await supabase
      .from("push_tokens")
      .select("device_token, platform")
      .eq("user_id", notification.user_id);

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No push tokens registered for user" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get unread count for badge
    const { count: unreadCount } = await supabase
      .from("notifications")
      .select("*", { count: "exact", head: true })
      .eq("user_id", notification.user_id)
      .is("read_at", null);

    // Generate APNs JWT
    let jwt: string;
    try {
      jwt = await generateAPNsJWT();
    } catch (e) {
      console.error("APNs JWT generation failed:", e);
      return new Response(
        JSON.stringify({ error: "APNs not configured", detail: e.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const apnsHost =
      APNS_ENVIRONMENT === "production"
        ? "api.push.apple.com"
        : "api.sandbox.push.apple.com";

    // Build APNs payload
    const apnsPayload = {
      aps: {
        alert: {
          title: notification.title,
          body: notification.body || "",
        },
        badge: unreadCount || 0,
        sound: "default",
        "mutable-content": 1,
      },
      // Custom data for navigation
      notification_type: notification.type,
      event_id: notification.event_id,
      invite_id: notification.invite_id,
      group_id: notification.group_id,
      conversation_id: notification.conversation_id,
    };

    // Send to all registered devices
    const results = await Promise.allSettled(
      tokens.map(async (token) => {
        const url = `https://${apnsHost}/3/device/${token.device_token}`;
        const response = await fetch(url, {
          method: "POST",
          headers: {
            authorization: `bearer ${jwt}`,
            "apns-topic": APNS_BUNDLE_ID,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "apns-expiration": "0",
            "content-type": "application/json",
          },
          body: JSON.stringify(apnsPayload),
        });

        if (!response.ok) {
          const errorBody = await response.text();
          console.error(`APNs error for token ${token.device_token}:`, errorBody);

          // Remove invalid tokens
          if (response.status === 410 || response.status === 400) {
            await supabase
              .from("push_tokens")
              .delete()
              .eq("device_token", token.device_token)
              .eq("user_id", notification.user_id);
          }

          throw new Error(`APNs ${response.status}: ${errorBody}`);
        }

        return { token: token.device_token, status: "sent" };
      })
    );

    const sent = results.filter((r) => r.status === "fulfilled").length;
    const failed = results.filter((r) => r.status === "rejected").length;

    return new Response(
      JSON.stringify({ sent, failed, total: tokens.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Push notification error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
