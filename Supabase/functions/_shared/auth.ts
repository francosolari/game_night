import { createClient, type User } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

export function createServiceClient() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
}

export async function requireAuthenticatedUser(req: Request): Promise<User> {
  const authorization = req.headers.get("Authorization") ?? req.headers.get("authorization");

  if (!authorization?.startsWith("Bearer ")) {
    throw new Response(
      JSON.stringify({ error: "Missing bearer token" }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  const token = authorization.slice("Bearer ".length).trim();
  const supabase = createServiceClient();
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data.user) {
    throw new Response(
      JSON.stringify({ error: "Invalid or expired token" }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  return data.user;
}
