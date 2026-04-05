// Supabase Edge Function: Send push notification via APNs
// Called via Database Webhook on notifications INSERT
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient } from "../_shared/auth.ts";

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") || "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") || "";
const APNS_KEY_P8 = Deno.env.get("APNS_KEY_P8") || "";
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") || "com.cardboardwithme.app";

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

interface NotificationEnrichment {
  subtitle?: string;
  body?: string;
  image_url?: string;
  category?: string;
}

type APNsEnvironment = "sandbox" | "production";

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
  play_log_reminder: "invites_enabled",
};

// Pick best available image from event data
function pickEventImageUrl(event: {
  cover_image_url?: string | null;
  event_games?: Array<{
    is_primary?: boolean;
    sort_order?: number;
    game?: { image_url?: string | null; thumbnail_url?: string | null } | null;
  }> | null;
  host?: { avatar_url?: string | null } | null;
}): string | undefined {
  if (event.cover_image_url) return event.cover_image_url;
  const games = event.event_games ?? [];
  const sorted = [...games].sort((a, b) => {
    if (a.is_primary && !b.is_primary) return -1;
    if (!a.is_primary && b.is_primary) return 1;
    return (a.sort_order ?? 99) - (b.sort_order ?? 99);
  });
  const primary = sorted[0];
  if (primary?.game?.image_url) return primary.game.image_url;
  if (primary?.game?.thumbnail_url) return primary.game.thumbnail_url;
  if (event.host?.avatar_url) return event.host.avatar_url;
  return undefined;
}

// Format an ISO date string into a human-readable string e.g. "Sat, Apr 12 at 7:00 PM"
function formatDate(iso: string): string {
  try {
    const d = new Date(iso);
    const date = d.toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      timeZone: "UTC",
    });
    const time = d.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      timeZone: "UTC",
    });
    return `${date} at ${time}`;
  } catch {
    return iso;
  }
}

// Build enrichment data for each notification type
async function buildEnrichment(
  supabase: ReturnType<typeof createServiceClient>,
  notification: WebhookPayload["record"]
): Promise<NotificationEnrichment> {
  const type = notification.type;

  // --- Event-based types ---
  if (notification.event_id && type !== "group_invite" && type !== "dm_received") {
    const { data: event } = await supabase
      .from("events")
      .select(`
        title,
        cover_image_url,
        location,
        confirmed_time_option_id,
        host:users!host_id(display_name, avatar_url),
        event_games(is_primary, sort_order, game:games(name, image_url, thumbnail_url)),
        time_options(id, start_time),
        confirmed_game:games!confirmed_game_id(name, image_url, thumbnail_url)
      `)
      .eq("id", notification.event_id)
      .maybeSingle();

    if (!event) return {};

    const imageUrl = pickEventImageUrl(event as Parameters<typeof pickEventImageUrl>[0]);
    const hostName = (event.host as { display_name?: string } | null)?.display_name;
    const location = (event as { location?: string | null }).location;

    switch (type) {
      case "invite_received": {
        const bodyParts = [
          hostName ? `From ${hostName}` : null,
          location || null,
        ].filter(Boolean);
        return {
          subtitle: event.title,
          body: bodyParts.length > 0 ? bodyParts.join(" · ") : undefined,
          image_url: imageUrl,
          category: "INVITE_ACTION",
        };
      }

      case "rsvp_update":
        return {
          subtitle: event.title,
          image_url: imageUrl,
          category: "EVENT_UPDATE",
        };

      case "time_confirmed": {
        const confirmedOptionId = (event as { confirmed_time_option_id?: string | null }).confirmed_time_option_id;
        const timeOptions = (event as { time_options?: Array<{ id: string; start_time: string }> | null }).time_options ?? [];
        const confirmedOption = timeOptions.find((t) => t.id === confirmedOptionId);
        return {
          subtitle: event.title,
          body: confirmedOption ? formatDate(confirmedOption.start_time) : undefined,
          image_url: imageUrl,
          category: "EVENT_UPDATE",
        };
      }

      case "game_confirmed": {
        const confirmedGame = (event as { confirmed_game?: { name?: string; image_url?: string | null; thumbnail_url?: string | null } | null }).confirmed_game;
        return {
          subtitle: event.title,
          body: confirmedGame?.name ? `${confirmedGame.name} is on the table!` : undefined,
          image_url: confirmedGame?.image_url ?? confirmedGame?.thumbnail_url ?? imageUrl,
          category: "EVENT_UPDATE",
        };
      }

      case "bench_promoted":
      case "event_cancelled":
      case "play_log_reminder":
      case "text_blast":
        return {
          subtitle: event.title,
          image_url: imageUrl,
          category: type === "event_cancelled" ? "EVENT_UPDATE" : "EVENT_UPDATE",
        };

      default:
        return { subtitle: event.title, image_url: imageUrl, category: "EVENT_UPDATE" };
    }
  }

  // --- Group invite ---
  if (type === "group_invite" && notification.group_id) {
    const { data: group } = await supabase
      .from("groups")
      .select("name, emoji, owner:users!owner_id(display_name, avatar_url)")
      .eq("id", notification.group_id)
      .maybeSingle();

    if (!group) return { category: "GROUP_ACTION" };
    const ownerName = (group.owner as { display_name?: string } | null)?.display_name;
    const ownerAvatar = (group.owner as { avatar_url?: string | null } | null)?.avatar_url;
    return {
      subtitle: ownerName ? `By ${ownerName}` : undefined,
      image_url: ownerAvatar ?? undefined,
      category: "GROUP_ACTION",
    };
  }

  // --- DM received ---
  if (type === "dm_received") {
    const senderId = notification.metadata?.sender_id as string | undefined;
    if (senderId) {
      const { data: sender } = await supabase
        .from("users")
        .select("avatar_url")
        .eq("id", senderId)
        .maybeSingle();
      return {
        image_url: (sender as { avatar_url?: string | null } | null)?.avatar_url ?? undefined,
        category: "DM_ACTION",
      };
    }
    return { category: "DM_ACTION" };
  }

  return {};
}

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
      .select("device_token, platform, apns_environment")
      .eq("user_id", notification.user_id);

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No push tokens registered for user" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fetch unread count for badge and enrichment data in parallel
    const [{ count: unreadCount }, enrichment] = await Promise.all([
      supabase
        .from("notifications")
        .select("*", { count: "exact", head: true })
        .eq("user_id", notification.user_id)
        .is("read_at", null),
      buildEnrichment(supabase, notification),
    ]);

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

    // Build APNs payload — undefined values are dropped by JSON.stringify
    const apnsPayload = {
      aps: {
        alert: {
          title: notification.title,
          subtitle: enrichment.subtitle,
          body: enrichment.body ?? notification.body ?? "",
        },
        badge: unreadCount ?? 0,
        sound: "default",
        "mutable-content": 1,
        category: enrichment.category,
      },
      // Custom data for navigation
      notification_type: notification.type,
      event_id: notification.event_id ?? undefined,
      invite_id: notification.invite_id ?? undefined,
      group_id: notification.group_id ?? undefined,
      conversation_id: notification.conversation_id ?? undefined,
      // Downloaded by Notification Service Extension to attach as thumbnail
      image_url: enrichment.image_url,
    };

    // Send to all registered devices
    const results = await Promise.allSettled(
      tokens.map(async (token) => {
        const apnsEnvironment = resolveAPNsEnvironment(token.apns_environment);
        const apnsHost =
          apnsEnvironment === "production"
            ? "api.push.apple.com"
            : "api.sandbox.push.apple.com";
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
          console.error(
            `APNs error for token ${token.device_token} (${apnsEnvironment}):`,
            errorBody
          );

          // Remove invalid tokens
          if (response.status === 410 || response.status === 400) {
            await supabase
              .from("push_tokens")
              .delete()
              .eq("device_token", token.device_token)
              .eq("apns_environment", apnsEnvironment)
              .eq("user_id", notification.user_id);
          }

          throw new Error(`APNs ${response.status}: ${errorBody}`);
        }

        return { token: token.device_token, status: "sent", apnsEnvironment };
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

function resolveAPNsEnvironment(raw: unknown): APNsEnvironment {
  return raw === "sandbox" ? "sandbox" : "production";
}
