// ============================================================
// Edge Function "feeds": Live-Sport und News für Huberts "Heute"-Seite.
//
// Warum eine eigene Funktion:
//  - Tagesschau und heise erlauben keinen direkten Abruf aus dem Browser (CORS).
//  - Die Sport-Rohdaten von ESPN sind groß (mehrere MB je Abfrage). Hier werden
//    sie auf das Nötige eingedampft, damit das alte iPad flott bleibt.
//  - Quellen lassen sich später austauschen, ohne die App zu ändern.
//
// Aufrufe (immer mit Header "x-kueche-key"):
//   GET <supabase-url>/functions/v1/feeds/sport
//   GET <supabase-url>/functions/v1/feeds/news
//   GET <supabase-url>/functions/v1/feeds/match?lg=<liga>&id=<spiel>
//   GET <supabase-url>/functions/v1/feeds/article?u=<artikel-link>
// ============================================================

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-kueche-key, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};
const UA = { "User-Agent": "Hubert/1.0 (privates Wanddisplay)" };

// ---------- Haushalts-Schlüssel prüfen (wie bei "efa") ----------
const goodKeys = new Map<string, number>();
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

// ---------- Zwischenspeicher ----------
// Warum "stale": Fällt eine Quelle aus, liefern wir den letzten guten Stand
// weiter, statt einer Fehlermeldung.
const cache = new Map<string, { at: number; val: unknown }>();
async function cached<T>(key: string, ms: number, load: () => Promise<T>): Promise<T | null> {
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < ms) return hit.val as T;
  try {
    const val = await load();
    cache.set(key, { at: Date.now(), val });
    return val;
  } catch (e) {
    console.error("Quelle fehlgeschlagen:", key, String(e));
    return hit ? (hit.val as T) : null;
  }
}
async function getJson(url: string) {
  const r = await fetch(url, { headers: UA });
  if (!r.ok) throw new Error("HTTP " + r.status + " " + url);
  return await r.json();
}

// ============================================================
// SPORT
// ============================================================
const ESPN = "https://site.api.espn.com/apis/site/v2/sports/";
const BAYERN = "132";

// Welche Wettbewerbe, und wer davon gezeigt wird
//   bayern: nur Bayern-Spiele · all: alle · de: nur mit deutschem Verein · ger: nur Nationalmannschaft
const FOOTBALL: [string, string, "bayern" | "all" | "de" | "ger"][] = [
  ["ger.1", "Bundesliga", "bayern"],
  ["ger.dfb_pokal", "DFB-Pokal", "all"],
  ["ger.super_cup", "Supercup", "all"],
  ["uefa.champions", "Champions League", "all"],
  ["uefa.europa", "Europa League", "de"],
  ["uefa.europa.conf", "Conference League", "de"],
  ["uefa.super_cup", "UEFA-Supercup", "all"],
  ["fifa.cwc", "Klub-WM", "all"],
  ["fifa.friendly", "Testspiel", "ger"],
  ["uefa.nations", "Nations League", "ger"],
  ["fifa.worldq.uefa", "WM-Quali", "ger"],
  ["fifa.world", "WM", "ger"],
  ["uefa.euroq", "EM-Quali", "ger"],
  ["uefa.euro", "EM", "ger"],
];

// Deutsche Namen für häufige Teams (ESPN liefert Englisch)
const NAMES: Record<string, string> = {
  "Bayern Munich": "FC Bayern", "Germany": "Deutschland", "FC Cologne": "1. FC Köln",
  "Borussia Dortmund": "Dortmund", "Bayer Leverkusen": "Leverkusen", "Borussia Monchengladbach": "Gladbach",
  "Borussia Mönchengladbach": "Gladbach", "Eintracht Frankfurt": "Frankfurt", "VfB Stuttgart": "Stuttgart",
  "Hamburg SV": "HSV", "Werder Bremen": "Bremen", "SC Freiburg": "Freiburg", "TSG Hoffenheim": "Hoffenheim",
  "VfL Wolfsburg": "Wolfsburg", "Union Berlin": "Union Berlin", "FC Augsburg": "Augsburg", "Mainz": "Mainz 05",
  "France": "Frankreich", "Spain": "Spanien", "Italy": "Italien", "England": "England", "Netherlands": "Niederlande",
  "Belgium": "Belgien", "Austria": "Österreich", "Switzerland": "Schweiz", "Denmark": "Dänemark", "Poland": "Polen",
  "Czechia": "Tschechien", "Czech Republic": "Tschechien", "Hungary": "Ungarn", "Croatia": "Kroatien",
  "Turkey": "Türkei", "Türkiye": "Türkei", "Greece": "Griechenland", "Sweden": "Schweden", "Norway": "Norwegen",
  "Scotland": "Schottland", "Ukraine": "Ukraine", "Slovakia": "Slowakei", "Slovenia": "Slowenien", "Serbia": "Serbien",
  "Romania": "Rumänien", "Ireland": "Irland", "Republic of Ireland": "Irland", "Northern Ireland": "Nordirland",
  "Wales": "Wales", "Iceland": "Island", "Finland": "Finnland", "Luxembourg": "Luxemburg", "Georgia": "Georgien",
  "Bosnia-Herzegovina": "Bosnien-H.", "Argentina": "Argentinien", "Brazil": "Brasilien", "United States": "USA",
  "Mexico": "Mexiko", "Japan": "Japan", "Morocco": "Marokko", "Paris Saint-Germain": "Paris SG",
  "Internazionale": "Inter Mailand", "AC Milan": "AC Mailand", "Juventus": "Juventus", "Barcelona": "FC Barcelona",
  "Real Madrid": "Real Madrid", "Atletico Madrid": "Atlético", "Manchester City": "Man City",
  "Manchester United": "Man United", "Arsenal": "Arsenal", "Liverpool": "Liverpool", "Chelsea": "Chelsea",
};
const ROUNDS: Record<string, string> = {
  "Final": "Finale", "Semifinal": "Halbfinale", "Semifinals": "Halbfinale", "Quarterfinal": "Viertelfinale",
  "Quarterfinals": "Viertelfinale", "Round of 16": "Achtelfinale", "Group Stage": "Gruppenphase",
  "Round 1": "1. Runde", "Round 2": "2. Runde", "Round 3": "3. Runde", "Round 4": "Achtelfinale",
  "Round of 32": "3. Runde", "Round of 64": "2. Runde", "Round of 128": "1. Runde",
};
const de = (n: string) => NAMES[n] ?? n;

type Side = { n: string; c?: string; score?: string; win?: boolean; sets?: (number | string)[];
  tb?: (number | null)[]; r?: number };
type Match = {
  id: string; sport: "fb" | "tn"; comp: string; round?: string; date: string;
  state: "pre" | "in" | "post"; detail: string; a: Side; b: Side; prio: number;
  lg?: string; eid?: string; venue?: string; note?: string;
};

function inWindow(iso: string) {
  const t = Date.parse(iso), now = Date.now();
  return t > now - 36 * 3600_000 && t < now + 7 * 24 * 3600_000;
}

function fbDetail(st: any): string {
  const name = st?.type?.name ?? "";
  if (name === "STATUS_HALFTIME") return "Halbzeit";
  if (st?.type?.state === "in") return st.displayClock || "live";
  if (st?.type?.state === "post") {
    const sd = st.type.shortDetail || "";
    if (/AET/.test(sd)) return "n. V.";
    if (/Pen|PK/i.test(sd)) return "n. E.";
    if (/Postp/i.test(sd)) return "verschoben";
    return "Ende";
  }
  if (/Postp/i.test(name)) return "verschoben";
  return "";
}

async function germanClubIds(): Promise<Set<string>> {
  const ids = await cached("de-clubs", 24 * 3600_000, async () => {
    const out: string[] = [];
    for (const lg of ["ger.1", "ger.2"]) {
      const j = await getJson(ESPN + "soccer/" + lg + "/teams");
      for (const t of j.sports?.[0]?.leagues?.[0]?.teams ?? []) out.push(String(t.team.id));
    }
    return out;
  });
  return new Set(ids ?? [BAYERN]);
}

async function football(): Promise<Match[]> {
  const clubs = await germanClubIds();
  const lists = await Promise.all(FOOTBALL.map(async ([slug, label, who]) => {
    const j: any = await cached("fb:" + slug, 20_000, () => getJson(ESPN + "soccer/" + slug + "/scoreboard"));
    const out: Match[] = [];
    for (const ev of j?.events ?? []) {
      const c = ev.competitions?.[0];
      if (!c || !inWindow(ev.date)) continue;
      const home = c.competitors.find((x: any) => x.homeAway === "home") ?? c.competitors[0];
      const away = c.competitors.find((x: any) => x.homeAway === "away") ?? c.competitors[1];
      const ids = [String(home.team.id), String(away.team.id)];
      const names = [home.team.displayName, away.team.displayName];
      const bayern = ids.includes(BAYERN);
      const germany = names.includes("Germany");
      const deClub = ids.some((i) => clubs.has(i));
      if (who === "bayern" && !bayern) continue;
      if (who === "de" && !deClub) continue;
      if (who === "ger" && !germany) continue;
      const st = c.status ?? ev.status;
      const state = st?.type?.state ?? "pre";
      const side = (t: any): Side => ({
        n: de(t.team.displayName), win: t.winner === true,
        score: state === "pre" ? undefined : String(t.score ?? ""),
      });
      out.push({
        id: "fb" + ev.id, sport: "fb", comp: label, date: ev.date, state, detail: fbDetail(st),
        lg: slug, eid: String(ev.id),
        a: side(home), b: side(away),
        prio: bayern || germany ? 1 : deClub ? 2 : 3,
      });
    }
    return out;
  }));
  return lists.flat();
}

function country(a: any): string | undefined {
  const m = /countries\/500\/(\w+)\.png/.exec(a?.flag?.href ?? "");
  return m ? m[1].toUpperCase() : undefined;
}

async function tennis(): Promise<Match[]> {
  const out: Match[] = [];
  for (const [tour, slug] of [["atp", "mens-singles"], ["wta", "womens-singles"]] as const) {
    const j: any = await cached("tn:" + tour, 20_000, () => getJson(ESPN + "tennis/" + tour + "/scoreboard"));
    for (const ev of j?.events ?? []) {
      for (const g of ev.groupings ?? []) {
        if (g.grouping?.slug !== slug) continue;
        for (const c of g.competitions ?? []) {
          if (!inWindow(c.date)) continue;
          const [p1, p2] = c.competitors ?? [];
          if (!p1?.athlete || !p2?.athlete) continue;
          if (p1.athlete.displayName === "TBD" || p2.athlete.displayName === "TBD") continue;
          const roundEn = c.round?.displayName ?? "";
          const german = [country(p1.athlete), country(p2.athlete)].includes("GER");
          const lateRound = /^(semi|final)/i.test(roundEn);
          // Herren: Deutsche + alle Halbfinals/Finals + ATP Finals komplett · Damen: nur Deutsche
          const allMatches = tour === "atp" && /ATP Finals/i.test(ev.name ?? "");
          if (!(german || allMatches || (tour === "atp" && lateRound))) continue;
          const st = c.status?.type ?? {};
          const side = (p: any): Side => ({
            n: p.athlete.shortName || p.athlete.displayName, c: country(p.athlete), win: p.winner === true,
            sets: (p.linescores ?? []).map((l: any) => l.value),
            tb: (p.linescores ?? []).map((l: any) => l.tiebreak ?? null),
            r: p.curatedRank?.current ?? undefined,
          });
          out.push({
            id: "tn" + c.id, sport: "tn", comp: ev.name + (tour === "wta" ? " (Damen)" : ""),
            round: ROUNDS[roundEn] ?? roundEn, date: c.date, state: st.state ?? "pre",
            detail: st.state === "in" ? "live" : st.state === "post" ? (/Retired|RET/i.test(st.detail ?? "") ? "Aufgabe" : "Ende") : "",
            a: side(p1), b: side(p2), prio: german ? 1 : 2,
            venue: c.venue?.fullName ?? ev.venue?.fullName, note: c.notes?.[0]?.text,
          });
        }
      }
    }
  }
  return out;
}

async function sport() {
  const [fb, tn] = await Promise.all([football().catch(() => []), tennis().catch(() => [])]);
  const order = { in: 0, pre: 1, post: 2 } as const;
  const all = [...fb, ...tn].sort((x, y) =>
    order[x.state] - order[y.state] ||
    (x.state === "post" ? Date.parse(y.date) - Date.parse(x.date) : Date.parse(x.date) - Date.parse(y.date)));
  return { at: new Date().toISOString(), matches: all };
}

// ============================================================
// NEWS
// ============================================================
type News = { t: string; top?: string; d: string; u: string; s?: string; b?: boolean; x?: string };
const TS = "https://www.tagesschau.de/api2u/";
const HEISE_KI = "https://www.heise.de/thema/Kuenstliche-Intelligenz.xml";

function tsItem(n: any): News | null {
  if (!n?.title || !(n.shareURL || n.detailsweb)) return null;
  if (n.type && !["story", "webview"].includes(n.type)) return null;
  return { t: n.title, top: n.topline?.trim() || undefined, d: n.date, u: n.shareURL || n.detailsweb,
    s: n.firstSentence || undefined, b: n.breakingNews === true || undefined, x: n.details || undefined };
}

function merge(top: News[], rest: News[], max = 15): News[] {
  const seen = new Set<string>(), out: News[] = [];
  for (const n of [...top, ...rest.sort((a, b) => Date.parse(b.d) - Date.parse(a.d))]) {
    if (seen.has(n.u)) continue;
    seen.add(n.u); out.push(n);
    if (out.length >= max) break;
  }
  return out;
}

function decode(s: string) {
  return s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
    .replace(/&#0?39;|&apos;/g, "'").replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n)).trim();
}
function tag(block: string, name: string) {
  const m = new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`).exec(block);
  return m ? decode(m[1]) : "";
}
// Liest RSS (<item>) und Atom (<entry>)
function parseFeed(xml: string): News[] {
  const out: News[] = [];
  const blocks = xml.match(/<(item|entry)[\s>][\s\S]*?<\/(item|entry)>/g) ?? [];
  for (const b of blocks) {
    let link = tag(b, "link");
    if (!link) { const m = /<link[^>]*href="([^"]+)"/.exec(b); link = m ? m[1] : ""; }
    const d = tag(b, "published") || tag(b, "updated") || tag(b, "pubDate") || tag(b, "dc:date");
    const t = tag(b, "title");
    if (!t || !link) continue;
    if (/^heise[-+ ]?(Angebot|Anzeige)/i.test(t)) continue; // Werbung des Verlags weglassen
    const s = (tag(b, "summary") || tag(b, "description")).slice(0, 220) || undefined;
    out.push({ t, d: d ? new Date(d).toISOString() : new Date().toISOString(), u: link.split("?")[0], s });
  }
  return out;
}

async function news() {
  const [home, inland, ausland, ki] = await Promise.all([
    cached("ts:home", 120_000, () => getJson(TS + "homepage/")),
    cached("ts:inland", 120_000, () => getJson(TS + "news/?ressort=inland")),
    cached("ts:ausland", 120_000, () => getJson(TS + "news/?ressort=ausland")),
    cached("heise:ki", 300_000, async () => {
      const r = await fetch(HEISE_KI, { headers: UA });
      if (!r.ok) throw new Error("HTTP " + r.status);
      return parseFeed(await r.text());
    }),
  ]);
  const list = (j: any) => ((j?.news ?? []).map(tsItem).filter(Boolean)) as News[];
  const homeItems = list(home);
  const homeRaw: any[] = (home as any)?.news ?? [];
  const byRessort = (r: string) => homeItems.filter((_, i) => homeRaw[i]?.ressort === r);
  // Erst die Topthemen der Redaktion, dann die neuesten Meldungen
  const deList = merge(byRessort("inland"), list(inland));
  const weltList = merge(byRessort("ausland"), list(ausland));
  const breaking = merge([...homeItems, ...deList, ...weltList].filter((n) => n.b), [], 3);
  const kiList = ((ki as News[] | null) ?? []).sort((a, b) => Date.parse(b.d) - Date.parse(a.d)).slice(0, 15);
  return { at: new Date().toISOString(), breaking, de: deList, welt: weltList, ki: kiList };
}

// ============================================================
// SPIELDETAILS (Fußball): Tore, Karten, Statistik, Aufstellung
// ============================================================
const STATS: [string, string][] = [
  ["possessionPct", "Ballbesitz"], ["totalShots", "Schüsse"], ["shotsOnTarget", "Aufs Tor"],
  ["wonCorners", "Ecken"], ["foulsCommitted", "Fouls"], ["offsides", "Abseits"],
  ["saves", "Paraden"], ["yellowCards", "Gelbe Karten"], ["redCards", "Rote Karten"],
];
async function match(lg: string, id: string) {
  if (!/^[a-z0-9_.]+$/.test(lg) || !/^\d+$/.test(id)) throw new Error("bad");
  const s: any = await cached("m:" + lg + ":" + id, 20_000, () => getJson(ESPN + "soccer/" + lg + "/summary?event=" + id));
  if (!s) throw new Error("no data");
  const comp = s.header?.competitions?.[0];
  const home = comp.competitors.find((c: any) => c.homeAway === "home") ?? comp.competitors[0];
  const away = comp.competitors.find((c: any) => c.homeAway === "away") ?? comp.competitors[1];
  const hid = String(home.team.id);
  const st = comp.status;
  const side = (c: any) => ({ n: de(c.team.displayName), score: c.score, win: c.winner === true,
    ht: c.linescores?.[0]?.displayValue });
  const events = (s.keyEvents ?? []).map((k: any) => {
    const type = k.type?.text ?? "";
    let kind = "";
    if (/Own Goal/i.test(type)) kind = "own";
    else if (/Penalty - Scored/i.test(type)) kind = "pen";
    else if (/^Goal/i.test(type)) kind = "goal";
    else if (/Yellow/i.test(type)) kind = "yellow";
    else if (/Red/i.test(type)) kind = "red";
    else if (/Substitution/i.test(type)) kind = "sub";
    if (!kind) return null;
    const ps = (k.participants ?? []).map((p: any) => p.athlete?.displayName).filter(Boolean);
    let who = ps[0] ?? "", extra = kind.match(/goal|pen/) && ps[1] ? "Vorlage: " + ps[1] : "";
    if (kind === "sub") {
      const m = /([^.]+?) replaces (.+?)\.?\s*$/.exec(k.text ?? "");
      if (m) { who = m[1].trim(); extra = "für " + m[2]; }
    }
    return { min: k.clock?.displayValue ?? "", kind, side: String(k.team?.id) === hid ? "h" : "a", who, extra };
  }).filter(Boolean);
  const teams = s.boxscore?.teams ?? [];
  const statOf = (t: any, name: string) => t?.statistics?.find((x: any) => x.name === name)?.displayValue;
  const th = teams.find((t: any) => String(t.team.id) === hid), ta = teams.find((t: any) => String(t.team.id) !== hid);
  const stats = STATS.map(([k, label]) => [label, statOf(th, k), statOf(ta, k)])
    .filter((r) => r[1] != null && r[2] != null);
  const lineup = (sideId: string, isHome: boolean) => {
    const r = (s.rosters ?? []).find((x: any) => (String(x.team.id) === sideId) === true) ??
      (s.rosters ?? [])[isHome ? 0 : 1];
    if (!r?.roster?.length) return null;
    const p = (x: any) => ({ n: x.athlete?.displayName ?? "", nr: x.jersey ?? "", pos: x.position?.abbreviation ?? "" });
    return { form: r.formation ?? "", xi: r.roster.filter((x: any) => x.starter).map(p),
      bench: r.roster.filter((x: any) => !x.starter).map(p) };
  };
  return {
    at: new Date().toISOString(), date: comp.date, state: st?.type?.state ?? "pre", detail: fbDetail(st),
    h: side(home), a: side(away), events, stats,
    lineups: { h: lineup(hid, true), a: lineup(String(away.team.id), false) },
    venue: s.gameInfo?.venue?.fullName, ref: s.gameInfo?.officials?.[0]?.displayName,
  };
}

// ============================================================
// ARTIKEL: Text zum Lesen direkt in Hubert (ohne Browser,
// funktioniert auch im geführten Zugriff)
// ============================================================
type Block = { k: "p" | "h" | "q"; t: string };
async function article(u: string) {
  const url = new URL(u);
  if (url.hostname === "www.tagesschau.de" && url.pathname.startsWith("/api2u/")) {
    const j: any = await cached("a:" + u, 600_000, () => getJson(u));
    const blocks: Block[] = [];
    for (const c of j?.content ?? []) {
      if (c.type === "text" && c.value) blocks.push({ k: "p", t: decode(c.value) });
      else if (c.type === "headline" && c.value) blocks.push({ k: "h", t: decode(c.value) });
      else if (c.type === "quotation" && c.quotation?.text) blocks.push({ k: "q", t: decode(c.quotation.text) });
    }
    const img = j?.teaserImage?.imageVariants?.["16x9-640"] ?? j?.teaserImage?.imageVariants?.["16x9-512"];
    return { t: j.title, top: j.topline, d: j.date, img, blocks: blocks.filter((b) => b.t), src: "tagesschau.de", url: j.shareURL };
  }
  if (url.hostname === "www.heise.de" && url.pathname.startsWith("/news/")) {
    const html: string = (await cached("a:" + u, 600_000, async () => {
      const r = await fetch(url.origin + url.pathname, { headers: UA });
      if (!r.ok) throw new Error("HTTP " + r.status);
      return await r.text();
    })) ?? "";
    let ld: any = {};
    try { ld = JSON.parse(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/.exec(html)?.[1] ?? "{}"); } catch { /* egal */ }
    // Artikeltext: ab dem ersten echten Absatz bis zum Autorenkürzel, z. B. "(mho)"
    const blocks: Block[] = [];
    let started = false;
    for (const m of html.matchAll(/<(p|h3)>([\s\S]*?)<\/\1>/g)) {
      const t = decode(m[2]).replace(/\s+/g, " ").trim();
      if (!t || t.includes("${") || /einverstanden/i.test(t)) continue;
      if (!started) { if (m[1] === "p" && t.length > 60) started = true; else continue; }
      if (/^\([a-z]{2,5}\)$/.test(t)) break;
      blocks.push({ k: m[1] === "h3" ? "h" : "p", t });
    }
    const img = Array.isArray(ld.image) ? (ld.image[0]?.url ?? ld.image[0]) : ld.image?.url;
    return { t: ld.headline ?? "", top: "", d: ld.datePublished, img: typeof img === "string" ? img : undefined,
      blocks, src: "heise online", url: url.origin + url.pathname, plus: ld.isAccessibleForFree === false };
  }
  throw new Error("Quelle nicht erlaubt");
}

// ============================================================
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const reqUrl = new URL(req.url);
  const what = reqUrl.pathname.split("/").filter(Boolean).pop() ?? "";
  if (!["sport", "news", "match", "article"].includes(what)) {
    return new Response("Unbekannte Abfrage", { status: 404, headers: cors });
  }
  if (!(await keyOk(req.headers.get("x-kueche-key")))) {
    return new Response("Falscher Haushalts-Schlüssel", { status: 401, headers: cors });
  }
  let body: unknown;
  try {
    const q = reqUrl.searchParams;
    body = what === "sport" ? await sport() : what === "news" ? await news()
      : what === "match" ? await match(q.get("lg") ?? "", q.get("id") ?? "")
      : await article(q.get("u") ?? "");
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify(body), {
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
});
