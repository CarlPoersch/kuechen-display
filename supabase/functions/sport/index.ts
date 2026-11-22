// ============================================================
// Edge Function "sport": personalisierter Sport für Hubert.
//   GET .../sport/catalog          Sportarten und Ligen
//   GET .../sport/search?q=…       Suche nach Vereinen, Sportlern, Ligen, Ländern
//   GET .../sport/teams?l=<liga>   Teams/Fahrer einer Liga (zum Durchblättern)
//   GET .../sport/feed?l=a,b,c     Spiele der Ligen (gestern bis +7 Tage)
// Quellen: ESPN (Fußball, Tennis, NBA, NHL, NFL, MLB), HockeyWeb (DEL, DEL2,
// Oberliga, Bayernliga, CHL, WM), Jolpica (Formel 1).
// Gefiltert nach Favoriten wird in der App – so teilen sich alle Nutzer den
// Zwischenspeicher je Liga.
// ============================================================

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-kueche-key, content-type, authorization, apikey",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};
const UA = { "User-Agent": "Hubert/1.0 (privates Wanddisplay)" };

// ---------- Zugang: Haushalts-Schlüssel (Web) oder Login (App) ----------
const goodKeys = new Map<string, number>();
async function keyOk(key: string | null): Promise<boolean> {
  if (!key) return false;
  const seen = goodKeys.get(key);
  if (seen && Date.now() - seen < 10 * 60_000) return true;
  const svc = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const r = await fetch(Deno.env.get("SUPABASE_URL") + "/rest/v1/rpc/kueche_check", {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: svc, Authorization: "Bearer " + svc },
    body: JSON.stringify({ p_key: key }),
  });
  const ok = r.ok && (await r.json()) === true;
  if (ok) goodKeys.set(key, Date.now());
  return ok;
}
async function userOk(auth: string | null): Promise<boolean> {
  if (!auth || !auth.startsWith("Bearer ")) return false;
  const seen = goodKeys.get(auth);
  if (seen && Date.now() - seen < 5 * 60_000) return true;
  const svc = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const r = await fetch(Deno.env.get("SUPABASE_URL") + "/auth/v1/user", { headers: { apikey: svc, Authorization: auth } });
  if (r.ok) goodKeys.set(auth, Date.now());
  return r.ok;
}

// ---------- Zwischenspeicher (fällt eine Quelle aus: letzter guter Stand) ----------
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
async function getText(url: string) {
  const r = await fetch(url, { headers: { ...UA, "Accept": "text/html" } });
  if (!r.ok) throw new Error("HTTP " + r.status + " " + url);
  return await r.text();
}

// ============================================================
// KATALOG
// ============================================================
type SportId = "fb" | "tn" | "bb" | "ih" | "af" | "bs" | "f1";
const CATALOG: { id: SportId; name: string; emoji: string; leagues: [string, string, string?][] }[] = [
  { id: "fb", name: "Fußball", emoji: "⚽️", leagues: [
    ["soccer/ger.1", "Bundesliga"], ["soccer/ger.2", "2. Bundesliga"], ["soccer/ger.3", "3. Liga"],
    ["soccer/ger.dfb_pokal", "DFB-Pokal"], ["soccer/uefa.champions", "Champions League", "intl"],
    ["soccer/uefa.europa", "Europa League", "intl"], ["soccer/uefa.europa.conf", "Conference League", "intl"],
    ["soccer/eng.1", "Premier League"], ["soccer/esp.1", "LaLiga"], ["soccer/ita.1", "Serie A"],
    ["soccer/fra.1", "Ligue 1"], ["soccer/ned.1", "Eredivisie"], ["soccer/aut.1", "Österr. Bundesliga"],
    ["soccer/sui.1", "Schweizer Super League"], ["soccer/por.1", "Liga Portugal"], ["soccer/tur.1", "Süper Lig"],
    ["soccer/usa.1", "MLS"],
    ["soccer/fifa.world", "WM", "nat"], ["soccer/fifa.worldq.uefa", "WM-Quali Europa", "nat"],
    ["soccer/uefa.euro", "EM", "nat"], ["soccer/uefa.euroq", "EM-Quali", "nat"],
    ["soccer/uefa.nations", "Nations League", "nat"], ["soccer/fifa.friendly", "Länderspiele", "nat"],
    ["soccer/fifa.cwc", "Klub-WM", "intl"],
  ] },
  { id: "tn", name: "Tennis", emoji: "🎾", leagues: [["tennis/atp", "ATP (Herren)"], ["tennis/wta", "WTA (Damen)"]] },
  { id: "ih", name: "Eishockey", emoji: "🏒", leagues: [
    ["hw/del", "DEL"], ["hw/del2", "DEL2"], ["hw/oberliga", "Oberliga (Nord & Süd)"], ["hw/bayernliga", "Bayernliga"],
    ["hw/chl", "Champions Hockey League", "intl"], ["hw/eishockey-wm", "Eishockey-WM", "nat"], ["hockey/nhl", "NHL"],
  ] },
  { id: "bb", name: "Basketball", emoji: "🏀", leagues: [["basketball/nba", "NBA"], ["basketball/wnba", "WNBA"]] },
  { id: "af", name: "American Football", emoji: "🏈", leagues: [["football/nfl", "NFL"]] },
  { id: "bs", name: "Baseball", emoji: "⚾️", leagues: [["baseball/mlb", "MLB"]] },
  { id: "f1", name: "Formel 1", emoji: "🏎️", leagues: [["f1", "Formel 1"]] },
];
const LEAGUE = new Map<string, { sport: SportId; name: string; kind?: string; emoji: string }>();
for (const s of CATALOG) for (const [id, name, kind] of s.leagues) LEAGUE.set(id, { sport: s.id, name, kind, emoji: s.emoji });
const ESPN = "https://site.api.espn.com/apis/site/v2/sports/";
const ESPN_SPORT: Record<string, SportId> = { soccer: "fb", basketball: "bb", hockey: "ih", football: "af", baseball: "bs" };
const INTL = CATALOG[0].leagues.filter((l) => l[2] === "intl").map((l) => l[0]);
const NAT = CATALOG[0].leagues.filter((l) => l[2] === "nat").map((l) => l[0]);
const alias = (id: string) => (id === "del" ? "hw/del" : id);

// Deutsche Namen (ESPN liefert Englisch)
const NAMES: Record<string, string> = {
  "Bayern Munich": "FC Bayern", "Bayern München": "FC Bayern", "Germany": "Deutschland", "FC Cologne": "1. FC Köln",
  "Borussia Dortmund": "Dortmund", "Bayer Leverkusen": "Leverkusen", "Borussia Monchengladbach": "Gladbach",
  "Borussia Mönchengladbach": "Gladbach", "Eintracht Frankfurt": "Frankfurt", "VfB Stuttgart": "Stuttgart",
  "Hamburg SV": "HSV", "Werder Bremen": "Bremen", "SC Freiburg": "Freiburg", "TSG Hoffenheim": "Hoffenheim",
  "VfL Wolfsburg": "Wolfsburg", "FC Augsburg": "Augsburg", "Mainz": "Mainz 05",
  "France": "Frankreich", "Spain": "Spanien", "Italy": "Italien", "Netherlands": "Niederlande", "Belgium": "Belgien",
  "Austria": "Österreich", "Switzerland": "Schweiz", "Denmark": "Dänemark", "Poland": "Polen", "Czechia": "Tschechien",
  "Czech Republic": "Tschechien", "Hungary": "Ungarn", "Croatia": "Kroatien", "Turkey": "Türkei", "Türkiye": "Türkei",
  "Greece": "Griechenland", "Sweden": "Schweden", "Norway": "Norwegen", "Scotland": "Schottland", "Slovakia": "Slowakei",
  "Slovenia": "Slowenien", "Serbia": "Serbien", "Romania": "Rumänien", "Republic of Ireland": "Irland", "Ireland": "Irland",
  "Northern Ireland": "Nordirland", "Iceland": "Island", "Finland": "Finnland", "Luxembourg": "Luxemburg",
  "Georgia": "Georgien", "Argentina": "Argentinien", "Brazil": "Brasilien", "United States": "USA", "Mexico": "Mexiko",
  "Morocco": "Marokko", "Paris Saint-Germain": "Paris SG", "Internazionale": "Inter Mailand", "AC Milan": "AC Mailand",
  "Barcelona": "FC Barcelona", "Atletico Madrid": "Atlético", "Manchester City": "Man City", "Manchester United": "Man United",
};
const de = (n: string) => NAMES[n] ?? n;
// Suche: deutsche Begriffe → ESPN (Englisch)
const QUERY_EN: Record<string, string> = {
  deutschland: "germany", "österreich": "austria", schweiz: "switzerland", frankreich: "france", spanien: "spain",
  italien: "italy", niederlande: "netherlands", holland: "netherlands", belgien: "belgium", brasilien: "brazil",
  argentinien: "argentina", kroatien: "croatia", "dänemark": "denmark", schweden: "sweden", norwegen: "norway",
  polen: "poland", tschechien: "czechia", "türkei": "turkey", ungarn: "hungary", schottland: "scotland",
  marokko: "morocco", mexiko: "mexico", "köln": "cologne", "münchen": "munich", "mönchengladbach": "monchengladbach",
};
const FLAGS: Record<string, string> = {
  Deutschland: "🇩🇪", "Österreich": "🇦🇹", Schweiz: "🇨🇭", Frankreich: "🇫🇷", Spanien: "🇪🇸", Italien: "🇮🇹", Niederlande: "🇳🇱",
  Belgien: "🇧🇪", Portugal: "🇵🇹", England: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", Schottland: "🏴󠁧󠁢󠁳󠁣󠁴󠁿", "Dänemark": "🇩🇰", Schweden: "🇸🇪", Norwegen: "🇳🇴",
  Finnland: "🇫🇮", Polen: "🇵🇱", Tschechien: "🇨🇿", Slowakei: "🇸🇰", Ungarn: "🇭🇺", Kroatien: "🇭🇷", "Türkei": "🇹🇷",
  Griechenland: "🇬🇷", Brasilien: "🇧🇷", Argentinien: "🇦🇷", USA: "🇺🇸", Kanada: "🇨🇦", Lettland: "🇱🇻", Slowenien: "🇸🇮",
  Serbien: "🇷🇸", "Rumänien": "🇷🇴", Irland: "🇮🇪", Mexiko: "🇲🇽", Marokko: "🇲🇦", Japan: "🇯🇵", Kasachstan: "🇰🇿",
};
// Tennis: Spieler eines Landes folgen
const COUNTRIES: Record<string, [string, string, string]> = {
  deutschland: ["GER", "🇩🇪", "Deutschland"], "österreich": ["AUT", "🇦🇹", "Österreich"], schweiz: ["SUI", "🇨🇭", "Schweiz"],
  italien: ["ITA", "🇮🇹", "Italien"], spanien: ["ESP", "🇪🇸", "Spanien"], frankreich: ["FRA", "🇫🇷", "Frankreich"],
  usa: ["USA", "🇺🇸", "USA"], polen: ["POL", "🇵🇱", "Polen"], tschechien: ["CZE", "🇨🇿", "Tschechien"],
  "großbritannien": ["GBR", "🇬🇧", "Großbritannien"], england: ["GBR", "🇬🇧", "Großbritannien"],
};

// ============================================================
// SPIELE
// ============================================================
type Side = { n: string; id?: string; full?: string; c?: string; score?: string; win?: boolean; sets?: (number | string)[];
  tb?: (number | null)[]; r?: number };
type Match = {
  id: string; sport: SportId; comp: string; round?: string; date: string; state: "pre" | "in" | "post"; detail: string;
  a: Side; b: Side; prio: number; lg?: string; eid?: string; venue?: string; note?: string; de?: boolean; late?: boolean;
  field?: { id: string; n: string; pos: number; t?: string; c?: string }[]; sessions?: { n: string; t: string }[]; L?: string;
};

function inWindow(iso: string) {
  const t = Date.parse(iso), now = Date.now();
  return t > now - 36 * 3600_000 && t < now + 7 * 24 * 3600_000;
}
function ymd(d: Date) { return d.toISOString().slice(0, 10).replace(/-/g, ""); }

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
  return /Postp/i.test(name) ? "verschoben" : "";
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
  return new Set(ids ?? ["132"]);
}

/// Mannschaftssport bei ESPN – je Tag eine Abfrage (Zeiträume lehnt ESPN ab)
async function espnTeams(id: string): Promise<Match[]> {
  const sport = ESPN_SPORT[id.split("/")[0]];
  const now = Date.now();
  const today = ymd(new Date(now));
  const days = [-1, 0, 1, 2, 3, 4, 5, 6].map((d) => ymd(new Date(now + d * 24 * 3600_000)));
  const pages = await Promise.all(days.map((d) =>
    cached("e:" + id + ":" + d, d <= today ? 20_000 : 600_000, () => getJson(ESPN + id + "/scoreboard?limit=100&dates=" + d))));
  const seen = new Set<string>();
  const events = pages.flatMap((p: any) => p?.events ?? []).filter((ev: any) => !seen.has(ev.id) && seen.add(ev.id));
  const clubs = sport === "fb" ? await germanClubIds() : new Set<string>();
  const out: Match[] = [];
  for (const ev of events) {
    const c = ev.competitions?.[0];
    if (!c || !inWindow(ev.date)) continue;
    const home = c.competitors.find((x: any) => x.homeAway === "home") ?? c.competitors[0];
    const away = c.competitors.find((x: any) => x.homeAway === "away") ?? c.competitors[1];
    if (!home?.team || !away?.team) continue;
    const st = c.status ?? ev.status;
    const state = st?.type?.state ?? "pre";
    const side = (t: any): Side => ({
      id: String(t.team.id), n: sport === "fb" ? de(t.team.displayName) : (t.team.shortDisplayName || t.team.displayName),
      full: t.team.displayName, win: t.winner === true, score: state === "pre" ? undefined : String(t.score ?? ""),
    });
    const detail = sport === "fb" ? fbDetail(st)
      : state === "in" ? (st?.type?.shortDetail ?? "live")
      : state === "post" ? (/OT|SO/.test(st?.type?.shortDetail ?? "") ? "n. V." : "Ende")
      : /Postp/i.test(st?.type?.name ?? "") ? "verschoben" : "";
    out.push({
      id: "s" + ev.id, sport, comp: LEAGUE.get(id)?.name ?? id, date: ev.date, state, detail,
      lg: sport === "fb" ? id.split("/")[1] : id, eid: String(ev.id), a: side(home), b: side(away), prio: 0,
      de: [home, away].some((t: any) => clubs.has(String(t.team.id))) || undefined, venue: c.venue?.fullName,
    });
  }
  return out;
}

function country(a: any): string | undefined {
  const m = /countries\/500\/(\w+)\.png/.exec(a?.flag?.href ?? "");
  return m ? m[1].toUpperCase() : undefined;
}
const ROUNDS: Record<string, string> = {
  "Final": "Finale", "Semifinal": "Halbfinale", "Semifinals": "Halbfinale", "Quarterfinal": "Viertelfinale",
  "Quarterfinals": "Viertelfinale", "Round of 16": "Achtelfinale", "Group Stage": "Gruppenphase",
  "Round 1": "1. Runde", "Round 2": "2. Runde", "Round 3": "3. Runde", "Round 4": "Achtelfinale",
  "Round of 32": "3. Runde", "Round of 64": "2. Runde", "Round of 128": "1. Runde",
};

/// Tennis: alle Einzel der Woche
async function tennis(id: string): Promise<Match[]> {
  const tour = id.split("/")[1];
  const slug = tour === "wta" ? "womens-singles" : "mens-singles";
  const j: any = await cached("tn:" + tour, 20_000, () => getJson(ESPN + "tennis/" + tour + "/scoreboard"));
  const out: Match[] = [];
  for (const ev of j?.events ?? []) {
    for (const g of ev.groupings ?? []) {
      if (g.grouping?.slug !== slug) continue;
      for (const c of g.competitions ?? []) {
        if (!inWindow(c.date)) continue;
        const [p1, p2] = c.competitors ?? [];
        if (!p1?.athlete || !p2?.athlete) continue;
        if (p1.athlete.displayName === "TBD" || p2.athlete.displayName === "TBD") continue;
        const roundEn = c.round?.displayName ?? "";
        const st = c.status?.type ?? {};
        const side = (p: any): Side => ({
          id: String(p.athlete.id ?? p.id ?? ""), n: p.athlete.shortName || p.athlete.displayName,
          full: p.athlete.displayName, c: country(p.athlete), win: p.winner === true,
          sets: (p.linescores ?? []).map((l: any) => l.value), tb: (p.linescores ?? []).map((l: any) => l.tiebreak ?? null),
          r: p.curatedRank?.current ?? undefined,
        });
        out.push({
          id: "tn" + c.id, sport: "tn", comp: ev.name, round: ROUNDS[roundEn] ?? roundEn, date: c.date, state: st.state ?? "pre",
          detail: st.state === "in" ? "live" : st.state === "post" ? (/Retired|RET/i.test(st.detail ?? "") ? "Aufgabe" : "Ende") : "",
          lg: id, a: side(p1), b: side(p2), prio: 0,
          late: (/^(semi|final)/i.test(roundEn) || /ATP Finals|WTA Finals/i.test(ev.name ?? "")) || undefined,
          venue: c.venue?.fullName ?? ev.venue?.fullName, note: c.notes?.[0]?.text,
        });
      }
    }
  }
  return out;
}

// ---------- HockeyWeb (Eishockey in Deutschland) ----------
// Die Seiten sind HTML; wir lesen nur Spielpaarung, Zeit und Stand heraus.
const HW = "https://www.hockeyweb.de/";
function unhtml(s: string) {
  return s.replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#0?39;|&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").trim();
}
/// Ortszeit Berlin → UTC (Sommerzeit: letzter Sonntag im März bis letzter Sonntag im Oktober)
function berlin(y: number, m: number, d: number, hh: number, mm: number): string {
  const lastSunday = (month: number) => { const t = new Date(Date.UTC(y, month + 1, 0)); t.setUTCDate(t.getUTCDate() - t.getUTCDay()); return t; };
  const local = Date.UTC(y, m - 1, d, hh, mm);
  const start = lastSunday(2).getTime() + 3600_000, end = lastSunday(9).getTime() + 3600_000;
  const off = local - 2 * 3600_000 >= start && local - 2 * 3600_000 < end ? 2 : 1;
  return new Date(local - off * 3600_000).toISOString();
}
type HwGame = { gid: string; lg: string; date: string; home: string; away: string; hs?: string; as?: string; live: boolean; detail: string; homeShort: string; awayShort: string };
function parseHw(html: string): HwGame[] {
  const out: HwGame[] = [];
  const tokens = [...html.matchAll(/<h2[^>]*>([\s\S]*?)<\/h2>|<div class="gamePlanGame/g)];
  let day: [number, number, number] | null = null;
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i];
    if (t[1] !== undefined) {
      const m = /(\d{2})\.(\d{2})\.(\d{4})/.exec(t[1]);
      day = m ? [+m[3], +m[2], +m[1]] : null;
      continue;
    }
    const block = html.slice(t.index!, i + 1 < tokens.length ? tokens[i + 1].index! : t.index! + 6000);
    const h = /href="\/([^"]+?)\/spiele\/[^"]*?-(\d{8})-(\d+)"/.exec(block);
    if (!h) continue;
    const names = [...block.matchAll(/class="text-wrap[^"]*\blg:block hidden">([^<]*)</g)].map((x) => unhtml(x[1]));
    const shorts = [...block.matchAll(/class="text-wrap[^"]*\bblock lg:hidden">([^<]*)</g)].map((x) => unhtml(x[1]));
    if (names.length < 2) continue;
    const sc = /min-w-\[54px\][^>]*>\s*<span[^>]*>([\d-]+)<\/span>\s*<span[^>]*>:<\/span>\s*<span[^>]*>([\d-]+)<\/span>/.exec(block);
    const tm = /<time datetime="([^"]+)"/.exec(block);
    let date = tm?.[1];
    if (!date) {
      const hm = /(\d{1,2}):(\d{2})\s*</.exec(block);
      const ds = h[2];
      const [y, mo, d] = day ?? [+ds.slice(0, 4), +ds.slice(4, 6), +ds.slice(6, 8)];
      date = berlin(y, mo, d, hm ? +hm[1] : 19, hm ? +hm[2] : 30);
    }
    const live = /bg-surface-error/.test(block);
    const liveBits = [...block.matchAll(/text-text-error">([^<]*)</g)].map((x) => x[1].replace(/,\s*$/, "").trim()).filter(Boolean);
    const per = liveBits.find((b) => /^D\d|^OT|^PS|^P$/.test(b)) ?? "";
    const min = liveBits.find((b) => /'/.test(b)) ?? "";
    const perDe = per.replace(/^D(\d)/, "$1. Drittel").replace(/^OT/, "Verl.").replace(/^PS/, "Penaltys");
    out.push({
      gid: h[3], lg: h[1], date, home: names[0], away: names[1], homeShort: shorts[0] ?? names[0], awayShort: shorts[1] ?? names[1],
      hs: sc && sc[1] !== "-" ? sc[1] : undefined, as: sc && sc[2] !== "-" ? sc[2] : undefined, live,
      detail: live ? [perDe, min].filter(Boolean).join(" ") : "",
    });
  }
  return out;
}
async function hockeyweb(id: string): Promise<Match[]> {
  const path = id.slice(3);   // "oberliga"
  const [plan, res, live] = await Promise.all([
    cached("hw:plan:" + path, 600_000, () => getText(HW + path + "/spielplan")),
    cached("hw:res:" + path, 60_000, () => getText(HW + path + "/ergebnisse")),
    cached("hw:live", 20_000, () => getText(HW + "eishockey-liveticker")),
  ]);
  const games = new Map<string, HwGame & { done?: boolean }>();
  for (const g of parseHw(plan ?? "")) games.set(g.gid, g);
  for (const g of parseHw(res ?? "")) games.set(g.gid, { ...g, done: g.hs !== undefined });
  for (const g of parseHw(live ?? "")) if (g.lg === path && (g.live || games.has(g.gid))) games.set(g.gid, { ...games.get(g.gid), ...g, done: !g.live && g.hs !== undefined });
  const out: Match[] = [];
  for (const g of games.values()) {
    if (!inWindow(g.date)) continue;
    const started = Date.parse(g.date) < Date.now();
    const state = g.live ? "in" : g.done ? "post" : started && Date.now() - Date.parse(g.date) < 3 * 3600_000 ? "in" : started ? "post" : "pre";
    const hs = Number(g.hs), as = Number(g.as);
    out.push({
      id: "hw" + g.gid, sport: "ih", comp: LEAGUE.get(id)?.name ?? path, date: g.date, state,
      detail: state === "in" ? (g.detail || "live") : state === "post" ? (g.hs !== undefined ? "Ende" : "") : "",
      lg: id, prio: 0,
      a: { id: g.home, n: g.homeShort, full: g.home, score: state === "pre" ? undefined : g.hs, win: g.done && hs > as },
      b: { id: g.away, n: g.awayShort, full: g.away, score: state === "pre" ? undefined : g.as, win: g.done && as > hs },
    });
  }
  return out;
}
/// Teams einer HockeyWeb-Liga (aus der Team-Auswahl des Spielplans)
async function hwTeams(id: string): Promise<{ id: string; n: string }[]> {
  const path = id.slice(3);
  const html = (await cached("hw:plan:" + path, 600_000, () => getText(HW + path + "/spielplan"))) ?? "";
  const out = new Map<string, string>();
  for (const m of html.matchAll(/value="\/[^"]*spielplan\?teams=(\d+)[^"]*"[^>]*>([^<]+)</g)) out.set(unhtml(m[2]), m[1]);
  return [...out.keys()].map((n) => ({ id: n, n })).sort((a, b) => a.n.localeCompare(b.n, "de"));
}

// ---------- Formel 1 (Jolpica) ----------
const GP: Record<string, string> = {
  "Australian": "Australien", "Chinese": "China", "Japanese": "Japan", "Bahrain": "Bahrain", "Saudi Arabian": "Saudi-Arabien",
  "Miami": "Miami", "Emilia Romagna": "Emilia-Romagna", "Monaco": "Monaco", "Spanish": "Spanien", "Canadian": "Kanada",
  "Austrian": "Österreich", "British": "Großbritannien", "Belgian": "Belgien", "Hungarian": "Ungarn", "Dutch": "Niederlande",
  "Italian": "Italien", "Azerbaijan": "Aserbaidschan", "Singapore": "Singapur", "United States": "USA", "Mexico City": "Mexiko",
  "São Paulo": "Brasilien", "Las Vegas": "Las Vegas", "Qatar": "Katar", "Abu Dhabi": "Abu Dhabi", "Madrid": "Madrid",
  "Barcelona-Catalunya": "Spanien",
};
const gpName = (n: string) => { const m = /^(.*) Grand Prix$/.exec(n); return m ? "GP " + (GP[m[1]] ?? m[1]) : n; };
const J = "https://api.jolpi.ca/ergast/f1/current/";
async function f1(): Promise<Match[]> {
  const [next, last] = await Promise.all([
    cached("f1:next", 600_000, () => getJson(J + "next.json")),
    cached("f1:last", 300_000, () => getJson(J + "last/results.json")),
  ]);
  const out: Match[] = [];
  const nr: any = (next as any)?.MRData?.RaceTable?.Races?.[0];
  if (nr) {
    const sessions: [string, any][] = [["1. Training", nr.FirstPractice], ["2. Training", nr.SecondPractice],
      ["3. Training", nr.ThirdPractice], ["Sprint-Quali", nr.SprintQualifying ?? nr.SprintShootout], ["Sprint", nr.Sprint],
      ["Qualifying", nr.Qualifying], ["Rennen", { date: nr.date, time: nr.time }]];
    const upcoming = sessions.filter(([, s]) => s?.date).map(([n, s]) => ({ n, t: s.date + "T" + (s.time ?? "00:00:00Z") }))
      .filter((s) => Date.parse(s.t) > Date.now() - 2 * 3600_000);
    const race = nr.date + "T" + (nr.time ?? "13:00:00Z");
    const running = Date.parse(race) < Date.now() && Date.now() - Date.parse(race) < 2.5 * 3600_000;
    out.push({
      id: "f1-" + nr.season + "-" + nr.round, sport: "f1", comp: "Formel 1", round: "Lauf " + nr.round, date: race,
      state: running ? "in" : "pre", detail: running ? "Rennen läuft" : (upcoming[0]?.n ?? ""), lg: "f1",
      a: { n: gpName(nr.raceName) }, b: { n: nr.Circuit?.Location?.locality ?? "" }, prio: 0,
      venue: nr.Circuit?.circuitName, sessions: upcoming,
    });
  }
  const lr: any = (last as any)?.MRData?.RaceTable?.Races?.[0];
  if (lr && (!nr || lr.round !== nr.round)) {
    const date = lr.date + "T" + (lr.time ?? "13:00:00Z");
    if (Date.parse(date) > Date.now() - 8 * 24 * 3600_000) {
      out.push({
        id: "f1-" + lr.season + "-" + lr.round, sport: "f1", comp: "Formel 1", round: "Lauf " + lr.round, date, state: "post",
        detail: "Ergebnis", lg: "f1", a: { n: gpName(lr.raceName) }, b: { n: lr.Circuit?.Location?.locality ?? "" }, prio: 0,
        venue: lr.Circuit?.circuitName,
        field: (lr.Results ?? []).map((r: any) => ({
          id: r.Driver?.driverId, n: (r.Driver?.givenName?.[0] ?? "") + ". " + (r.Driver?.familyName ?? ""),
          pos: Number(r.position), t: r.Constructor?.name, c: r.Driver?.code,
        })),
      });
    }
  }
  return out;
}
async function drivers(): Promise<{ id: string; n: string }[]> {
  const j: any = await cached("f1:drivers", 24 * 3600_000, () => getJson(J + "drivers.json?limit=100"));
  return (j?.MRData?.DriverTable?.Drivers ?? []).map((d: any) => ({ id: d.driverId, n: d.givenName + " " + d.familyName }));
}

async function feed(ids: string[]) {
  const known = [...new Set(ids.map(alias))].filter((i) => LEAGUE.has(i)).slice(0, 40);
  const lists = await Promise.all(known.map((id) => {
    const load = id === "f1" ? f1() : id.startsWith("hw/") ? hockeyweb(id) : id.startsWith("tennis/") ? tennis(id) : espnTeams(id);
    return load.then((l) => l.map((m) => ({ ...m, L: id }))).catch((e) => { console.error("Liga", id, String(e)); return [] as Match[]; });
  }));
  const order = { in: 0, pre: 1, post: 2 } as const;
  const all = lists.flat().sort((x, y) => order[x.state] - order[y.state] ||
    (x.state === "post" ? Date.parse(y.date) - Date.parse(x.date) : Date.parse(x.date) - Date.parse(y.date)));
  return { at: new Date().toISOString(), matches: all };
}

async function teams(id: string) {
  id = alias(id);
  if (!LEAGUE.has(id)) throw new Error("Liga unbekannt");
  if (id === "f1") return (await drivers()).sort((a, b) => a.n.localeCompare(b.n));
  if (id.startsWith("hw/")) return await hwTeams(id);
  if (id.startsWith("tennis/")) return [];
  const j: any = await cached("teams:" + id, 24 * 3600_000, () => getJson(ESPN + id + "/teams?limit=500"));
  const sport = ESPN_SPORT[id.split("/")[0]];
  return (j?.sports?.[0]?.leagues?.[0]?.teams ?? []).map((t: any) => ({
    id: String(t.team.id), n: sport === "fb" ? de(t.team.displayName) : t.team.displayName,
  })).sort((a: any, b: any) => a.n.localeCompare(b.n, "de"));
}

// ============================================================
// SUCHE – wie die Haltestellensuche: offizielle Treffer zum Antippen
// ============================================================
type Hit = { kind: "team" | "player" | "driver" | "league" | "country" | "nat"; id: string; name: string; sub: string;
  emoji: string; sport: SportId; leagues: string[] };
const fold = (s: string) => s.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/ß/g, "ss").trim();

async function espnSearch(q: string, type: "team" | "player"): Promise<any[]> {
  const j: any = await cached("q:" + type + ":" + q, 3600_000, () =>
    getJson("https://site.web.api.espn.com/apis/common/v3/search?limit=20&type=" + type + "&query=" + encodeURIComponent(q)));
  return j?.items ?? [];
}

async function search(raw: string): Promise<Hit[]> {
  const q = raw.trim();
  if (q.length < 2) return [];
  const fq = fold(q);
  const en = QUERY_EN[q.toLowerCase()];
  const hits: Hit[] = [];
  const add = (h: Hit) => { if (!hits.some((x) => x.kind === h.kind && x.id === h.id && x.sport === h.sport)) hits.push(h); };

  // Ligen aus dem Katalog (auch Kurzformen wie „F1“ oder „CL“)
  const SHORT: Record<string, string> = { f1: "f1", cl: "soccer/uefa.champions", el: "soccer/uefa.europa", bl: "soccer/ger.1", em: "soccer/uefa.euro", wm: "soccer/fifa.world" };
  for (const s of CATALOG) for (const [id, name] of s.leagues) {
    if (SHORT[fq] === id || fold(name).includes(fq) || fold(s.name).startsWith(fq)) add({ kind: "league", id, name, sub: s.name + " · alle Spiele", emoji: s.emoji, sport: s.id, leagues: [id] });
  }

  const [teamsA, teamsB, players, hwLists, drv] = await Promise.all([
    espnSearch(q, "team"), en ? espnSearch(en, "team") : Promise.resolve([]), espnSearch(q, "player"),
    Promise.all(CATALOG.flatMap((s) => s.leagues).filter(([id]) => id.startsWith("hw/")).map(async ([id]) => ({ id, teams: await hwTeams(id).catch(() => []) }))),
    drivers().catch(() => []),
  ]);

  // Vereine und Nationalteams (ESPN)
  for (const t of [...teamsB, ...teamsA]) {
    const sp = ESPN_SPORT[t.sport];
    if (!sp || /\bU\d{2}\b|Women|\(W\)/i.test(t.displayName ?? "")) continue;
    const lg = String(t.league ?? "");
    if (/\.w\.|^w|wchampions|wworld|women|college|club\.friendly/.test(lg)) continue;
    const full = sp === "fb" ? "soccer/" + lg : t.sport + "/" + lg;
    const name = de(t.displayName);
    if (sp === "fb" && (NAT.includes(full) || /^fifa\.|^uefa\.(nations|euro)/.test(lg))) {
      add({ kind: "nat", id: String(t.id), name, sub: "Fußball · Nationalmannschaft", emoji: FLAGS[name] ?? "⚽️", sport: "fb", leagues: NAT });
    } else if (LEAGUE.has(full)) {
      const leagues = sp === "fb" ? [full, ...(lg.startsWith("ger.") ? ["soccer/ger.dfb_pokal"] : []), ...INTL] : [full];
      add({ kind: "team", id: String(t.id), name, sub: CATALOG.find((c) => c.id === sp)!.name + " · " + LEAGUE.get(full)!.name,
        emoji: LEAGUE.get(full)!.emoji, sport: sp, leagues });
    }
  }
  // Eishockey in Deutschland (HockeyWeb)
  const byName = new Map<string, string[]>();
  for (const l of hwLists) for (const t of l.teams) if (fold(t.n).includes(fq)) byName.set(t.n, [...(byName.get(t.n) ?? []), l.id]);
  for (const [n, leagues] of byName) {
    const nat = leagues.every((l) => l === "hw/eishockey-wm");
    add({ kind: nat ? "nat" : "team", id: n, name: n, sub: "Eishockey · " + (nat ? "Nationalmannschaft" : leagues.map((l) => LEAGUE.get(l)!.name).join(", ")),
      emoji: nat ? (FLAGS[n] ?? "🏒") : "🏒", sport: "ih", leagues });
  }
  // Tennisspieler
  for (const p of players) {
    if (p.sport !== "tennis" || !["atp", "wta"].includes(p.league)) continue;
    add({ kind: "player", id: String(p.id), name: p.displayName, sub: "Tennis · " + (p.league === "wta" ? "WTA" : "ATP"), emoji: "🎾", sport: "tn", leagues: ["tennis/" + p.league] });
  }
  // Formel-1-Fahrer
  for (const d of drv) if (fold(d.n).includes(fq)) add({ kind: "driver", id: d.id, name: d.n, sub: "Formel 1 · Fahrer", emoji: "🏎️", sport: "f1", leagues: ["f1"] });
  // Länder (Tennis: alle Spieler eines Landes)
  const c = COUNTRIES[q.toLowerCase()];
  if (c) add({ kind: "country", id: c[0], name: c[2] + " im Tennis", sub: "Tennis · alle Spieler aus " + c[2], emoji: c[1], sport: "tn", leagues: ["tennis/atp", "tennis/wta"] });

  // Beste Treffer zuerst: Suche als ganzes Wort im Namen („Bayern“ → FC Bayern), dann Wortanfang
  // („Bayernliga“), dann irgendwo enthalten; bei Gleichstand Vereine/Sportler vor Ligen
  const words = (s: string) => fold(s).split(/[^a-z0-9]+/).filter(Boolean);
  const match = (h: Hit) => {
    const n = fold(h.name), w = words(h.name);
    if (n === fq || w.includes(fq) || n.startsWith(fq + " ")) return 0;
    if (n.startsWith(fq) || w.some((x) => x.startsWith(fq))) return 1;
    return n.includes(fq) ? 2 : 3;
  };
  const rank = (h: Hit) => match(h) * 10 +
    ({ team: 0, nat: 0, player: 1, driver: 1, country: 2, league: 3 } as const)[h.kind];
  return hits.sort((a, b) => rank(a) - rank(b)).slice(0, 25);
}

// ============================================================
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const url = new URL(req.url);
  const what = url.pathname.split("/").filter(Boolean).pop() ?? "";
  if (!["catalog", "search", "teams", "feed"].includes(what)) return new Response("Unbekannte Abfrage", { status: 404, headers: cors });
  if (!(await keyOk(req.headers.get("x-kueche-key"))) && !(await userOk(req.headers.get("authorization")))) {
    return new Response("Kein Zugang", { status: 401, headers: cors });
  }
  const q = url.searchParams;
  let body: unknown;
  try {
    body = what === "catalog" ? CATALOG.map((s) => ({ ...s, leagues: s.leagues.map(([id, name, kind]) => ({ id, name, kind })) }))
      : what === "search" ? await search(q.get("q") ?? "")
      : what === "teams" ? await teams(q.get("l") ?? "")
      : await feed((q.get("l") ?? "").split(",").filter(Boolean));
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify(body), { headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
});
