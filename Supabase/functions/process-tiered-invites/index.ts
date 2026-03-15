// Supabase Edge Function: Process tiered invite logic
// When someone declines, automatically promote next person from waitlist
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface ProcessRequest {
  invite_id: string;
}

serve(async (req) => {
  try {
    const { invite_id }: ProcessRequest = await req.json();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Fetch the invite that was just responded to
    const { data: respondedInvite } = await supabase
      .from("invites")
      .select("*")
      .eq("id", invite_id)
      .single();

    if (!respondedInvite) {
      return new Response(
        JSON.stringify({ error: "Invite not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Only process if the invite was declined
    if (respondedInvite.status !== "declined") {
      return new Response(
        JSON.stringify({ message: "No action needed - invite was not declined" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fetch event to check strategy
    const { data: event } = await supabase
      .from("events")
      .select("*")
      .eq("id", respondedInvite.event_id)
      .single();

    if (!event) {
      return new Response(
        JSON.stringify({ error: "Event not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const strategy = event.invite_strategy;

    // Only process tiered invites with auto-promote
    if (strategy.type !== "tiered" || !strategy.auto_promote) {
      return new Response(
        JSON.stringify({ message: "Event does not use tiered auto-promote" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Find the next waitlisted invite to promote
    const { data: waitlisted } = await supabase
      .from("invites")
      .select("*")
      .eq("event_id", respondedInvite.event_id)
      .eq("status", "waitlisted")
      .eq("is_active", false)
      .order("tier", { ascending: true })
      .order("tier_position", { ascending: true })
      .limit(1);

    if (!waitlisted || waitlisted.length === 0) {
      return new Response(
        JSON.stringify({ message: "No waitlisted invites to promote" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const promotedInvite = waitlisted[0];

    // Promote: update status and mark as active
    await supabase
      .from("invites")
      .update({
        status: "pending",
        is_active: true,
      })
      .eq("id", promotedInvite.id);

    // Send invite notification to the promoted person
    await supabase.functions.invoke("send-invite", {
      body: {
        invite_id: promotedInvite.id,
        event_id: respondedInvite.event_id,
      },
    });

    // Also send a special "spot opened up" SMS
    const APP_URL = Deno.env.get("APP_URL") || "https://gamenight.app";
    const inviteLink = `${APP_URL}/invite/${promotedInvite.invite_token}`;

    await supabase.functions.invoke("send-sms", {
      body: {
        to: promotedInvite.phone_number,
        message: `🎉 A spot opened up for "${event.title}"! You've been moved off the waitlist. RSVP now: ${inviteLink}`,
      },
    });

    return new Response(
      JSON.stringify({
        success: true,
        promoted_invite_id: promotedInvite.id,
        promoted_phone: promotedInvite.phone_number,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Tiered invite error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
