import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PublicEventRequest {
  share_token: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { share_token }: PublicEventRequest = await req.json();

    if (!share_token) {
      return new Response(
        JSON.stringify({ error: "share_token is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const { data: event, error } = await supabase
      .from("events")
      .select(`
        id,
        title,
        description,
        location,
        location_address,
        status,
        allow_time_suggestions,
        allow_guest_invites,
        cover_image_url,
        cover_variant,
        host:users!host_id(display_name, avatar_url),
        games:event_games(
          is_primary,
          sort_order,
          game:games(
            name,
            complexity,
            min_playtime,
            max_playtime,
            min_players,
            max_players,
            thumbnail_url
          )
        ),
        time_options:time_options(
          id,
          date,
          start_time,
          end_time,
          label,
          vote_count
        )
      `)
      .eq("share_token", share_token)
      .is("deleted_at", null)
      .single();

    if (error || !event) {
      return new Response(
        JSON.stringify({ error: "Event not found." }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Don't expose cancelled/draft events publicly
    if (event.status === "cancelled" || event.status === "draft") {
      return new Response(
        JSON.stringify({ error: "Event not found." }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({
        ...event,
        rsvp_requires_auth: true,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Get public event error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
