// ============================================================
// Edge Function "kitchen": Helfer für die Küche der nativen App.
//
//   GET  /kitchen/import?u=<Rezept-Link>      (angemeldet: Authorization: Bearer <Login>)
//        Liest das Rezept von der Webseite. Fast alle Rezeptseiten (Chefkoch,
//        Lecker, EatSmarter, Blogs …) beschreiben ihr Rezept maschinenlesbar
//        (schema.org/Recipe). Das wird in Huberts Rezeptformat umgewandelt.
//
//   GET  /kitchen/add?t=<Kurzbefehl-Schlüssel>&item=Milch und Eier
//        Für den Siri-Kurzbefehl: setzt Artikel auf die Einkaufsliste.
//        Der Schlüssel liegt in der Datenbank nur als sha256-Hash.
// ============================================================

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const SUPA = Deno.env.get("SUPABASE_URL") ?? "";
const SVC = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json; charset=utf-8" } });
const text = (body: string, status = 200) =>
  new Response(body, { status, headers: { ...cors, "Content-Type": "text/plain; charset=utf-8" } });

async function userOk(auth: string | null): Promise<boolean> {
  if (!auth || !auth.startsWith("Bearer ")) return false;
  const r = await fetch(SUPA + "/auth/v1/user", { headers: { apikey: SVC, Authorization: auth } });
  return r.ok;
}

// ---------------- Rezept-Import ----------------

function decode(s: string): string {
  return s.replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&quot;/g, '"')
    .replace(/&#0?39;|&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n)).replace(/\s+/g, " ").trim();
}

// deno-lint-ignore no-explicit-any
function findRecipe(node: any): any {
  if (!node || typeof node !== "object") return null;
  if (Array.isArray(node)) { for (const n of node) { const r = findRecipe(n); if (r) return r; } return null; }
  const t = node["@type"];
  if (t === "Recipe" || (Array.isArray(t) && t.includes("Recipe"))) return node;
  for (const k of ["@graph", "mainEntity", "itemListElement"]) { const r = findRecipe(node[k]); if (r) return r; }
  return null;
}

function minutesOf(iso?: string): number | null {
  const m = /P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?/.exec(iso ?? "");
  if (!m) return null;
  const v = (+(m[1] ?? 0)) * 1440 + (+(m[2] ?? 0)) * 60 + (+(m[3] ?? 0));
  return v > 0 ? v : null;
}

const UNIT = "(?:g|kg|mg|ml|l|cl|dl|el|tl|esslöffel|teelöffel|prise[n]?|msp\\.?|stück|stk\\.?|bund|dose[n]?|zehe[n]?|becher|pck\\.?|päckchen|packung(?:en)?|tasse[n]?|scheibe[n]?|handvoll|glas|gläser|zweig(?:e)?|blatt|blätter|kugel[n]?)";
const AMOUNT = new RegExp("^((?:ca\\.\\s*)?[\\d½¼¾⅓⅔.,/–-]+(?:\\s*[\\d½¼¾⅓⅔.,/–-]+)?(?:\\s*" + UNIT + "\\b\\.?)?)\\s+(.+)$", "i");

function ingredient(s: string) {
  const t = decode(s);
  const m = AMOUNT.exec(t);
  return m ? { amount: m[1].trim(), name: m[2].trim() } : { amount: "", name: t };
}

// deno-lint-ignore no-explicit-any
function steps(ins: any): { text: string; minutes?: number }[] {
  const out: { text: string; minutes?: number }[] = [];
  // deno-lint-ignore no-explicit-any
  const add = (x: any) => {
    if (!x) return;
    if (typeof x === "string") {
      for (const part of decode(x).split(/(?<=\.)\s+(?=[A-ZÄÖÜ])|\n/)) if (part.trim()) push(part.trim());
    } else if (Array.isArray(x)) x.forEach(add);
    else if (x["@type"] === "HowToSection") add(x.itemListElement);
    else if (x.text) push(decode(String(x.text)));
    else if (x.name) push(decode(String(x.name)));
  };
  const push = (t: string) => {
    const m = /(\d+)\s*(?:[–-]\s*\d+\s*)?(?:Min\.?|Minuten)/i.exec(t);
    out.push(m ? { text: t, minutes: +m[1] } : { text: t });
  };
  add(ins);
  return out.slice(0, 40);
}

const ICONS: [RegExp, string][] = [
  [/nudel|pasta|spaghetti|lasagne|penne/i, "🍝"], [/suppe|eintopf/i, "🍲"], [/curry/i, "🍛"], [/salat/i, "🥗"],
  [/kuchen|torte|muffin/i, "🍰"], [/pizza/i, "🍕"], [/burger/i, "🍔"], [/hähnchen|huhn|chicken/i, "🍗"],
  [/fisch|lachs/i, "🐟"], [/reis|risotto/i, "🍚"], [/brot|brötchen/i, "🥖"], [/kartoffel|pommes/i, "🥔"],
];

async function importRecipe(u: string) {
  const url = new URL(u);
  if (!/^https?:$/.test(url.protocol)) throw new Error("Nur Web-Links");
  const r = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 (iPad; CPU OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1", "Accept-Language": "de-DE,de" } });
  if (!r.ok) throw new Error("Seite nicht erreichbar (" + r.status + ")");
  const html = await r.text();
  // deno-lint-ignore no-explicit-any
  let rec: any = null;
  for (const m of html.matchAll(/<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)) {
    try { rec = findRecipe(JSON.parse(m[1].trim())); } catch { /* nächster Block */ }
    if (rec) break;
  }
  if (!rec) throw new Error("Auf der Seite wurde kein Rezept gefunden");
  const title = decode(String(rec.name ?? "Rezept"));
  const yieldText = String(Array.isArray(rec.recipeYield) ? rec.recipeYield[0] : rec.recipeYield ?? "");
  const servings = Math.min(20, Math.max(1, parseInt(yieldText) || 2));
  const mins = minutesOf(rec.totalTime) ?? ((minutesOf(rec.prepTime) ?? 0) + (minutesOf(rec.cookTime) ?? 0) || null);
  const cuisine = Array.isArray(rec.recipeCuisine) ? rec.recipeCuisine[0] : rec.recipeCuisine;
  return {
    id: "", title, icon: ICONS.find(([re]) => re.test(title))?.[1] ?? "🍽️",
    cuisine: cuisine ? decode(String(cuisine)) : url.hostname.replace(/^www\./, ""),
    servings, time: mins ? "ca. " + mins + " Min." : null,
    ingredients: (rec.recipeIngredient ?? rec.ingredients ?? []).map((s: string) => ingredient(String(s))),
    steps: steps(rec.recipeInstructions),
    source: url.toString(),
  };
}

// ---------------- Siri: Einkaufsliste ----------------

async function sha256(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function addItems(token: string, itemText: string) {
  const h = await sha256(token);
  const q = await fetch(SUPA + "/rest/v1/kitchen_tokens?select=household_id&token_hash=eq." + h,
    { headers: { apikey: SVC, Authorization: "Bearer " + SVC } });
  const rows = await q.json();
  if (!Array.isArray(rows) || !rows.length) return text("Der Kurzbefehl ist nicht mehr gültig. Richte ihn in Hubert neu ein.", 401);
  const names = itemText.split(/,|\bund\b|\n/i).map((s) => s.trim()).filter(Boolean)
    .map((s) => s.charAt(0).toUpperCase() + s.slice(1)).slice(0, 20);
  if (!names.length) return text("Was soll auf die Liste?", 400);
  const ins = await fetch(SUPA + "/rest/v1/kitchen_items", {
    method: "POST",
    headers: { apikey: SVC, Authorization: "Bearer " + SVC, "Content-Type": "application/json", Prefer: "return=minimal" },
    body: JSON.stringify(names.map((name) => ({ household_id: rows[0].household_id, kind: "shop", name }))),
  });
  if (!ins.ok) return text("Konnte nicht speichern.", 500);
  const list = names.length === 1 ? names[0] : names.slice(0, -1).join(", ") + " und " + names[names.length - 1];
  return text(list + (names.length === 1 ? " steht" : " stehen") + " auf der Einkaufsliste.");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const u = new URL(req.url);
  const what = u.pathname.split("/").filter(Boolean).pop() ?? "";
  try {
    if (what === "add") {
      let item = u.searchParams.get("item") ?? "";
      if (req.method === "POST" && !item) {
        // Kurzbefehle schicken JSON ({"item": "..."}) oder ein Formular (item=...)
        const raw = await req.text();
        try { item = String(JSON.parse(raw).item ?? ""); }
        catch { item = new URLSearchParams(raw).get("item") ?? raw; }
      }
      return await addItems(u.searchParams.get("t") ?? "", item);
    }
    if (what === "import") {
      if (!(await userOk(req.headers.get("authorization")))) return json({ error: "Nicht angemeldet" }, 401);
      return json(await importRecipe(u.searchParams.get("u") ?? ""));
    }
    return json({ error: "Unbekannte Abfrage" }, 404);
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 400);
  }
});
