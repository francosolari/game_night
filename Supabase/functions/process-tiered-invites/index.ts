// Supabase Edge Function: Process tiered invite logic
// When someone declines, automatically promote next person from waitlist
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, requireAuthenticatedUser } from "../_shared/auth.ts";
import { sendSMS } from "../_shared/sms.ts";
const APP_URL = Deno.env.get("APP_URL") || "https://gamenight.app";

interface ProcessRequest {
  invite_id: string;
}

serve(async (req) => {
  try {
    const caller = await requireAuthenticatedUser(req);
    const { invite_id }: ProcessRequest = await req.json();

    const supabase = createServiceClient();

    // Fetch the invite that was just responded to
    const { data: respondedInvite } = await supabase
      .from("invites")
      .select("id, event_id, host_user_id, user_id, status")
      .eq("id", invite_id)
      .single();

    if (!respondedInvite) {
      return new Response(
        JSON.stringify({ error: "Invite not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Verify the caller is the person who responded to this invite
    if (respondedInvite.user_id !== caller.id) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 403, headers: { "Content-Type": "application/json" } }
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

    // Promote: update status, mark as active, track promotion
    await supabase
      .from("invites")
      .update({
        status: "pending",
        is_active: true,
        promoted_at: new Date().toISOString(),
        promoted_from_tier: promotedInvite.tier,
      })
      .eq("id", promotedInvite.id);

    const inviteLink = `${APP_URL}/invite/${promotedInvite.invite_token}`;

    try {
      await sendSMS({
        to: promotedInvite.phone_number,
        message: `🎉 A spot opened up for "${event.title}"! You've been moved off the waitlist. RSVP now: ${inviteLink}`,
      });

      await supabase
        .from("invites")
        .update({ sms_delivery_status: "sent" })
        .eq("id", promotedInvite.id);
    } catch (smsError) {
      await supabase
        .from("invites")
        .update({ sms_delivery_status: "failed" })
        .eq("id", promotedInvite.id);

      console.error("Tiered invite SMS error:", smsError);
      return new Response(
        JSON.stringify({ error: "Failed to notify promoted invitee" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        promoted_invite_id: promotedInvite.id,
        promoted_phone: promotedInvite.phone_number,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }

    console.error("Tiered invite error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
