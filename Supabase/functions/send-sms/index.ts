// Supabase Edge Function: Send SMS via Twilio
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { sendSMS } from "../_shared/sms.ts";

interface SMSRequest {
  to: string;
  message: string;
}

serve(async (req) => {
  try {
    const { to, message }: SMSRequest = await req.json();

    if (!to || !message) {
      return new Response(
        JSON.stringify({ error: "Missing 'to' or 'message'" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const result = await sendSMS({ to, message });

    return new Response(
      JSON.stringify({
        success: true,
        sid: result.sid,
        status: result.status,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("SMS Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
