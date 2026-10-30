import { createClient } from "npm:@supabase/supabase-js@2";

import {
  createMobileLookupHash,
  encryptMobile,
} from "../_shared/member-mobile.ts";

import { validateOwnerRegisterRequest } from "../_shared/owner-register-request.ts";
import { registerOwnerMember } from "../_shared/owner-register-service.ts";
import { toPostgresBytea } from "../_shared/postgres-bytea.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const publishableKey = Deno.env.get("SUPABASE_ANON_KEY");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const appOrigin = Deno.env.get("APP_ORIGIN");

const corsHeaders = {
  "Access-Control-Allow-Origin": appOrigin ?? "",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (request) => {
  if (!appOrigin) {
    return respond(503, { error: "SERVER_CONFIGURATION_ERROR" });
  }

  if (request.method === "OPTIONS") {
    if (request.headers.get("Origin") !== appOrigin) {
      return new Response(null, { status: 403 });
    }

    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const validated = await validateOwnerRegisterRequest(request, appOrigin);

  if (!validated.ok) {
    return respond(validated.status, { error: validated.error });
  }

  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    return respond(500, { error: "SERVER_CONFIGURATION_ERROR" });
  }

  try {
    const authClient = createClient(supabaseUrl, publishableKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const result = await registerOwnerMember(
      validated.accessToken,
      validated.body,
      {
        authenticate: async (accessToken) => {
          const { data, error } = await authClient.auth.getUser(accessToken);

          if (error || !data.user) {
            return null;
          }

          return data.user.id;
        },

        isActiveOwner: async (userId) => {
          const { data, error } = await serviceClient
            .schema("api")
            .rpc("is_active_owner_for_user", {
              p_user_id: userId,
            });

          if (error) {
            throw new Error("OWNER_VERIFICATION_UNAVAILABLE");
          }

          return data === true;
        },

        hashMobile: createMobileLookupHash,

        encryptMobile,

        insertMember: async (input) => {
          const { data, error } = await serviceClient
            .schema("api")
            .rpc("owner_register_member", {
              p_actor_user_id: input.actorUserId,
              p_full_name: input.fullName,
              p_mobile_lookup_hash: toPostgresBytea(
                input.mobileLookupHash,
              ),
              p_mobile_encrypted: toPostgresBytea(
                input.mobileEncrypted,
              ),
            });

          if (error) {
            throw new Error(error.message);
          }

          return data;
        },
      },
    );

    return respond(result.status, result.body);
  } catch {
    return respond(500, { error: "INTERNAL_SERVER_ERROR" });
  }
});
