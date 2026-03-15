// Supabase Edge Function: Send invite notification (SMS + Push)
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, requireAuthenticatedUser } from "../_shared/auth.ts";
import { sendSMS } from "../_shared/sms.ts";
const APP_URL = Deno.env.get("APP_URL") || "https://gamenight.app";

interface InviteRequest {
  invite_id: string;
}

serve(async (req) => {
  try {
    const caller = await requireAuthenticatedUser(req);
    const { invite_id }: InviteRequest = await req.json();

    if (!invite_id) {
      return new Response(
        JSON.stringify({ error: "invite_id is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createServiceClient();

    // Fetch invite details
    const { data: invite, error: inviteError } = await supabase
      .from("invites")
      .select("id, event_id, host_user_id, phone_number, invite_token")
      .eq("id", invite_id)
      .single();

    if (inviteError || !invite) {
      return new Response(
        JSON.stringify({ error: "Invite not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    if (invite.host_user_id !== caller.id) {
      return new Response(
        JSON.stringify({ error: "Only the event host can send invites" }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fetch event with games
    const { data: event } = await supabase
      .from("events")
      .select(`
        *,
        host:users(display_name),
        games:event_games(
          is_primary,
          game:games(name, complexity, min_playtime, max_playtime)
        )
      `)
      .eq("id", invite.event_id)
      .single();

    if (!event) {
      return new Response(
        JSON.stringify({ error: "Event not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Build invite link
    const inviteLink = `${APP_URL}/invite/${invite.invite_token}`;

    // Build game list for SMS
    const gameList = event.games
      .sort((a: any, b: any) => (b.is_primary ? 1 : 0) - (a.is_primary ? 1 : 0))
      .map((eg: any) => {
        const g = eg.game;
        const star = eg.is_primary ? "⭐ " : "";
        const time = g.min_playtime === g.max_playtime
          ? `${g.min_playtime}min`
          : `${g.min_playtime}-${g.max_playtime}min`;
        return `${star}${g.name} (${time})`;
      })
      .join(", ");

    const hostName = event.host?.display_name || "Someone";

    const smsMessage = `🎲 ${hostName} invited you to "${event.title}"!\n\nGames: ${gameList}\n\nRSVP: ${inviteLink}`;

    try {
      await sendSMS({
        to: invite.phone_number,
        message: smsMessage,
      });

      await supabase
        .from("invites")
        .update({ sms_delivery_status: "sent" })
        .eq("id", invite_id);
    } catch (smsError) {
      await supabase
        .from("invites")
        .update({ sms_delivery_status: "failed" })
        .eq("id", invite_id);

      console.error("Send invite SMS error:", smsError);
      return new Response(
        JSON.stringify({ error: "Failed to send invite SMS" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        sms_sent: true,
        invite_link: inviteLink,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }

    console.error("Send invite error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
