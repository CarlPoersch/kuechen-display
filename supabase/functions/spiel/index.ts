// ============================================================
// Edge Function "spiel": Spielseite und Tabellen für Hubert (Fußball).
//   GET .../spiel/match?lg=ger.1&id=<spiel>   Tore, Karten, Statistik, Aufstellung mit Positionen
//   GET .../spiel/table?l=soccer/ger.1        Tabelle bzw. Gruppen, Zonen, Form je Team
// Quelle: ESPN. feeds/match bleibt für ältere App-Versionen unverändert.
// Design: docs/specs/2026-11-28-sport-spielseite-design.md
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

const ESPN = "https://site.api.espn.com/apis/site/v2/sports/";

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

// ============================================================
// TABELLE (Fußball): Tabelle bzw. Gruppen, Zonen, Form je Team
//   GET .../spiel/table?l=soccer/ger.1
// Quelle: ESPN-Tabelle (Reihenfolge, Zonen) + Spielplan je Team im selben
// Wettbewerb (Form). Bewusst nichts selbst berechnet – lieber keine
// Angabe als eine falsche Tabelle.
// ============================================================
const ZONES: [RegExp, string][] = [
  [/^Champions League qualif/i, "Champions-League-Quali"], [/^Champions League/i, "Champions League"],
  [/^Europa League qualif/i, "Europa-League-Quali"], [/^Europa League/i, "Europa League"],
  [/^(Europa )?Conference League qualif/i, "Conference-League-Quali"], [/Conference League/i, "Conference League"],
  [/round of 16/i, "Achtelfinale"], [/playoffs? - seeded/i, "Play-offs (gesetzt)"], [/playoffs? - unseeded/i, "Play-offs (ungesetzt)"],
  [/knockout|playoff round/i, "K.-o.-Runde"], [/Promotion playoff/i, "Aufstiegs-Relegation"], [/Promotion/i, "Aufstieg"],
  [/Relegation playoff/i, "Relegation"], [/Relegation/i, "Abstieg"], [/Eliminated/i, "Ausgeschieden"],
  [/Qualif|Advance/i, "Weiter"],
];
const zoneDE = (t: string) => ZONES.find(([r]) => r.test(t))?.[1] ?? t;
const groupDE = (n: string) => n.replace(/^Group\s+/i, "Gruppe ").replace(/^League Phase$/i, "Ligaphase");

async function form(id: string, team: string): Promise<string[]> {
  const j: any = await cached("sched:" + id + ":" + team, 30 * 60_000, () => getJson(ESPN + id + "/teams/" + team + "/schedule"));
  const done = (j?.events ?? []).filter((e: any) => e.competitions?.[0]?.status?.type?.completed)
    .sort((a: any, b: any) => Date.parse(b.date) - Date.parse(a.date)).slice(0, 5);
  return done.map((e: any) => {
    const cs = e.competitions[0].competitors ?? [];
    const me = cs.find((c: any) => String(c.team?.id ?? c.id) === team), them = cs.find((c: any) => c !== me);
    if (!me || !them) return "";
    if (me.winner === true) return "S";
    if (them.winner === true) return "N";
    const a = Number(me.score?.value ?? me.score), b = Number(them.score?.value ?? them.score);
    return a > b ? "S" : a < b ? "N" : "U";
  }).filter(Boolean);
}

async function table(id: string) {
  if (!/^soccer\/[a-z0-9_.]+$/.test(id)) throw new Error("Liga unbekannt");
  // Läuft in der Liga gerade ein Spiel, wird die Tabelle öfter frisch geholt
  const today: any = await cached("e:" + id + ":" + ymd(new Date()), 60_000, () => getJson(ESPN + id + "/scoreboard?limit=100&dates=" + ymd(new Date())));
  const live = (today?.events ?? []).some((e: any) => e.status?.type?.state === "in");
  const j: any = await cached("tab:" + id + (live ? ":live" : ""), live ? 60_000 : 10 * 60_000,
    () => getJson("https://site.api.espn.com/apis/v2/sports/" + id + "/standings"));
  if (!j) return { l: id, groups: [], zones: [], form: {} };
  const parts: any[] = j.children?.length ? j.children : j.standings ? [{ name: "", standings: j.standings }] : [];
  const zones: { c: string; t: string }[] = [];
  const zoneIdx = (note: any): number | undefined => {
    if (!note?.description) return undefined;
    const t = zoneDE(note.description), c = note.color ?? "#8E8E93";
    let i = zones.findIndex((z) => z.t === t);
    if (i < 0) { zones.push({ c, t }); i = zones.length - 1; }
    return i;
  };
  const groups = parts.map((g: any) => {
    const rows = (g.standings?.entries ?? []).map((e: any) => {
      const st = (n: string) => e.stats?.find((x: any) => x.name === n);
      const num = (n: string) => Number(st(n)?.value ?? st(n)?.displayValue ?? 0) || 0;
      return { id: String(e.team?.id ?? ""), n: de(e.team?.displayName ?? ""), k: e.team?.abbreviation ?? "",
        p: num("rank") || 0, sp: num("gamesPlayed"), s: num("wins"), u: num("ties"), nl: num("losses"),
        tf: num("pointsFor"), tg: num("pointsAgainst"), td: num("pointDifferential"), pk: num("points"),
        z: zoneIdx(e.note) };
    }).sort((a: any, b: any) => (a.p || 99) - (b.p || 99));
    rows.forEach((r: any, i: number) => { if (!r.p) r.p = i + 1; });
    return { n: parts.length > 1 ? groupDE(g.name ?? "") : undefined, rows };
  }).filter((g: any) => g.rows.length > 1);
  const ids = [...new Set(groups.flatMap((g: any) => g.rows.map((r: any) => r.id)).filter(Boolean))].slice(0, 64);
  const forms = await Promise.all(ids.map((t) => form(id, t).catch(() => [] as string[])));
  const fm: Record<string, string[]> = {};
  ids.forEach((t, i) => { if (forms[i].length) fm[t] = forms[i]; });
  return { l: id, at: new Date().toISOString(), live, groups, zones, form: fm };
}

// ============================================================
// SPIELDETAILS
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
  const side = (c: any) => ({ n: de(c.team.displayName), id: String(c.team.id), score: c.score, win: c.winner === true,
    ht: c.linescores?.[0]?.displayValue });
  const events = (s.keyEvents ?? []).map((k: any) => {
    const type = k.type?.text ?? "";
    let kind = "";
    if (/Own Goal/i.test(type)) kind = "own";
    else if (/Penalty - Scored/i.test(type)) kind = "pen";
    else if (/^Goal/i.test(type)) kind = "goal";
    else if (/Second Yellow|Yellow.*Red/i.test(type)) kind = "yellowred";
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
    // Je Spieler: Position (für das Spielfeld), Platz in der Formation, eigene Ereignisse mit Minute
    const p = (x: any) => {
      const ev: { k: string; m: string }[] = [];
      let subs = 0;
      for (const pl of x.plays ?? []) {
        const m = pl.clock?.displayValue ?? "";
        if (pl.ownGoal && (pl.didScore || pl.scoringPlay)) ev.push({ k: "own", m });
        else if (pl.didScore) ev.push({ k: pl.penaltyKick ? "pen" : "goal", m });
        if (pl.redCard) ev.push({ k: ev.some((e) => e.k === "yellow") ? "yellowred" : "red", m });
        else if (pl.yellowCard) ev.push({ k: "yellow", m });
        if (pl.substitution) {
          // Eingewechselte: erste Wechsel-Aktion = rein, eine weitere = raus
          ev.push({ k: x.subbedIn && subs === 0 ? "in" : "out", m });
          subs++;
        }
      }
      const a = x.athlete ?? {};
      const last = a.lastName || (a.displayName ?? "").split(" ").slice(-1)[0] || "";
      return { n: a.displayName ?? "", nr: x.jersey ?? "", pos: x.position?.abbreviation ?? "",
        id: a.id ? String(a.id) : undefined, ln: last, fp: Number(x.formationPlace ?? 0) || 0, ev };
    };
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
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const url = new URL(req.url);
  const what = url.pathname.split("/").filter(Boolean).pop() ?? "";
  if (!["match", "table"].includes(what)) return new Response("Unbekannte Abfrage", { status: 404, headers: cors });
  if (!(await keyOk(req.headers.get("x-kueche-key"))) && !(await userOk(req.headers.get("authorization")))) {
    return new Response("Kein Zugang", { status: 401, headers: cors });
  }
  const q = url.searchParams;
  let body: unknown;
  try {
    body = what === "match" ? await match(q.get("lg") ?? "", q.get("id") ?? "") : await table(q.get("l") ?? "");
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify(body), { headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
});
