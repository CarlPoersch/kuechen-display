// ============================================================
// Edge Function "filme": Kino, Streaming und Serien für Hubert (Daten: TMDB).
//   GET .../filme/providers                 Streamingdienste in Deutschland (mit Logo und App-Symbol)
//   GET .../filme/genres                    Genres (Film + Serie, deutsch)
//   GET .../filme/feed?p=8,9&x=27           Neu: Kino, Streaming-Filme, Serien (p = Dienste, x = Genres ausblenden)
//   GET .../filme/title?t=movie|tv&id=…     Details eines Titels
//   GET .../filme/search?q=…&t=tv|multi     Suche
//   GET .../filme/shows?ids=1,2             Gefolgte Serien: nächste Folge
//   GET .../filme/favs?ids=tv:1,movie:2     Favoriten: Serien mit nächster Folge, Filme mit Kino-/Streaming-Start (DE)
//   GET .../filme/random?t=movie|tv|any&p=…&g=…&x=…&min=7&len=120   Zufallsvorschlag (g = Wunsch-Genres, eins davon)
// Der TMDB-Schlüssel liegt im Supabase Vault (app_tmdb_key), nicht im Code.
// ============================================================

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-kueche-key, content-type, authorization, apikey",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};
const SB = Deno.env.get("SUPABASE_URL") ?? "";
const SVC = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const IMG = "https://image.tmdb.org/t/p/";

// ---------- Zugang: Haushalts-Schlüssel (Web) oder Login (App) ----------
const good = new Map<string, number>();
async function keyOk(key: string | null): Promise<boolean> {
  if (!key) return false;
  const seen = good.get(key);
  if (seen && Date.now() - seen < 10 * 60_000) return true;
  const r = await fetch(SB + "/rest/v1/rpc/kueche_check", {
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
  const r = await fetch(SB + "/auth/v1/user", { headers: { apikey: SVC, Authorization: auth } });
  if (r.ok) good.set(auth, Date.now());
  return r.ok;
}

// ---------- TMDB-Schlüssel aus dem Vault ----------
let tmdbKey = "";
async function key(): Promise<string> {
  if (tmdbKey) return tmdbKey;
  const r = await fetch(SB + "/rest/v1/rpc/app_secret", {
    method: "POST", headers: { "Content-Type": "application/json", apikey: SVC, Authorization: "Bearer " + SVC },
    body: JSON.stringify({ p_name: "app_tmdb_key" }),
  });
  tmdbKey = r.ok ? String(await r.json() ?? "") : "";
  if (!tmdbKey) throw new Error("TMDB-Schlüssel fehlt");
  return tmdbKey;
}

// ---------- Zwischenspeicher ----------
const cache = new Map<string, { at: number; val: unknown }>();
async function cached<T>(k: string, ms: number, load: () => Promise<T>): Promise<T> {
  const hit = cache.get(k);
  if (hit && Date.now() - hit.at < ms) return hit.val as T;
  try {
    const val = await load();
    cache.set(k, { at: Date.now(), val });
    if (cache.size > 2000) cache.delete(cache.keys().next().value!);
    return val;
  } catch (e) {
    if (hit) return hit.val as T;
    throw e;
  }
}
async function tmdb(path: string, params: Record<string, string | number | undefined> = {}, ms = 6 * 3600_000): Promise<any> {
  const q = new URLSearchParams({ language: "de-DE" });
  for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== "") q.set(k, String(v));
  const url = "https://api.themoviedb.org/3/" + path + "?" + q.toString();
  return await cached(url, ms, async () => {
    q.set("api_key", await key());
    const r = await fetch("https://api.themoviedb.org/3/" + path + "?" + q.toString());
    if (!r.ok) throw new Error("TMDB " + r.status + " " + path);
    return await r.json();
  });
}

const day = (offset: number) => new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10);
const img = (p: string | null | undefined, size = "w342") => (p ? IMG + size + p : undefined);

type Provider = { id: number; name: string; logo?: string; icon?: string };
type Item = {
  id: number; t: "movie" | "tv"; title: string; poster?: string; date?: string; rating?: number; genres?: number[];
  providers?: Provider[]; next?: { s: number; e: number; date?: string; name?: string }; kino?: boolean;
};

// Leih-/Kauf-Shops, Werbe-Varianten und Sammel-Apps sind keine eigenen Abos
const NOISE = /store|justwatch|amazon video|youtube|with ads|channel|plex|rakuten|google play|microsoft|videoload|chili|kino on demand/i;
const okProvider = (name: string) => !NOISE.test(name);

// ---------- Offizielle App-Symbole (App Store) ----------
// TMDB-Logos fehlen manchmal oder sind auf hellem Grund unsichtbar (RTL+: transparentes PNG mit heller Schrift).
// Deshalb liefert die Funktion zusätzlich das App-Symbol aus dem deutschen App Store.
// Feste App-IDs (am 23.11.2026 im App Store geprüft) und EINE Sammelabfrage – viele Einzelabfragen
// hintereinander sperrt der App Store (so fehlte das RTL+-Symbol, es stand weit hinten in der Liste).
const APP_IDS: Record<string, number> = {
  "Netflix": 363590051, "Amazon Prime Video": 545519333, "Disney Plus": 1446075923, "Disney+": 1446075923,
  "Apple TV Plus": 1174078549, "Apple TV+": 1174078549, "Apple TV": 1174078549,
  "Paramount Plus": 1340650234, "Paramount+": 1340650234, "WOW": 929190059, "Sky Go": 375667763, "Joyn": 826510222,
  "MagentaTV": 1625657880, "ZDF": 437025413, "HBO Max": 1666653815, "Max": 1666653815, "Crunchyroll": 329913454,
  "DAZN": 1129523589, "RTL+": 1057991212, "ARD Plus": 1635800815, "arte": 405028510, "ARTE": 405028510,
};
let iconMap: Map<number, string> | null = null;
let iconAt = 0;
let iconLoading: Promise<void> | null = null;

async function loadIcons(): Promise<void> {
  const fresh = iconMap && Date.now() - iconAt < (iconMap.size ? 7 * 86_400_000 : 10 * 60_000);
  if (fresh) return;
  if (!iconLoading) {
    iconLoading = (async () => {
      const ids = [...new Set(Object.values(APP_IDS))].join(",");
      const map = new Map<number, string>();
      try {
        const r = await fetch(`https://itunes.apple.com/lookup?id=${ids}&country=de`);
        const j = r.ok ? await r.json() : null;
        for (const a of j?.results ?? []) {
          const art = a.artworkUrl512 ?? a.artworkUrl100;
          if (a.trackId && art) map.set(a.trackId, art);
        }
        if (!r.ok) console.log("App-Store-Abfrage fehlgeschlagen:", r.status);
      } catch (e) { console.log("App Store nicht erreichbar:", String(e)); }
      // Leeres Ergebnis nicht über ein altes, gutes legen
      if (map.size || !iconMap) { iconMap = map; iconAt = Date.now(); }
    })().finally(() => { iconLoading = null; });
  }
  await iconLoading;
}
const iconFor = (name: string): string | undefined => {
  const id = APP_IDS[name];
  return id ? iconMap?.get(id) : undefined;
};
const withIcon = (p: Provider): Provider => ({ ...p, icon: iconFor(p.name) });

function providersDE(wp: any): Provider[] {
  const de = wp?.results?.DE;
  const list = [...(de?.flatrate ?? []), ...(de?.free ?? []), ...(de?.ads ?? [])];
  const seen = new Set<number>();
  return list.filter((p: any) => okProvider(p.provider_name) && !seen.has(p.provider_id) && seen.add(p.provider_id))
    .map((p: any) => withIcon({ id: p.provider_id, name: p.provider_name, logo: img(p.logo_path, "w92") }));
}

function base(r: any, t: "movie" | "tv"): Item {
  return {
    id: r.id, t, title: t === "movie" ? r.title : r.name, poster: img(r.poster_path),
    date: t === "movie" ? r.release_date : r.first_air_date, rating: r.vote_average ? Math.round(r.vote_average * 10) / 10 : undefined,
    genres: r.genre_ids ?? (r.genres ?? []).map((g: any) => g.id),
  };
}

async function details(t: "movie" | "tv", id: number) {
  return await tmdb(t + "/" + id, {
    append_to_response: t === "movie" ? "watch/providers,release_dates" : "watch/providers,content_ratings",
  }, 6 * 3600_000);
}

// ---------- Routen ----------
async function providers() {
  const j = await tmdb("watch/providers/tv", { watch_region: "DE" }, 7 * 86_400_000);
  const m = await tmdb("watch/providers/movie", { watch_region: "DE" }, 7 * 86_400_000);
  const all = new Map<number, any>();
  for (const p of [...(j.results ?? []), ...(m.results ?? [])]) if (!all.has(p.provider_id)) all.set(p.provider_id, p);
  const prio = (p: any) => p.display_priorities?.DE ?? p.display_priority ?? 999;
  // Die 30 wichtigsten Dienste plus bekannte Abos, die bei TMDB weiter hinten stehen (z. B. HBO Max, neu seit 01/2026)
  const PIN = /^(hbo max|max|rtl\+|ard plus|arte|wow|joyn|paramount\+|paramount plus|skyshowtime|magentatv|ard mediathek|zdf|dazn|crunchyroll|apple tv\+|apple tv plus|disney plus|netflix|amazon prime video)$/i;
  const list = [...all.values()].filter((p) => okProvider(p.provider_name)).sort((a, b) => prio(a) - prio(b));
  const top = list.slice(0, 30);
  for (const p of list.slice(30)) if (PIN.test(p.provider_name)) top.push(p);
  // Falls TMDB HBO Max für Deutschland (noch) nicht führt: von Hand ergänzen (TMDB-ID 1899)
  if (!top.some((p) => /hbo max|^max$/i.test(p.provider_name))) {
    top.push({ provider_id: 1899, provider_name: "HBO Max", logo_path: all.get(1899)?.logo_path });
  }
  return top.map((p) => withIcon({ id: p.provider_id, name: p.provider_name, logo: img(p.logo_path, "w92") }));
}

async function genres() {
  const [m, t] = await Promise.all([tmdb("genre/movie/list", {}, 7 * 86_400_000), tmdb("genre/tv/list", {}, 7 * 86_400_000)]);
  // m/t: gibt es das Genre bei Filmen / Serien?
  const out = new Map<number, { id: number; name: string; m: boolean; t: boolean }>();
  for (const g of m.genres ?? []) out.set(g.id, { id: g.id, name: g.name, m: true, t: false });
  for (const g of t.genres ?? []) { const o = out.get(g.id); if (o) o.t = true; else out.set(g.id, { id: g.id, name: g.name, m: false, t: true }); }
  return [...out.values()].sort((a, b) => a.name.localeCompare(b.name, "de"));
}

async function feed(p: string, x: string) {
  const prov = p.split(",").filter(Boolean).join("|");
  const without = x.split(",").filter(Boolean).join(",");
  // Kino: Starts in Deutschland letzte Woche bis in zwei Wochen
  const kinoJ = await tmdb("discover/movie", {
    region: "DE", with_release_type: "3|2", "release_date.gte": day(-7), "release_date.lte": day(14),
    sort_by: "popularity.desc", without_genres: without,
  }, 3 * 3600_000);
  const kino: Item[] = (kinoJ.results ?? []).filter((r: any) => r.poster_path).slice(0, 20)
    .map((r: any) => ({ ...base(r, "movie"), kino: true }));

  let stream: Item[] = [], tv: Item[] = [];
  if (prov) {
    // Streaming-Filme: in den letzten 5 Monaten erschienen und bei einem der Dienste (neueste digitale Starts zuerst)
    const sJ = await tmdb("discover/movie", {
      watch_region: "DE", with_watch_providers: prov, with_watch_monetization_types: "flatrate|free|ads",
      "primary_release_date.gte": day(-150), "primary_release_date.lte": day(7),
      sort_by: "popularity.desc", without_genres: without, "vote_count.gte": 5,
    }, 3 * 3600_000);
    const sTop = (sJ.results ?? []).filter((r: any) => r.poster_path).slice(0, 16);
    stream = await Promise.all(sTop.map(async (r: any) => {
      const d = await details("movie", r.id).catch(() => null);
      const rel = (d?.release_dates?.results ?? []).find((x: any) => x.iso_3166_1 === "DE")?.release_dates ?? [];
      const digital = rel.find((x: any) => x.type === 4)?.release_date?.slice(0, 10);
      return { ...base(r, "movie"), date: digital ?? r.release_date, providers: providersDE(d?.["watch/providers"]) };
    }));
    stream.sort((a, b) => (b.date ?? "").localeCompare(a.date ?? ""));

    // Serien mit Folgen in diesen zwei Wochen bei einem der Dienste (ohne Nachrichten, Talk, Daily Soaps)
    const tJ = await tmdb("discover/tv", {
      watch_region: "DE", with_watch_providers: prov, with_watch_monetization_types: "flatrate|free|ads",
      "air_date.gte": day(-3), "air_date.lte": day(10), sort_by: "popularity.desc", "vote_count.gte": 30,
      without_genres: [without, "10763,10767,10766"].filter(Boolean).join(","),
    }, 3 * 3600_000);
    const tTop = (tJ.results ?? []).filter((r: any) => r.poster_path).slice(0, 16);
    tv = await Promise.all(tTop.map(async (r: any) => {
      const d = await details("tv", r.id).catch(() => null);
      const n = d?.next_episode_to_air ?? d?.last_episode_to_air;
      return {
        ...base(r, "tv"), providers: providersDE(d?.["watch/providers"]),
        next: n ? { s: n.season_number, e: n.episode_number, date: n.air_date, name: n.name } : undefined,
        date: n?.air_date ?? r.first_air_date,
      };
    }));
  }
  return { at: new Date().toISOString(), kino, stream, tv };
}

async function title(t: "movie" | "tv", id: number) {
  const d = await details(t, id);
  let fsk: string | undefined;
  if (t === "movie") {
    const de = (d.release_dates?.results ?? []).find((x: any) => x.iso_3166_1 === "DE");
    fsk = (de?.release_dates ?? []).map((x: any) => x.certification).find((c: string) => c) || undefined;
  } else {
    fsk = (d.content_ratings?.results ?? []).find((x: any) => x.iso_3166_1 === "DE")?.rating || undefined;
  }
  const n = d.next_episode_to_air, l = d.last_episode_to_air;
  return {
    id: d.id, t, title: t === "movie" ? d.title : d.name, original: t === "movie" ? d.original_title : d.original_name,
    overview: d.overview || undefined, poster: img(d.poster_path), backdrop: img(d.backdrop_path, "w780"),
    date: t === "movie" ? d.release_date : d.first_air_date, runtime: t === "movie" ? d.runtime : (d.episode_run_time ?? [])[0],
    genres: (d.genres ?? []).map((g: any) => g.name), rating: d.vote_average ? Math.round(d.vote_average * 10) / 10 : undefined,
    votes: d.vote_count, fsk, providers: providersDE(d["watch/providers"]),
    seasons: d.number_of_seasons, status: d.status, ended: t === "tv" ? ["Ended", "Canceled"].includes(d.status) : undefined,
    next: n ? { s: n.season_number, e: n.episode_number, date: n.air_date, name: n.name } : undefined,
    last: l ? { s: l.season_number, e: l.episode_number, date: l.air_date, name: l.name } : undefined,
    networks: (d.networks ?? []).map((x: any) => x.name),
  };
}

async function search(q: string, t: string) {
  if (q.trim().length < 2) return [];
  const j = await tmdb(t === "tv" ? "search/tv" : "search/multi", { query: q, include_adult: "false" }, 3600_000);
  return (j.results ?? []).filter((r: any) => (r.media_type ?? t) !== "person").slice(0, 20)
    .map((r: any) => base(r, (r.media_type ?? t) === "tv" ? "tv" : "movie"));
}

async function shows(ids: string) {
  const list = ids.split(",").map(Number).filter((n) => n > 0).slice(0, 40);
  return await Promise.all(list.map(async (id) => {
    const d = await details("tv", id).catch(() => null);
    if (!d) return { id, t: "tv", title: "?" };
    const n = d.next_episode_to_air, l = d.last_episode_to_air;
    return {
      id, t: "tv", title: d.name, poster: img(d.poster_path), providers: providersDE(d["watch/providers"]),
      ended: ["Ended", "Canceled"].includes(d.status), seasons: d.number_of_seasons,
      next: n ? { s: n.season_number, e: n.episode_number, date: n.air_date, name: n.name } : undefined,
      last: l ? { s: l.season_number, e: l.episode_number, date: l.air_date, name: l.name } : undefined,
    };
  }));
}

async function favs(ids: string) {
  const list = ids.split(",").map((x) => x.split(":")).filter(([t, id]) => (t === "tv" || t === "movie") && Number(id) > 0).slice(0, 60);
  return await Promise.all(list.map(async ([t, idS]) => {
    const id = Number(idS), type = t as "movie" | "tv";
    const d = await details(type, id).catch(() => null);
    if (!d) return { id, t: type, title: "?" };
    const base = { id, t: type, title: type === "movie" ? d.title : d.name, poster: img(d.poster_path), providers: providersDE(d["watch/providers"]) };
    if (type === "tv") {
      const n = d.next_episode_to_air, l = d.last_episode_to_air;
      return {
        ...base, ended: ["Ended", "Canceled"].includes(d.status), seasons: d.number_of_seasons,
        next: n ? { s: n.season_number, e: n.episode_number, date: n.air_date, name: n.name } : undefined,
        last: l ? { s: l.season_number, e: l.episode_number, date: l.air_date, name: l.name } : undefined,
      };
    }
    // Film: Starttermine in Deutschland (Kino = Typ 2/3, digital = Typ 4)
    const rel = (d.release_dates?.results ?? []).find((x: any) => x.iso_3166_1 === "DE")?.release_dates ?? [];
    const first = (types: number[]) => rel.filter((x: any) => types.includes(x.type)).map((x: any) => String(x.release_date ?? "").slice(0, 10)).filter(Boolean).sort()[0];
    return { ...base, kino: first([2, 3]), digital: first([4]), date: d.release_date || undefined };
  }));
}

// Film- und Serien-Genres heißen bei TMDB teils anders (Action ↔ Action & Adventure)
const GENRE_MAP: Record<"movie" | "tv", Record<number, number[]>> = {
  tv: { 28: [10759], 12: [10759], 878: [10765], 14: [10765], 10752: [10768] },
  movie: { 10759: [28, 12], 10765: [878, 14], 10768: [10752] },
};
const MOVIE_ONLY = new Set([28, 12, 878, 14, 10752, 27, 53, 36, 10402, 10749, 10770]);
const TV_ONLY = new Set([10759, 10765, 10768, 10762, 10763, 10764, 10766, 10767]);
function genresFor(type: "movie" | "tv", ids: number[]): number[] {
  const own = type === "movie" ? TV_ONLY : MOVIE_ONLY;
  const out = new Set<number>();
  for (const id of ids) {
    if (!own.has(id)) out.add(id);
    for (const m of GENRE_MAP[type][id] ?? []) out.add(m);
  }
  return [...out];
}

async function random(t: string, p: string, x: string, min: number, len: number, g = "") {
  const want = g.split(",").map(Number).filter((n) => n > 0);
  // Mit Wunsch-Genres nur die Art nehmen, für die es passende Genres gibt
  const types: ("movie" | "tv")[] = (t === "tv" ? ["tv"] : t === "movie" ? ["movie"] : ["movie", "tv"])
    .filter((ty) => !want.length || genresFor(ty as "movie" | "tv", want).length > 0) as ("movie" | "tv")[];
  if (!types.length) return null;
  const type = types[Math.floor(Math.random() * types.length)];
  const withG = want.length ? genresFor(type, want).join("|") : undefined;
  const params: Record<string, string | number | undefined> = {
    with_genres: withG,
    watch_region: "DE", with_watch_providers: p.split(",").filter(Boolean).join("|") || undefined,
    with_watch_monetization_types: p ? "flatrate|free|ads" : undefined,
    without_genres: x.split(",").filter(Boolean).join(",") || undefined,
    "vote_average.gte": min > 0 ? min : undefined, "vote_count.gte": 150, sort_by: "popularity.desc",
    "with_runtime.lte": type === "movie" && len > 0 ? len : undefined,
  };
  const first = await tmdb("discover/" + type, { ...params, page: 1 }, 6 * 3600_000);
  const pages = Math.max(1, Math.min(first.total_pages ?? 1, 15));
  const page = 1 + Math.floor(Math.random() * pages);
  const j = page === 1 ? first : await tmdb("discover/" + type, { ...params, page }, 6 * 3600_000);
  const pool = (j.results ?? []).filter((r: any) => r.poster_path && r.overview);
  if (!pool.length) return null;
  const pick = pool[Math.floor(Math.random() * pool.length)];
  return await title(type, pick.id);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const url = new URL(req.url);
  const what = url.pathname.split("/").filter(Boolean).pop() ?? "";
  const routes = ["providers", "genres", "feed", "title", "search", "shows", "favs", "random"];
  if (!routes.includes(what)) return new Response("Unbekannte Abfrage", { status: 404, headers: cors });
  if (!(await keyOk(req.headers.get("x-kueche-key"))) && !(await userOk(req.headers.get("authorization")))) {
    return new Response("Kein Zugang", { status: 401, headers: cors });
  }
  const q = url.searchParams;
  await loadIcons();      // einmal pro Instanz, danach aus dem Speicher
  let body: unknown;
  try {
    const t = (q.get("t") === "tv" ? "tv" : "movie") as "movie" | "tv";
    body = what === "providers" ? await providers()
      : what === "genres" ? await genres()
      : what === "feed" ? await feed(q.get("p") ?? "", q.get("x") ?? "")
      : what === "title" ? await title(t, Number(q.get("id")))
      : what === "search" ? await search(q.get("q") ?? "", q.get("t") ?? "multi")
      : what === "shows" ? await shows(q.get("ids") ?? "")
      : what === "favs" ? await favs(q.get("ids") ?? "")
      : await random(q.get("t") ?? "any", q.get("p") ?? "", q.get("x") ?? "", Number(q.get("min") ?? 0), Number(q.get("len") ?? 0), q.get("g") ?? "");
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify(body), { headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
});
