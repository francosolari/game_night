// Supabase Edge Function: Notify invitees when host confirms a poll option
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, requireAuthenticatedUser } from "../_shared/auth.ts";
import { sendSMS } from "../_shared/sms.ts";

interface NotifyRequest {
  event_id: string;
  type: "time" | "game";
}

serve(async (req) => {
  try {
    const caller = await requireAuthenticatedUser(req);
    const { event_id, type }: NotifyRequest = await req.json();

    if (!event_id || !type) {
      return new Response(
        JSON.stringify({ error: "event_id and type are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createServiceClient();

    // Fetch event with host info
    const { data: event, error: eventError } = await supabase
      .from("events")
      .select("*, host:users!host_id(*)")
      .eq("id", event_id)
      .single();

    if (eventError || !event) {
      return new Response(
        JSON.stringify({ error: "Event not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    if (event.host_id !== caller.id) {
      return new Response(
        JSON.stringify({ error: "Only the host can trigger notifications" }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }

    const hostName = event.host?.display_name || "The host";
    let message = "";

    if (type === "time") {
      // Fetch confirmed time option
      const { data: timeOption } = await supabase
        .from("time_options")
        .select("*")
        .eq("id", event.confirmed_time_option_id)
        .single();

      if (timeOption) {
        const date = new Date(timeOption.start_time);
        const dateStr = date.toLocaleDateString("en-US", {
          weekday: "short",
          month: "short",
          day: "numeric",
        });
        const timeStr = date.toLocaleTimeString("en-US", {
          hour: "numeric",
          minute: "2-digit",
        });
        message = `${hostName} picked ${dateStr} at ${timeStr} for ${event.title}!`;
      }
    } else if (type === "game") {
      // Fetch confirmed game
      const { data: eventGame } = await supabase
        .from("event_games")
        .select("*, game:games(*)")
        .eq("event_id", event_id)
        .eq("game_id", event.confirmed_game_id)
        .single();

      if (eventGame?.game) {
        message = `${hostName} picked ${eventGame.game.name} for ${event.title}!`;
      }
    }

    if (!message) {
      return new Response(
        JSON.stringify({ error: "Could not determine confirmation details" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fetch active invitees (not the host)
    const { data: invites } = await supabase
      .from("invites")
      .select("phone_number")
      .eq("event_id", event_id)
      .eq("is_active", true)
      .neq("status", "declined");

    const sent: string[] = [];
    const failed: string[] = [];

    for (const invite of invites || []) {
      try {
        await sendSMS(invite.phone_number, message);
        sent.push(invite.phone_number);
      } catch (err) {
        console.error(`SMS failed for ${invite.phone_number}:`, err);
        failed.push(invite.phone_number);
      }
    }

    return new Response(
      JSON.stringify({ sent: sent.length, failed: failed.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("notify-poll-confirmed error:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
