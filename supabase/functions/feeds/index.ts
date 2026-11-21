// ============================================================
// Edge Function "feeds": Live-Sport und News für Huberts "Heute"-Seite.
//
// Warum eine eigene Funktion:
//  - Tagesschau und heise erlauben keinen direkten Abruf aus dem Browser (CORS).
//  - Die Sport-Rohdaten von ESPN sind groß (mehrere MB je Abfrage). Hier werden
//    sie auf das Nötige eingedampft, damit das alte iPad flott bleibt.
//  - Quellen lassen sich später austauschen, ohne die App zu ändern.
//
// Aufrufe mit Header "x-kueche-key" (Web) oder "Authorization: Bearer <Login>" (native App):
//   GET <supabase-url>/functions/v1/feeds/sport          (alte App-Versionen: feste Auswahl)
//   GET <supabase-url>/functions/v1/feeds/sport2?l=…     (personalisiert, siehe unten)
//   GET <supabase-url>/functions/v1/feeds/sports | teams?l=…
//   GET <supabase-url>/functions/v1/feeds/news
//   GET <supabase-url>/functions/v1/feeds/match?lg=<liga>&id=<spiel>
//   GET <supabase-url>/functions/v1/feeds/article?u=<artikel-link>
// ============================================================

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-kueche-key, content-type, authorization, apikey",
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

// ---------- Oder: angemeldeter Nutzer der nativen App (Supabase-Login) ----------
async function userOk(auth: string | null): Promise<boolean> {
  if (!auth || !auth.startsWith("Bearer ")) return false;
  const seen = goodKeys.get(auth);
  if (seen && Date.now() - seen < 5 * 60_000) return true;
  const svc = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const r = await fetch(Deno.env.get("SUPABASE_URL") + "/auth/v1/user", { headers: { apikey: svc, Authorization: auth } });
  if (r.ok) goodKeys.set(auth, Date.now());
  return r.ok;
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

type Side = { n: string; id?: string; full?: string; c?: string; score?: string; win?: boolean; sets?: (number | string)[];
  tb?: (number | null)[]; r?: number };
type Match = {
  id: string; sport: "fb" | "tn" | "bb" | "ih" | "af" | "bs" | "f1"; comp: string; round?: string; date: string;
  state: "pre" | "in" | "post"; detail: string; a: Side; b: Side; prio: number;
  lg?: string; eid?: string; venue?: string; note?: string;
  de?: boolean; late?: boolean; field?: { id: string; n: string; pos: number; t?: string; c?: string }[];
  sessions?: { n: string; t: string }[]; L?: string;
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
// SPORT, PERSONALISIERT (ab App-Version mit Sport-Einstellungen)
//   GET .../feeds/sports            Katalog: Sportarten und Ligen
//   GET .../feeds/teams?l=<liga>    Teams/Fahrer einer Liga (für Favoriten)
//   GET .../feeds/sport2?l=a,b,c    Spiele der gewählten Ligen (gestern bis +7 Tage)
// Gefiltert nach Favoriten wird in der App – so teilen sich alle Nutzer den
// Zwischenspeicher je Liga und der Server bleibt einfach.
// ============================================================
type SportId = "fb" | "tn" | "bb" | "ih" | "af" | "bs" | "f1";
const CATALOG: { id: SportId; name: string; emoji: string; leagues: [string, string, string?][] }[] = [
  { id: "fb", name: "Fußball", emoji: "⚽️", leagues: [
    ["soccer/ger.1", "Bundesliga"], ["soccer/ger.2", "2. Bundesliga"], ["soccer/ger.3", "3. Liga"],
    ["soccer/ger.dfb_pokal", "DFB-Pokal"], ["soccer/uefa.champions", "Champions League", "intl"],
    ["soccer/uefa.europa", "Europa League", "intl"], ["soccer/uefa.europa.conf", "Conference League", "intl"],
    ["soccer/eng.1", "Premier League"], ["soccer/esp.1", "LaLiga"], ["soccer/ita.1", "Serie A"],
    ["soccer/fra.1", "Ligue 1"], ["soccer/ned.1", "Eredivisie"], ["soccer/aut.1", "Österr. Bundesliga"],
    ["soccer/sui.1", "Schweizer Super League"], ["soccer/usa.1", "MLS"],
    ["soccer/fifa.world", "WM", "nat"], ["soccer/fifa.worldq.uefa", "WM-Quali Europa", "nat"],
    ["soccer/uefa.euro", "EM", "nat"], ["soccer/uefa.euroq", "EM-Quali", "nat"],
    ["soccer/uefa.nations", "Nations League", "nat"], ["soccer/fifa.friendly", "Länderspiele", "nat"],
    ["soccer/fifa.cwc", "Klub-WM", "intl"],
  ] },
  { id: "tn", name: "Tennis", emoji: "🎾", leagues: [["tennis/atp", "ATP (Herren)"], ["tennis/wta", "WTA (Damen)"]] },
  { id: "bb", name: "Basketball", emoji: "🏀", leagues: [["basketball/nba", "NBA"], ["basketball/wnba", "WNBA"]] },
  { id: "ih", name: "Eishockey", emoji: "🏒", leagues: [["del", "DEL"], ["hockey/nhl", "NHL"]] },
  { id: "af", name: "American Football", emoji: "🏈", leagues: [["football/nfl", "NFL"]] },
  { id: "bs", name: "Baseball", emoji: "⚾️", leagues: [["baseball/mlb", "MLB"]] },
  { id: "f1", name: "Formel 1", emoji: "🏎️", leagues: [["f1", "Formel 1"]] },
];
const LEAGUE = new Map<string, { sport: SportId; name: string }>();
for (const s of CATALOG) for (const [id, name] of s.leagues) LEAGUE.set(id, { sport: s.id, name });
const ESPN_SPORT: Record<string, SportId> = { soccer: "fb", basketball: "bb", hockey: "ih", football: "af", baseball: "bs" };

function ymd(d: Date) { return d.toISOString().slice(0, 10).replace(/-/g, ""); }

/// Mannschaftssportarten bei ESPN (Fußball, NBA, NHL, NFL, MLB …)
async function espnTeams(id: string): Promise<Match[]> {
  const [sp] = id.split("/");
  const sport = ESPN_SPORT[sp];
  // Je Tag eine Abfrage (Zeiträume lehnt ESPN ab). Heute/gestern oft auffrischen, die Zukunft selten.
  const now = Date.now();
  const days = [-1, 0, 1, 2, 3, 4, 5, 6].map((d) => ymd(new Date(now + d * 24 * 3600_000)));
  const today = ymd(new Date(now));
  const pages = await Promise.all(days.map((d) =>
    cached("s2:" + id + ":" + d, d <= today ? 20_000 : 600_000, () => getJson(ESPN + id + "/scoreboard?limit=100&dates=" + d))));
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
    const side = (t: any): Side & { id: string } => ({
      id: String(t.team.id),
      n: sport === "fb" ? de(t.team.displayName) : (t.team.shortDisplayName || t.team.displayName),
      win: t.winner === true, score: state === "pre" ? undefined : String(t.score ?? ""),
    });
    const detail = sport === "fb" ? fbDetail(st)
      : state === "in" ? (st?.type?.shortDetail ?? "live") : state === "post" ? (/OT|SO/.test(st?.type?.shortDetail ?? "") ? "n. V." : "Ende")
      : /Postp/i.test(st?.type?.name ?? "") ? "verschoben" : "";
    out.push({
      id: "s" + ev.id, sport, comp: LEAGUE.get(id)?.name ?? id, date: ev.date, state, detail,
      lg: sport === "fb" ? id.split("/")[1] : id, eid: String(ev.id),
      a: side(home), b: side(away), prio: 0,
      de: [home, away].some((t: any) => clubs.has(String(t.team.id))) || undefined,
      venue: c.venue?.fullName,
    } as Match);
  }
  return out;
}

/// Tennis: alle Einzel der Woche (Herren bzw. Damen); Filter (Deutsche, Favoriten) macht die App
async function tennisAll(id: string): Promise<Match[]> {
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
        const side = (p: any) => ({
          id: String(p.athlete.id ?? p.id ?? ""), n: p.athlete.shortName || p.athlete.displayName,
          full: p.athlete.displayName, c: country(p.athlete), win: p.winner === true,
          sets: (p.linescores ?? []).map((l: any) => l.value),
          tb: (p.linescores ?? []).map((l: any) => l.tiebreak ?? null),
          r: p.curatedRank?.current ?? undefined,
        });
        const late = /^(semi|final)/i.test(roundEn) || /ATP Finals|WTA Finals/i.test(ev.name ?? "");
        out.push({
          id: "tn" + c.id, sport: "tn", comp: ev.name, round: ROUNDS[roundEn] ?? roundEn, date: c.date,
          state: st.state ?? "pre",
          detail: st.state === "in" ? "live" : st.state === "post" ? (/Retired|RET/i.test(st.detail ?? "") ? "Aufgabe" : "Ende") : "",
          lg: id, a: side(p1), b: side(p2), prio: 0, late: late || undefined,
          venue: c.venue?.fullName ?? ev.venue?.fullName, note: c.notes?.[0]?.text,
        } as Match);
      }
    }
  }
  return out;
}

/// DEL über OpenLigaDB (Community-gepflegt; Ergebnisse kommen meist kurz nach Spielende)
async function delGames(): Promise<Match[]> {
  const now = new Date();
  const season = now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
  const all: any[] = (await cached("del:" + season, 120_000, () => getJson("https://api.openligadb.de/getmatchdata/del/" + season))) ?? [];
  const out: Match[] = [];
  for (const m of all) {
    const date = m.matchDateTimeUTC;
    if (!date || !inWindow(date)) continue;
    const started = Date.parse(date) < Date.now();
    const res = (m.matchResults ?? []).sort((x: any, y: any) => (y.resultOrderID ?? 0) - (x.resultOrderID ?? 0))[0];
    const lastGoal = (m.goals ?? []).at?.(-1);
    const s1 = res?.pointsTeam1 ?? lastGoal?.scoreTeam1, s2 = res?.pointsTeam2 ?? lastGoal?.scoreTeam2;
    const state = m.matchIsFinished ? "post" : started && Date.now() - Date.parse(date) < 3.5 * 3600_000 ? "in" : started ? "post" : "pre";
    const side = (t: any, score: any, win: boolean) => ({
      id: String(t.teamId), n: t.shortName || t.teamName, score: state === "pre" || score == null ? undefined : String(score), win,
    });
    out.push({
      id: "del" + m.matchID, sport: "ih", comp: "DEL", round: m.group?.groupName, date, state,
      detail: state === "in" ? "live" : state === "post" ? (m.matchIsFinished ? "Ende" : "") : "",
      lg: "del", a: side(m.team1, s1, m.matchIsFinished && s1 > s2), b: side(m.team2, s2, m.matchIsFinished && s2 > s1), prio: 0,
      venue: m.location?.locationCity,
    } as Match);
  }
  return out;
}

/// Formel 1 über Jolpica (Nachfolger der Ergast-API): nächstes Rennen + letztes Ergebnis
const GP: Record<string, string> = {
  "Australian": "Australien", "Chinese": "China", "Japanese": "Japan", "Bahrain": "Bahrain", "Saudi Arabian": "Saudi-Arabien",
  "Miami": "Miami", "Emilia Romagna": "Emilia-Romagna", "Monaco": "Monaco", "Spanish": "Spanien", "Canadian": "Kanada",
  "Austrian": "Österreich", "British": "Großbritannien", "Belgian": "Belgien", "Hungarian": "Ungarn", "Dutch": "Niederlande",
  "Italian": "Italien", "Azerbaijan": "Aserbaidschan", "Singapore": "Singapur", "United States": "USA", "Mexico City": "Mexiko",
  "São Paulo": "Brasilien", "Las Vegas": "Las Vegas", "Qatar": "Katar", "Abu Dhabi": "Abu Dhabi", "Madrid": "Madrid",
  "Barcelona-Catalunya": "Spanien",
};
const gpName = (n: string) => { const m = /^(.*) Grand Prix$/.exec(n); return m ? "GP " + (GP[m[1]] ?? m[1]) : n; };
async function f1(): Promise<Match[]> {
  const J = "https://api.jolpi.ca/ergast/f1/current/";
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
      state: running ? "in" : "pre", detail: running ? "Rennen läuft" : (upcoming[0] ? upcoming[0].n : ""),
      lg: "f1", a: { n: gpName(nr.raceName) }, b: { n: nr.Circuit?.Location?.locality ?? "" }, prio: 0,
      venue: nr.Circuit?.circuitName, sessions: upcoming,
    } as Match);
  }
  const lr: any = (last as any)?.MRData?.RaceTable?.Races?.[0];
  if (lr && (!nr || lr.round !== nr.round)) {
    const date = lr.date + "T" + (lr.time ?? "13:00:00Z");
    if (Date.parse(date) > Date.now() - 8 * 24 * 3600_000) {
      out.push({
        id: "f1-" + lr.season + "-" + lr.round, sport: "f1", comp: "Formel 1", round: "Lauf " + lr.round, date,
        state: "post", detail: "Ergebnis", lg: "f1", a: { n: gpName(lr.raceName) }, b: { n: lr.Circuit?.Location?.locality ?? "" },
        prio: 0, venue: lr.Circuit?.circuitName,
        field: (lr.Results ?? []).map((r: any) => ({
          id: r.Driver?.driverId, n: (r.Driver?.givenName?.[0] ?? "") + ". " + (r.Driver?.familyName ?? ""), pos: Number(r.position),
          t: r.Constructor?.name, c: r.Driver?.code,
        })),
      } as Match);
    }
  }
  return out;
}

async function sport2(ids: string[]) {
  const known = [...new Set(ids)].filter((i) => LEAGUE.has(i)).slice(0, 40);
  const lists = await Promise.all(known.map((id) => {
    const load = id === "f1" ? f1() : id === "del" ? delGames() : id.startsWith("tennis/") ? tennisAll(id) : espnTeams(id);
    // L = Liga-Kennung wie im Katalog (danach filtert die App ihre Favoriten)
    return load.then((l) => l.map((m) => ({ ...m, L: id })))
      .catch((e) => { console.error("Liga", id, String(e)); return [] as Match[]; });
  }));
  const order = { in: 0, pre: 1, post: 2 } as const;
  const all = lists.flat().sort((x, y) =>
    order[x.state] - order[y.state] ||
    (x.state === "post" ? Date.parse(y.date) - Date.parse(x.date) : Date.parse(x.date) - Date.parse(y.date)));
  return { at: new Date().toISOString(), matches: all };
}

/// Teams bzw. Fahrer einer Liga – zum Auswählen der Favoriten
async function teams(id: string) {
  if (!LEAGUE.has(id)) throw new Error("Liga unbekannt");
  if (id === "f1") {
    const j: any = await cached("f1:drivers", 24 * 3600_000, () => getJson("https://api.jolpi.ca/ergast/f1/current/drivers.json"));
    return (j?.MRData?.DriverTable?.Drivers ?? []).map((d: any) => ({ id: d.driverId, n: d.givenName + " " + d.familyName }))
      .sort((a: any, b: any) => a.n.localeCompare(b.n));
  }
  if (id === "del") {
    const now = new Date();
    const season = now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
    const j: any = await cached("del:teams:" + season, 24 * 3600_000, () => getJson("https://api.openligadb.de/getavailableteams/del/" + season));
    return (j ?? []).map((t: any) => ({ id: String(t.teamId), n: t.teamName })).sort((a: any, b: any) => a.n.localeCompare(b.n, "de"));
  }
  if (id.startsWith("tennis/")) return [];   // Spieler: freie Eingabe in der App
  const j: any = await cached("teams:" + id, 24 * 3600_000, () => getJson(ESPN + id + "/teams?limit=500"));
  const sport = ESPN_SPORT[id.split("/")[0]];
  return (j?.sports?.[0]?.leagues?.[0]?.teams ?? []).map((t: any) => ({
    id: String(t.team.id), n: sport === "fb" ? de(t.team.displayName) : t.team.displayName,
  })).sort((a: any, b: any) => a.n.localeCompare(b.n, "de"));
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
  if (!["sport", "sport2", "sports", "teams", "news", "match", "article"].includes(what)) {
    return new Response("Unbekannte Abfrage", { status: 404, headers: cors });
  }
  if (!(await keyOk(req.headers.get("x-kueche-key"))) && !(await userOk(req.headers.get("authorization")))) {
    return new Response("Falscher Haushalts-Schlüssel", { status: 401, headers: cors });
  }
  let body: unknown;
  try {
    const q = reqUrl.searchParams;
    body = what === "sport" ? await sport() : what === "news" ? await news()
      : what === "sport2" ? await sport2((q.get("l") ?? "").split(",").filter(Boolean))
      : what === "sports" ? CATALOG.map((s) => ({ ...s, leagues: s.leagues.map(([id, name, kind]) => ({ id, name, kind })) }))
      : what === "teams" ? await teams(q.get("l") ?? "")
      : what === "match" ? await match(q.get("lg") ?? "", q.get("id") ?? "")
      : await article(q.get("u") ?? "");
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify(body), {
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
});
