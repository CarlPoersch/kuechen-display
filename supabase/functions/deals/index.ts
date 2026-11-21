// ============================================================
// Edge Function "deals": gute Angebote nach deinen Stichwörtern.
//   GET  .../deals/catalog                         Vorschläge (Stichwörter)
//   POST .../deals/match   { watch, min }          Treffer je Stichwort + heiße Deals
//   GET  .../deals/preview?t=&alts=&not=&max=&min= Vorschau für ein Stichwort
// Quelle: RSS-Feeds von mydealz (allgemein, Kategorien und Themen-Gruppen).
// Alles, was gelesen wird, landet 7 Tage in deal_cache – so bleiben auch
// ältere Treffer sichtbar, obwohl jeder Feed nur die letzten 30 Deals enthält.
// Stichwörter passen auch ungefähr: Groß/klein, Umlaute (ä/ae), Mehrzahl,
// Wortteile (Saugroboter ↔ Roboter), Tippfehler und Synonyme der Vorschläge.
// ============================================================

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-kueche-key, content-type, authorization, apikey",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const SUPA = Deno.env.get("SUPABASE_URL") ?? "";
const SVC = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const MD = "https://www.mydealz.de/";
const UA = { "User-Agent": "Mozilla/5.0 (compatible; Hubert/1.0; privates Wanddisplay)", "Accept": "application/rss+xml, application/xml, text/xml" };

// ---------- Zugang: Haushalts-Schlüssel (Web) oder Login (App) ----------
const good = new Map<string, number>();
async function keyOk(key: string | null): Promise<boolean> {
  if (!key) return false;
  const seen = good.get(key);
  if (seen && Date.now() - seen < 10 * 60_000) return true;
  const r = await fetch(SUPA + "/rest/v1/rpc/kueche_check", {
    method: "POST", headers: { "Content-Type": "application/json", apikey: SVC, Authorization: "Bearer " + SVC },
    body: JSON.stringify({ p_key: key }),
  });
  const ok = r.ok && (await r.json()) === true;
  if (ok) good.set(key, Date.now());
  return ok;
}
async function userOk(auth: string | null): Promise<boolean> {
  if (!auth || !auth.startsWith("Bearer ")) return false;
  const seen = good.get(auth);
  if (seen && Date.now() - seen < 5 * 60_000) return true;
  const r = await fetch(SUPA + "/auth/v1/user", { headers: { apikey: SVC, Authorization: auth } });
  if (r.ok) good.set(auth, Date.now());
  return r.ok;
}

// ============================================================
// VORSCHLÄGE – wie die Grundliste beim Einkaufszettel: sofort nutzbar,
// mit Synonymen (alts), Ausschlüssen (not) und passenden mydealz-Gruppen (g)
// ============================================================
type Preset = { t: string; alts?: string[]; not?: string[]; g?: string[] };
const CATALOG: { name: string; emoji: string; items: Preset[] }[] = [
  { name: "Technik", emoji: "💻", items: [
    { t: "Kopfhörer", alts: ["AirPods", "Earbuds", "Ohrhörer", "In-Ear-Kopfhörer", "Over-Ear-Kopfhörer", "Headphones", "Headset", "True Wireless", "Bose QuietComfort"], not: ["Ersatzpolster"], g: ["kopfhoerer", "airpods"] },
    { t: "AirPods", g: ["airpods"] },
    { t: "Fernseher", alts: ["TV", "Smart TV", "OLED", "QLED", "Fernsehgerät"], not: ["Wandhalterung", "Halterung", "Fernbedienung", "Antenne"], g: ["fernseher"] },
    { t: "Smartphone", alts: ["Handy", "iPhone", "Galaxy", "Pixel"], not: ["Hülle", "Panzerglas", "Schutzfolie", "Displayschutz", "Tarif", "Vertrag", "Ladekabel"], g: ["smartphone", "iphone"] },
    { t: "iPhone", not: ["Hülle", "Panzerglas", "Schutzfolie", "Displayschutz", "Ladekabel"], g: ["iphone"] },
    { t: "Laptop", alts: ["Notebook", "MacBook", "Ultrabook", "Chromebook"], not: ["Tasche", "Hülle", "Ständer", "Rucksack"], g: ["laptop"] },
    { t: "Tablet", alts: ["iPad", "Galaxy Tab"], not: ["Hülle", "Panzerglas", "Schutzfolie"], g: ["tablet", "ipad"] },
    { t: "Smartwatch", alts: ["Apple Watch", "Galaxy Watch", "Garmin", "Fitnesstracker"], not: ["Armband", "Schutzfolie"], g: ["smartwatch"] },
    { t: "Monitor", alts: ["Bildschirm"], not: ["Monitorarm", "Halterung"], g: ["monitor"] },
  ] },
  { name: "Gaming", emoji: "🎮", items: [
    { t: "PlayStation 5", alts: ["PS5", "DualSense"], g: ["playstation-5", "playstation"] },
    { t: "Nintendo Switch", alts: ["Switch 2", "Switch OLED"], g: ["nintendo-switch", "nintendo"] },
    { t: "Xbox", alts: ["Game Pass"], g: ["xbox"] },
    { t: "Gratis-Spiele", alts: ["kostenlos Spiel", "gratis Spiel", "Epic Games", "Prime Gaming", "free to keep"], g: ["freebies", "gaming"] },
  ] },
  { name: "Haushalt", emoji: "🏠", items: [
    { t: "Staubsauger", alts: ["Saugroboter", "Akkusauger", "Wischroboter", "Dyson", "Roborock"], not: ["Staubsaugerbeutel", "Beutel", "Filter", "Ersatzteil", "Zubehör"], g: ["staubsauger", "saugroboter"] },
    { t: "Kaffeevollautomat", alts: ["Kaffeemaschine", "Siebträger", "Espressomaschine", "Nespresso", "Dolce Gusto"], not: ["Entkalker", "Reinigungstabletten"], g: ["kaffee"] },
    { t: "Heißluftfritteuse", alts: ["Airfryer", "Air Fryer", "Ninja Foodi"] },
    { t: "Küchenmaschine", alts: ["Thermomix", "Monsieur Cuisine", "KitchenAid", "Standmixer"] },
    { t: "Werkzeug", alts: ["Akkuschrauber", "Bohrmaschine", "Makita", "Werkzeugkoffer"], g: ["werkzeug"] },
  ] },
  { name: "Einkauf", emoji: "🛒", items: [
    { t: "Kaffee", alts: ["Kaffeebohnen", "Espresso", "Kaffeepads", "Kaffeekapseln"], not: ["Kaffeemaschine", "Kaffeevollautomat", "Tasse", "Becher"], g: ["kaffee"] },
    { t: "Wein", alts: ["Rotwein", "Weißwein", "Sekt", "Champagner", "Prosecco"], not: ["Weinglas", "Weingläser", "Weinkühlschrank"], g: ["wein"] },
    { t: "Bier", alts: ["Kasten Bier", "Craft Beer"], not: ["Bierglas", "Biergläser"], g: ["bier"] },
    { t: "Süßigkeiten", alts: ["Schokolade", "Milka", "Lindt", "Haribo", "Ritter Sport"], g: ["lebensmittel"] },
    { t: "Waschmittel", alts: ["Persil", "Ariel", "Weichspüler", "Spülmaschinentabs", "Geschirrtabs"], g: ["drogerie"] },
  ] },
  { name: "Freizeit & Familie", emoji: "🎁", items: [
    { t: "Lego", g: ["lego"] },
    { t: "Spielzeug", alts: ["Playmobil", "Carrera", "Ravensburger", "Puzzle", "Brettspiel"], g: ["spielzeug"] },
    { t: "Reisen", alts: ["Urlaub", "Hotel", "Flug", "Flüge", "Städtetrip", "Kurzurlaub"], g: ["reisen"] },
    { t: "Kino & Streaming", alts: ["Kinoticket", "Netflix", "Disney+", "Spotify", "DAZN", "WOW"], g: ["kultur-freizeit"] },
    { t: "Fahrrad", alts: ["E-Bike", "Ebike", "Pedelec", "Fahrradhelm"] },
  ] },
  { name: "Mode & Beauty", emoji: "👟", items: [
    { t: "Sneaker", alts: ["Turnschuhe", "Laufschuhe", "Nike", "Adidas", "New Balance"], g: ["sneaker", "schuhe"] },
    { t: "Winterjacke", alts: ["Daunenjacke", "Parka", "Steppjacke"], g: ["winterjacken", "jacken"] },
    { t: "Parfum", alts: ["Eau de Parfum", "Eau de Toilette"], g: ["parfum", "beauty"] },
  ] },
  { name: "Händler & Aktionen", emoji: "🏪", items: [
    { t: "Black Friday", alts: ["Black Week", "Cyber Monday"] },
    { t: "Lidl" }, { t: "Aldi" }, { t: "IKEA" }, { t: "dm" }, { t: "Rossmann" },
  ] },
];
const PRESETS = CATALOG.flatMap((c) => c.items);

// ============================================================
// UNGEFÄHRES PASSEN
// ============================================================
/** Klein, ohne Akzente; Umlaute und ihre Ersatzschreibung (ae/oe/ue) gelten gleich */
const fold = (s: string) => s.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/ß/g, "ss")
  .replace(/ae/g, "a").replace(/oe/g, "o").replace(/ue/g, "u");
/** Wörter; Zahlen werden abgetrennt (PS5 → ps 5) */
const toks = (s: string) => fold(s).replace(/([a-z])(\d)/g, "$1 $2").replace(/(\d)([a-z])/g, "$1 $2")
  .split(/[^a-z0-9]+/).filter(Boolean);
const STOP = new Set(["und", "fur", "mit", "der", "die", "das", "von", "im", "in", "the", "and", "for", "de"]);
/** Grobe Grundform: Mehrzahl und Endungen ab (Kopfhörern → kopfhor, Winterjacken → winterjack) */
function stem(t: string): string {
  if (/^\d+$/.test(t)) return t;
  for (let i = 0; i < 2; i++) {
    const m = t.length > 5 ? /(en|er|es|n|s|e)$/.exec(t) : null;
    if (!m) break;
    t = t.slice(0, -m[1].length);
  }
  return t;
}
function lev(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) return max + 1;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    let best = i;
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      best = Math.min(best, cur[j]);
    }
    if (best > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}
/** Passt ein Suchwort auf ein Wort im Titel? */
function tokOk(k: string, t: string): boolean {
  if (k === t) return true;
  if (/^\d+$/.test(k) || /^\d+$/.test(t)) return false;
  if (k.length >= 4 && t.startsWith(k)) return true;              // Lego → Legosteine
  if (k.length >= 5 && t.includes(k)) return true;                // Sauger → Akkusauger
  if (k.length >= 6 && k[0] === t[0]) return lev(k, t, k.length >= 9 ? 2 : 1) <= (k.length >= 9 ? 2 : 1);   // Tippfehler
  return false;
}
type Prepared = { words: string[]; joined: string[] };
function prepare(text: string): Prepared {
  const w = toks(text).map(stem);
  const joined: string[] = [];
  for (let i = 0; i + 1 < w.length; i++) if (w[i].length >= 2 && w[i + 1].length >= 2) joined.push(stem(w[i] + w[i + 1]));   // „Air Pods“ ↔ „AirPods“
  return { words: w, joined };
}
/** Passt eine Suchphrase (alle Wörter, Reihenfolge egal) auf den Text? */
function phraseOk(phrase: string, p: Prepared): boolean {
  const raw = toks(phrase).filter((x) => !STOP.has(x));
  if (!raw.length) return false;
  const ks = raw.map(stem);
  // Zusammengezogene Wortpaare nur für längere Suchwörter (sonst passt „ear“ auf „e aroma“)
  const hit = (k: string) => p.words.some((t) => tokOk(k, t)) || (k.length >= 5 && p.joined.some((t) => tokOk(k, t)));
  if (ks.every(hit)) return true;
  if (raw.length > 1) {                                             // „Play Station“ ↔ „PlayStation“
    const c = stem(raw.join(""));
    if (c.length >= 5 && hit(c)) return true;
  }
  return false;
}
/** Gleicher Begriff? (für Vorschläge: „kopfhoerer“, „Kopfhörern“ → „Kopfhörer“) */
function same(a: string, b: string): boolean {
  const x = stem(toks(a).join("")), y = stem(toks(b).join(""));
  return x === y || (x.length >= 5 && lev(x, y, 1) <= 1);
}

type Watch = { t: string; alts?: string[]; not?: string[]; max?: number | null };
type Rule = { t: string; phrases: string[]; not: string[]; max?: number | null; groups: string[]; std: { alts: string[]; not: string[] } };
type Item = Deal & { prep: Prepared; tprep: Prepared };
const slug = (s: string) => s.toLowerCase().replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss")
  .normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
function rule(w: Watch): Rule {
  const p = PRESETS.find((x) => same(x.t, w.t));
  const alts = (w.alts ?? []).filter(Boolean), not = (w.not ?? []).filter(Boolean);
  const groups = [...(p?.g ?? [slug(w.t)])];
  for (const a of alts.slice(0, 2)) if (slug(a).length >= 3) groups.push(slug(a));
  // Ausschlüsse greifen nicht, wenn das Stichwort selbst danach fragt („Panzerglas“ sucht Panzerglas)
  const self = prepare(w.t);
  return {
    t: w.t, phrases: [w.t, ...(p?.alts ?? []), ...alts], not: [...(p?.not ?? []), ...not].filter((n) => !phraseOk(n, self)), max: w.max ?? null,
    groups: [...new Set(groups.filter((g) => g.length >= 2))], std: { alts: p?.alts ?? [], not: p?.not ?? [] },
  };
}

// ============================================================
// FEEDS LESEN
// ============================================================
type Deal = { id: string; t: string; m?: string; p?: number | null; pt?: string; temp?: number; cat?: string; img?: string; u: string; x?: string; d: string };
function decode(s: string): string {
  return s.replace(/<!\[CDATA\[|\]\]>/g, "").replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(+d)).replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&");
}
function price(s: string | undefined): number | null {
  if (!s) return null;
  if (/kostenlos|gratis|free/i.test(s)) return 0;
  const m = /(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?/.exec(s);
  return m ? parseFloat(m[1].replace(/\./g, "") + (m[2] ? "." + m[2] : "")) : null;
}
function parseRss(xml: string): Deal[] {
  const out: Deal[] = [];
  for (const it of xml.split("<item>").slice(1)) {
    const get = (re: RegExp) => { const m = re.exec(it); return m ? decode(m[1]).trim() : undefined; };
    const rawTitle = get(/<title>([\s\S]*?)<\/title>/);
    const u = get(/<link>([\s\S]*?)<\/link>/);
    if (!rawTitle || !u) continue;
    const tm = /^(-?\d+)°\s*-\s*/.exec(rawTitle);
    const t = tm ? rawTitle.slice(tm[0].length) : rawTitle;
    const merchant = /<pepper:merchant([^>]*)\/?>/.exec(it)?.[1] ?? "";
    const m = /name="([^"]*)"/.exec(merchant)?.[1];
    const pt = /price="([^"]*)"/.exec(merchant)?.[1];
    const id = /-(\d{5,})(?:[/?#]|$)/.exec(u)?.[1];
    const desc = get(/<description>([\s\S]*?)<\/description>/) ?? "";
    const x = desc.replace(/^<strong>[\s\S]*?<\/strong>/, "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim().slice(0, 260);
    const pub = get(/<pubDate>([\s\S]*?)<\/pubDate>/);
    const d = pub ? new Date(pub) : new Date();
    let p = price(pt);
    if (p === null) { const tp = /(\d+(?:[.,]\d{1,2})?)\s?€/.exec(t); p = tp ? price(tp[1]) : null; }
    out.push({
      id: id ? "md" + id : u, t, m: m ? decode(m) : undefined, p, pt: pt ? decode(pt) : undefined,
      temp: tm ? +tm[1] : undefined, cat: get(/<category>([\s\S]*?)<\/category>/), u, x: x || undefined,
      img: /<media:content[^>]*url="([^"]+)"/.exec(it)?.[1], d: isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString(),
    });
  }
  return out;
}

const BASE = ["rss/hot", "rss/new", "rss/deals",
  ...["elektronik", "gaming", "family-kids", "home-living", "lebensmittel", "supermarkt", "drogerie", "beauty",
    "kultur-freizeit", "reisen", "auto-motorrad", "garten-baumarkt", "freebies", "sport"].map((g) => "rss/gruppe/" + g)];
let baseAt = 0, cleanAt = 0;
const groupOk = new Map<string, { ok: boolean; at: number }>();
const groupAt = new Map<string, number>();

async function fetchFeed(path: string): Promise<Deal[]> {
  const r = await fetch(MD + path, { headers: UA });
  if (r.status === 404) throw new Error("404");
  if (!r.ok) throw new Error("HTTP " + r.status);
  return parseRss(await r.text());
}

async function rest(method: string, path: string, body?: unknown, extra: Record<string, string> = {}) {
  const r = await fetch(SUPA + "/rest/v1/" + path, {
    method, headers: { apikey: SVC, Authorization: "Bearer " + SVC, "Content-Type": "application/json", ...extra },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!r.ok) throw new Error("DB " + r.status + " " + (await r.text()).slice(0, 200));
  return r;
}

/** Feeds neu lesen (allgemeine alle 5 Min., Themen-Gruppen der Stichwörter alle 10 Min.) und speichern */
async function refresh(groups: string[]) {
  const now = Date.now();
  const paths: string[] = [];
  if (now - baseAt > 5 * 60_000) { baseAt = now; paths.push(...BASE); }
  for (const g of groups.slice(0, 30)) {
    const st = groupOk.get(g);
    if (st && !st.ok && now - st.at < 24 * 3600_000) continue;          // gibt es nicht – einen Tag nicht mehr fragen
    if (now - (groupAt.get(g) ?? 0) < 10 * 60_000) continue;
    groupAt.set(g, now);
    if (!paths.includes("rss/gruppe/" + g)) paths.push("rss/gruppe/" + g);
  }
  if (!paths.length) return;
  const lists = await Promise.all(paths.map(async (p) => {
    const g = p.startsWith("rss/gruppe/") ? p.slice(11) : null;
    try {
      const d = await fetchFeed(p);
      if (g) groupOk.set(g, { ok: true, at: now });
      return d;
    } catch (e) {
      if (g && String(e).includes("404")) groupOk.set(g, { ok: false, at: now });
      else console.error("Feed", p, String(e));
      return [] as Deal[];
    }
  }));
  // Nur die Trend-Feeds nennen die Temperatur – fehlende Werte überschreiben nie vorhandene
  const byId = new Map<string, Deal>();
  for (const d of lists.flat()) {
    const prev = byId.get(d.id);
    const merged: any = { ...(prev ?? {}) };
    for (const [k, v] of Object.entries(d)) if (v !== undefined && v !== null) merged[k] = v;
    byId.set(d.id, merged);
  }
  if (!byId.size) return;
  const row = (d: Deal) => ({
    id: d.id, title: d.t, merchant: d.m ?? null, price: d.p ?? null, price_text: d.pt ?? null,
    cat: d.cat ?? null, img: d.img ?? null, url: d.u, snippet: d.x ?? null, pub: d.d, seen: new Date().toISOString(),
  });
  const withTemp = [...byId.values()].filter((d) => d.temp !== undefined).map((d) => ({ ...row(d), temp: d.temp }));
  const noTemp = [...byId.values()].filter((d) => d.temp === undefined).map(row);
  const cols = "id,title,merchant,price,price_text,cat,img,url,snippet,pub,seen";
  try {
    const up = { Prefer: "resolution=merge-duplicates,return=minimal" };
    if (noTemp.length) await rest("POST", "deal_cache?on_conflict=id&columns=" + cols, noTemp, up);
    if (withTemp.length) await rest("POST", "deal_cache?on_conflict=id&columns=" + cols + ",temp", withTemp, up);
    if (now - cleanAt > 3600_000) {
      cleanAt = now;
      await rest("DELETE", "deal_cache?pub=lt." + new Date(now - 10 * 24 * 3600_000).toISOString(), undefined, { Prefer: "return=minimal" });
    }
  } catch (e) { console.error("Speichern", String(e)); }
  memo = null;
}

/** Alle Deals der letzten 7 Tage (1 Min. im Speicher) */
let memo: { at: number; deals: Item[] } | null = null;
async function load() {
  if (memo && Date.now() - memo.at < 60_000) return memo.deals;
  const since = new Date(Date.now() - 7 * 24 * 3600_000).toISOString();
  const rows: any[] = [];
  for (let off = 0; off < 6000; off += 1000) {
    const r = await rest("GET", "deal_cache?select=*&pub=gte." + since + "&order=pub.desc&limit=1000&offset=" + off);
    const page = await r.json();
    rows.push(...page);
    if (page.length < 1000) break;
  }
  const deals = rows.map((r) => {
    const d: Deal = { id: r.id, t: r.title, m: r.merchant ?? undefined, p: r.price === null ? null : Number(r.price), pt: r.price_text ?? undefined,
      temp: r.temp ?? undefined, cat: r.cat ?? undefined, img: r.img ?? undefined, u: r.url, x: r.snippet ?? undefined, d: new Date(r.pub).toISOString() };
    return { ...d, prep: prepare([d.t, d.m ?? "", d.cat ?? ""].join(" ")), tprep: prepare(d.t) };
  });
  memo = { at: Date.now(), deals };
  return deals;
}

function matches(r: Rule, d: Item, min: number): boolean {
  if ((d.temp ?? 0) < min) return false;
  if (r.max !== null && r.max !== undefined && (d.p === null || d.p === undefined || d.p > r.max)) return false;
  if (!r.phrases.some((p) => phraseOk(p, d.prep))) return false;
  // Ausschlüsse nur gegen den Titel
  return !r.not.some((n) => phraseOk(n, d.tprep));
}
const strip = ({ prep: _p, tprep: _t, ...d }: Item): Deal => d;

async function match(watch: Watch[], min: number) {
  const rules = watch.slice(0, 40).map(rule);
  await refresh(rules.flatMap((r) => r.groups));
  const all = await load();
  const groups = rules.map((r) => {
    const hit = all.filter((d) => matches(r, d, min));
    return { t: r.t, n: hit.length, deals: hit.slice(0, 40).map(strip) };
  });
  const recent = Date.now() - 36 * 3600_000;
  const hot = all.filter((d) => (d.temp ?? 0) >= 200 && Date.parse(d.d) > recent)
    .sort((a, b) => (b.temp ?? 0) - (a.temp ?? 0)).slice(0, 15).map(strip);
  return { at: new Date().toISOString(), total: all.length, groups, hot };
}

async function preview(w: Watch, min: number) {
  const r = rule(w);
  await refresh(r.groups);
  const hit = (await load()).filter((d) => matches(r, d, min));
  return { n: hit.length, deals: hit.slice(0, 8).map(strip), std: r.std };
}

// ============================================================
const clean = (s: unknown, n = 60) => String(s ?? "").replace(/\s+/g, " ").trim().slice(0, n);
const list = (v: unknown) => (Array.isArray(v) ? v : typeof v === "string" ? v.split(",") : []).map((x) => clean(x)).filter(Boolean).slice(0, 15);
const num = (v: unknown) => { const n = typeof v === "number" ? v : parseFloat(String(v ?? "").replace(",", ".")); return isFinite(n) && n > 0 ? n : null; };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const url = new URL(req.url);
  const what = url.pathname.split("/").filter(Boolean).pop() ?? "";
  if (!["catalog", "match", "preview"].includes(what)) return new Response("Unbekannte Abfrage", { status: 404, headers: cors });
  if (!(await keyOk(req.headers.get("x-kueche-key"))) && !(await userOk(req.headers.get("authorization")))) {
    return new Response("Kein Zugang", { status: 401, headers: cors });
  }
  let body: unknown;
  try {
    if (what === "catalog") {
      body = CATALOG.map((c) => ({ name: c.name, emoji: c.emoji, items: c.items.map((i) => ({ t: i.t, alts: i.alts ?? [], not: i.not ?? [] })) }));
    } else if (what === "preview") {
      const q = url.searchParams;
      body = await preview({ t: clean(q.get("t")), alts: list(q.get("alts")), not: list(q.get("not")), max: num(q.get("max")) }, Number(q.get("min") ?? 0) || 0);
    } else {
      const j: any = req.method === "POST" ? await req.json() : {};
      const watch: Watch[] = (Array.isArray(j.watch) ? j.watch : []).map((w: any) => ({ t: clean(w?.t), alts: list(w?.alts), not: list(w?.not), max: num(w?.max) }))
        .filter((w: Watch) => w.t.length >= 2);
      body = await match(watch, Number(j.min ?? 0) || 0);
    }
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify(body), { headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
});
