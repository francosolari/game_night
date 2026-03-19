import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient } from "../_shared/auth.ts";

interface BetaUserRequest {
  phone: string;
  password?: string;
  mode?: "probe" | "ensure";
}

const PAGE_SIZE = 1000;
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
  const mode = body?.mode ?? "ensure";
  const password = body?.password?.trim();
  if (!normalizedPhone) {
    return new Response(JSON.stringify({ error: "Missing phone number" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (mode === "ensure" && !password) {
    return new Response(JSON.stringify({ error: "Missing password for ensure mode" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createServiceClient();

    try {
        const existingUser = await findUserByPhone(supabase, normalizedPhone);
        let userId: string | undefined;

        if (mode === "probe") {
            return new Response(
              JSON.stringify({ exists: Boolean(existingUser), userId: existingUser?.id ?? null }),
              { status: 200, headers: { "Content-Type": "application/json" } },
            );
        }

        if (existingUser) {
            userId = existingUser.id;
        } else {
            const { data, error } = await supabase.auth.admin.createUser({
                phone: normalizedPhone,
                password: password!,
                phone_confirm: true,
                user_metadata: { beta: true },
            });
            if (error) {
                console.error("[beta-ensure-user] createUser failed", error);
                const fallbackExisting = await retryFindUserByPhone(supabase, normalizedPhone);
                if (fallbackExisting) {
                    userId = fallbackExisting.id;
                } else {
                    const body = JSON.stringify(error);
                    return new Response(
                        JSON.stringify({ error: body ?? "Phone collision" }),
                        { status: 500, headers: { "Content-Type": "application/json" } },
                    );
                }
            } else {
                userId = data?.user?.id;
            }
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
  const normalizedTarget = normalizePhone(phone);
  let page = 1;
  while (true) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: PAGE_SIZE });
    if (error) {
      throw error;
    }

    const users = data?.users ?? [];
    const match = users.find((user) => normalizePhone(user?.phone ?? "") === normalizedTarget);
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

async function retryFindUserByPhone(
  supabase: ReturnType<typeof createServiceClient>,
  phone: string,
) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const match = await findUserByPhone(supabase, phone);
    if (match) {
      return match;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  return null;
}
