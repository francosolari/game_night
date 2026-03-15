import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PublicInviteRequest {
  invite_token: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { invite_token }: PublicInviteRequest = await req.json();

    if (!invite_token) {
      return new Response(
        JSON.stringify({ error: "invite_token is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const { data: invite, error } = await supabase
      .from("invites")
      .select(`
        id,
        display_name,
        status,
        is_active,
        created_at,
        event:events(
          id,
          title,
          description,
          location,
          location_address,
          allow_time_suggestions,
          host:users(display_name),
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
        )
      `)
      .eq("invite_token", invite_token)
      .single();

    if (error || !invite || !invite.event) {
      return new Response(
        JSON.stringify({ error: "Invite not found or expired." }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({
        ...invite,
        rsvp_requires_auth: true,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Get public invite error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
