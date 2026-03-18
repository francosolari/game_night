import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient } from "../_shared/auth.ts";

interface BetaUserRequest {
  phone: string;
  password: string;
}

const PAGE_SIZE = 100;
const SECRET_HEADER = "x-beta-secret";
const SECRET_ENV = "BETA_SHARED_SECRET";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const expectedSecret = Deno.env.get(SECRET_ENV);
  if (!expectedSecret) {
    console.error("[beta-ensure-user] missing secret");
    return new Response(JSON.stringify({ error: "Service not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const providedSecret = req.headers.get(SECRET_HEADER);
  if (providedSecret !== expectedSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: BetaUserRequest;
  try {
    body = await req.json();
  } catch (error) {
    console.error("[beta-ensure-user] invalid JSON", error);
    return new Response(JSON.stringify({ error: "Invalid JSON payload" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const normalizedPhone = normalizePhone(body?.phone ?? "");
  const password = body?.password?.trim();
  if (!normalizedPhone || !password) {
    return new Response(JSON.stringify({ error: "Missing phone or password" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createServiceClient();

  try {
    const existingUser = await findUserByPhone(supabase, normalizedPhone);
    let userId: string | undefined;

    if (existingUser) {
      userId = existingUser.id;
      const { error } = await supabase.auth.admin.updateUserById(existingUser.id, {
        password,
        phone_confirm: true,
      });
      if (error) {
        console.error("[beta-ensure-user] updateUserById failed", error);
        throw error;
      }
    } else {
      const { data, error } = await supabase.auth.admin.createUser({
        phone: normalizedPhone,
        password,
        phone_confirm: true,
        user_metadata: { beta: true },
      });
      if (error) {
        console.error("[beta-ensure-user] createUser failed", error);
        throw error;
      }
      userId = data?.user?.id;
    }

    return new Response(
      JSON.stringify({ success: true, userId }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("[beta-ensure-user] error", error);
    return new Response(JSON.stringify({ error: (error as Error).message ?? "unknown" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

function normalizePhone(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  if (!digits) {
    return "";
  }
  if (raw.trim().startsWith("+")) {
    return `+${digits}`;
  }
  if (digits.length === 10) {
    return `+1${digits}`;
  }
  if (digits.length === 11 && digits.startsWith("1")) {
    return `+${digits}`;
  }
  return `+${digits}`;
}

async function findUserByPhone(
  supabase: ReturnType<typeof createServiceClient>,
  phone: string,
) {
  let page = 1;
  while (true) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: PAGE_SIZE });
    if (error) {
      throw error;
    }

    const users = data?.users ?? [];
    const match = users.find((user) => user?.phone === phone);
    if (match) {
      return match;
    }

    if (users.length < PAGE_SIZE) {
      break;
    }
    page += 1;
  }
  return null;
}
