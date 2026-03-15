// Supabase Edge Function: Send invite notification (SMS + Push)
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APP_URL = Deno.env.get("APP_URL") || "https://gamenight.app";

interface InviteRequest {
  invite_id: string;
  event_id: string;
}

serve(async (req) => {
  try {
    const { invite_id, event_id }: InviteRequest = await req.json();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Fetch invite details
    const { data: invite, error: inviteError } = await supabase
      .from("invites")
      .select("*")
      .eq("id", invite_id)
      .single();

    if (inviteError || !invite) {
      return new Response(
        JSON.stringify({ error: "Invite not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
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
      .eq("id", event_id)
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

    // Send SMS
    const smsMessage = `🎲 ${hostName} invited you to "${event.title}"!\n\nGames: ${gameList}\n\nRSVP: ${inviteLink}`;

    // Call the send-sms function
    const { error: smsError } = await supabase.functions.invoke("send-sms", {
      body: {
        to: invite.phone_number,
        message: smsMessage,
      },
    });

    // Update SMS delivery status
    await supabase
      .from("invites")
      .update({
        sms_delivery_status: smsError ? "failed" : "sent",
      })
      .eq("id", invite_id);

    return new Response(
      JSON.stringify({
        success: true,
        sms_sent: !smsError,
        invite_link: inviteLink,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Send invite error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
