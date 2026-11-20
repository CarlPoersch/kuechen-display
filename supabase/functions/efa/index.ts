// ============================================================
// Edge Function "efa": Vermittler für die Bayern-Fahrplanauskunft.
//
// Warum: Browser dürfen die Fahrplan-Daten nicht direkt abfragen (CORS).
// Diese Funktion holt sie und reicht sie mit passenden CORS-Headern weiter,
// genau wie server.py im lokalen Betrieb.
//
// Schutz: Nur mit gültigem Haushalts-Schlüssel (Header "x-kueche-key",
// geprüft über kueche_check) oder Login der nativen App (Bearer-Token).
// Aufruf: GET <supabase-url>/functions/v1/efa/XML_DM_REQUEST?...
// ============================================================
const EFA_BASE = "https://mobile.defas-fgi.de/beg/";
const ALLOWED = new Set(["XML_DM_REQUEST", "XML_TRIP_REQUEST2", "XML_STOPFINDER_REQUEST", "XML_COORD_REQUEST"]);
const CACHE_MS = 30_000; // gleiche Abfrage innerhalb von 30 s nicht erneut senden

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-kueche-key, content-type, authorization, apikey",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const goodKeys = new Map<string, number>();            // geprüfte Schlüssel (10 min merken)
const cache = new Map<string, { at: number; body: string }>();

async function keyOk(key: string | null): Promise<boolean> {
  if (!key) return false;
  const seen = goodKeys.get(key);
  if (seen && Date.now() - seen < 10 * 60_000) return true;
  const url = Deno.env.get("SUPABASE_URL") + "/rest/v1/rpc/kueche_check";
  const svc = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const r = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: svc, Authorization: "Bearer " + svc },
    body: JSON.stringify({ p_key: key }),
  });
  const ok = r.ok && (await r.json()) === true;
  if (ok) goodKeys.set(key, Date.now());
  return ok;
}

// Oder: angemeldeter Nutzer der nativen App (Supabase-Login)
async function userOk(auth: string | null): Promise<boolean> {
  if (!auth || !auth.startsWith("Bearer ")) return false;
  const seen = goodKeys.get(auth);
  if (seen && Date.now() - seen < 5 * 60_000) return true;
  const svc = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const r = await fetch(Deno.env.get("SUPABASE_URL") + "/auth/v1/user", { headers: { apikey: svc, Authorization: auth } });
  if (r.ok) goodKeys.set(auth, Date.now());
  return r.ok;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });

  const url = new URL(req.url);
  const endpoint = url.pathname.split("/").filter(Boolean).pop() ?? "";
  if (!ALLOWED.has(endpoint)) {
    return new Response("Abfrage nicht erlaubt", { status: 403, headers: cors });
  }
  if (!(await keyOk(req.headers.get("x-kueche-key"))) && !(await userOk(req.headers.get("authorization")))) {
    return new Response("Falscher Haushalts-Schlüssel", { status: 401, headers: cors });
  }

  const target = EFA_BASE + endpoint + url.search;
  const hit = cache.get(target);
  let body: string;
  if (hit && Date.now() - hit.at < CACHE_MS) {
    body = hit.body;
  } else {
    try {
      const r = await fetch(target, { headers: { "User-Agent": "Kuechen-Display/1.0" } });
      if (!r.ok) throw new Error("HTTP " + r.status);
      body = await r.text();
    } catch (e) {
      console.error("EFA-Fehler", e);
      return new Response("Fahrplanauskunft nicht erreichbar", { status: 502, headers: cors });
    }
    cache.set(target, { at: Date.now(), body });
    // Alte Einträge aufräumen, damit der Speicher nicht wächst
    for (const [k, v] of cache) if (Date.now() - v.at > 5 * 60_000) cache.delete(k);
  }
  return new Response(body, {
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
});
