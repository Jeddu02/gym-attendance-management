import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { withBrowserCors } from "../_shared/browser-cors.ts";
import { readIngressBody } from "../_shared/walkin-ingress.ts";
import { parseWalkinRequestLimit } from "../_shared/walkin-request.ts";
import { capabilityDigest, parseRecoveryInput, recoveryResponse } from "../_shared/walkin-recovery.ts";

const origin = Deno.env.get("APP_ORIGIN");
const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const enabled = Deno.env.get("PUBLIC_WALKIN_ENABLED") === "true";
const limit = parseWalkinRequestLimit(Deno.env.get("WALKIN_REQUEST_LIMIT_PER_MINUTE"));
let isolatedBackend = false;
try { isolatedBackend = ["127.0.0.1", "localhost", "[::1]"].includes(new URL(url ?? "").hostname); } catch { /* fail closed */ }
// Local implementation only: the all-attempt ingress architecture/limits remain
// an explicit release blocker. Do not enable this bundle on hosted systems.
Deno.serve(withBrowserCors(origin, async (request: Request) => {
  const respond = (status: number, body: Record<string, unknown>) => new Response(JSON.stringify(body), {
    status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store", "Vary": "Origin", "Access-Control-Allow-Origin": origin! },
  });
  if (request.method !== "POST") return respond(405, { error: "REQUEST_UNAVAILABLE" });
  if (!isolatedBackend || !enabled || !url || !key || limit !== 10) return respond(503, { error: "REQUEST_UNAVAILABLE" });
  const deadline = AbortSignal.any([request.signal, AbortSignal.timeout(10000)]);
  const service = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
  const call = (name: string, args: Record<string, unknown>, ms: number) => service.schema("api").rpc(name, args)
    .abortSignal(AbortSignal.any([deadline, AbortSignal.timeout(ms)]));
  const throttled = () => {
    const response = respond(429, { error: "REQUEST_UNAVAILABLE" });
    response.headers.set("Retry-After", "5"); return response;
  };
  let ticket: string | undefined; let dispatched = false;
  const finish = async (kind: string) => {
    if (ticket && !dispatched && !deadline.aborted) {
      try { await call("public_walkin_finish", { p_ticket: ticket, p_kind: kind }, 1000); } catch { /* Lease reclamation remains authoritative. */ }
    }
  };
  const observe = async (kind: string) => {
    if (!deadline.aborted) {
      try { await call("public_walkin_observe", { p_kind: kind }, 1000); } catch { /* No sensitive log or unsafe retry. */ }
    }
  };
  try {
    const admission = await call("public_walkin_admit", {}, 1000);
    if (admission.error) { await observe("unavailable"); return respond(503, { error: "REQUEST_UNAVAILABLE" }); }
    if (admission.data?.status === "denied") return throttled();
    if (admission.data?.status !== "allowed" || typeof admission.data.ticket !== "string"
      || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(admission.data.ticket))
      return respond(503, { error: "REQUEST_UNAVAILABLE" });
    ticket = admission.data.ticket;
    let input;
    try { input = parseRecoveryInput(await readIngressBody(request, AbortSignal.any([deadline, AbortSignal.timeout(2000)]))); }
    catch (error) {
      const timeout = deadline.aborted || (error instanceof DOMException && error.name === "AbortError");
      await finish(timeout ? "timeout" : "denied");
      return respond(timeout ? 503 : 400, { error: timeout ? "REQUEST_UNAVAILABLE" : "INVALID_REQUEST" });
    }
    if (!input) { await finish("denied"); return respond(400, { error: "INVALID_REQUEST" }); }
    const digest = await capabilityDigest(input.capability);
    const args = { p_ticket: ticket, p_digest: digest, p_action: input.action, p_method: input.action === "create" ? input.paymentMethod : null };
    const binding = await call("public_walkin_bind", args, 1000);
    if (binding.error || binding.data?.status !== "allowed") {
      await finish("unavailable");
      return !binding.error && binding.data?.status === "denied" ? throttled() : respond(503, { error: "REQUEST_UNAVAILABLE" });
    }
    if (deadline.aborted) return respond(503, { error: "REQUEST_UNAVAILABLE" });
    dispatched = true;
    const { data, error } = await call("public_walkin_execute", args, 5000);
    if (error) {
      const limited = error.code === "P0001" && error.message === "WALKIN_RATE_LIMITED";
      await observe(limited ? "denied" : error.code === "57014" ? "timeout" : "unavailable");
      return limited ? throttled() : respond(503, { error: "REQUEST_UNAVAILABLE" });
    }
    const result = recoveryResponse(data, input);
    return result ? respond(result.status, result.body) : respond(503, { error: "REQUEST_UNAVAILABLE" });
  } catch {
    if (dispatched) await observe("unavailable"); else await finish("unavailable");
    return respond(503, { error: "REQUEST_UNAVAILABLE" });
  }
}));
