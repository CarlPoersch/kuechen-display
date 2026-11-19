// ============================================================
// Hubert.Feeds: holt Sport, News und Wetter und merkt sich den letzten Stand.
//
// Warum ein gemeinsamer Baustein: Startseite, Sport- und News-Bereich zeigen
// dieselben Daten. So wird nur einmal geladen, und nach einem Neustart ist
// sofort der letzte Stand da (statt eines leeren Kastens).
//
// Quellen:
//   sport, news → Supabase-Funktion "feeds" (Tagesschau/heise/ESPN)
//   wetter      → Open-Meteo direkt (braucht keinen Schlüssel, erlaubt Browser-Abrufe)
// ============================================================
(function () {
  var mem = Launcher.storage("hubert");
  var LAT = 49.0134, LON = 12.1016; // Regensburg
  var OBS_URL = "https://api.brightsky.dev/current_weather?lat=" + LAT + "&lon=" + LON;
  var listeners = { sport: [], news: [], wetter: [], kalender: [] };
  var inflight = {};

  function cloud() { return !!(window.CONFIG && CONFIG.supabaseUrl); }

  function url(kind) {
    if (kind === "wetter") {
      return "https://api.open-meteo.com/v1/forecast?latitude=" + LAT + "&longitude=" + LON +
        "&current=temperature_2m,apparent_temperature,weather_code,is_day,precipitation" +
        "&hourly=temperature_2m,precipitation_probability,weather_code" +
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset" +
        "&timezone=Europe%2FBerlin&forecast_days=4";
    }
    return CONFIG.supabaseUrl + "/functions/v1/feeds/" + kind;
  }

  /** Letzter gespeicherter Stand: { at: Zeitstempel, data } oder null */
  function cached(kind) { return mem.get("feed:" + kind, null); }

  /** Neu laden. Fehler werden geschluckt: Dann bleibt einfach der alte Stand stehen. */
  function load(kind) {
    if (inflight[kind]) return inflight[kind];
    if (kind !== "wetter" && !cloud()) return Promise.resolve(cached(kind));
    var headers = {};
    if (kind !== "wetter") headers["x-kueche-key"] = Launcher.store ? Launcher.store.householdKey() : "";
    function get(u, h) {
      return fetch(u, { headers: h || {}, cache: "no-store" })
        .then(function (r) { if (!r.ok) throw new Error("HTTP " + r.status); return r.json(); });
    }
    var job = get(url(kind), headers);
    if (kind === "wetter") {
      // Warum zwei Quellen: Open-Meteo liefert die Vorhersage, verpasst aber oft leichten Regen.
      // Der Deutsche Wetterdienst (über Bright Sky) misst an der Station Regensburg, was JETZT ist.
      job = Promise.all([job, get(OBS_URL).catch(function () { return null; })]).then(function (r) {
        r[0].obs = r[1] && r[1].weather ? r[1].weather : null;
        return r[0];
      });
    }
    inflight[kind] = job
      .then(function (data) {
        var entry = { at: Date.now(), data: data };
        mem.set("feed:" + kind, entry);
        listeners[kind].forEach(function (fn) { try { fn(entry); } catch (e) { console.error(e); } });
        return entry;
      })
      .catch(function (e) { console.warn("Feed", kind, e); return cached(kind); })
      .then(function (x) { inflight[kind] = null; return x; });
    return inflight[kind];
  }

  function subscribe(kind, fn) {
    listeners[kind].push(fn);
    return function () { listeners[kind] = listeners[kind].filter(function (f) { return f !== fn; }); };
  }

  // ---------- Takt: wie oft neu laden ----------
  // Sport: alle 30 s, solange etwas live ist oder gleich beginnt, sonst alle 10 min.
  function sportInterval() {
    var c = cached("sport"), now = Date.now();
    var hot = c && c.data && (c.data.matches || []).some(function (m) {
      var t = Date.parse(m.date);
      return m.state === "in" || (m.state === "pre" && t < now + 5 * 60000 && t > now - 3 * 3600000);
    });
    return hot ? 30000 : 10 * 60000;
  }
  var INTERVAL = {
    sport: sportInterval,
    news: function () { return 5 * 60000; },
    wetter: function () { return 15 * 60000; }
  };

  /**
   * Hält die Daten frisch, solange jemand zuschaut. Gibt eine Stopp-Funktion zurück.
   * Lädt sofort, wenn der gespeicherte Stand älter als das Intervall ist.
   */
  function keepFresh(kind) {
    var timer = null, stopped = false;
    function tick() {
      if (stopped) return;
      var c = cached(kind), every = INTERVAL[kind]();
      var due = !c || Date.now() - c.at >= every - 2000;
      (due ? load(kind) : Promise.resolve()).then(function () {
        if (stopped) return;
        var c2 = cached(kind), wait = INTERVAL[kind]();
        var left = c2 ? Math.max(5000, wait - (Date.now() - c2.at)) : wait;
        timer = setTimeout(tick, left);
      });
    }
    tick();
    return function () { stopped = true; clearTimeout(timer); };
  }

  // ---------- Hilfen für die Anzeige ----------
  function pad(n) { return (n < 10 ? "0" : "") + n; }
  function hhmm(d) { d = new Date(d); return pad(d.getHours()) + ":" + pad(d.getMinutes()); }
  var WD = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"];
  function dayDiff(d) {
    var a = new Date(d); a.setHours(0, 0, 0, 0);
    var b = new Date(); b.setHours(0, 0, 0, 0);
    return Math.round((a - b) / 86400000);
  }
  /** "heute 20:45", "morgen 18:00", "Di 21:00", "gestern" */
  function when(d) {
    var dd = dayDiff(d);
    if (dd === 0) return hhmm(d);
    if (dd === 1) return "morgen " + hhmm(d);
    if (dd === -1) return "gestern";
    var x = new Date(d);
    return WD[x.getDay()] + " " + (dd < 0 ? x.getDate() + "." + (x.getMonth() + 1) + "." : hhmm(d));
  }
  /** "vor 5 Min", "vor 2 Std", "Mo 14:20" */
  function ago(d) {
    var m = Math.round((Date.now() - new Date(d)) / 60000);
    if (m < 1) return "gerade eben";
    if (m < 60) return "vor " + m + " Min";
    if (m < 12 * 60) return "vor " + Math.round(m / 60) + " Std";
    var x = new Date(d);
    return WD[x.getDay()] + " " + hhmm(x);
  }
  function flag(c) { return c === "GER" ? "🇩🇪" : ""; }

  // Wettercodes (WMO) → Symbol und Text
  function weather(code, day) {
    var n = day === 0;
    var W = {
      0: [n ? "🌙" : "☀️", "Klar"], 1: [n ? "🌙" : "🌤", "Überwiegend klar"], 2: ["⛅️", "Teils bewölkt"], 3: ["☁️", "Bedeckt"],
      45: ["🌫", "Nebel"], 48: ["🌫", "Reifnebel"], 51: ["🌦", "Leichter Niesel"], 53: ["🌦", "Niesel"], 55: ["🌧", "Starker Niesel"],
      56: ["🌧", "Gefrierender Niesel"], 57: ["🌧", "Gefrierender Niesel"], 61: ["🌦", "Leichter Regen"], 63: ["🌧", "Regen"],
      65: ["🌧", "Starker Regen"], 66: ["🌧", "Eisregen"], 67: ["🌧", "Eisregen"], 71: ["🌨", "Leichter Schnee"], 73: ["🌨", "Schnee"],
      75: ["❄️", "Starker Schnee"], 77: ["🌨", "Schneegriesel"], 80: ["🌦", "Regenschauer"], 81: ["🌧", "Regenschauer"],
      82: ["⛈", "Heftige Schauer"], 85: ["🌨", "Schneeschauer"], 86: ["🌨", "Schneeschauer"], 95: ["⛈", "Gewitter"],
      96: ["⛈", "Gewitter mit Hagel"], 99: ["⛈", "Gewitter mit Hagel"]
    };
    return W[code] || ["🌡", ""];
  }

  /** Eine Spielzeile als HTML (Fußball oder Tennis), genutzt von Startseite und Sport-Bereich */
  function matchHtml(m, opts) {
    var esc = Launcher.esc;
    opts = opts || {};
    var live = m.state === "in", post = m.state === "post";
    var right = live ? '<span class="s-live">' + esc(m.detail || "live") + "</span>"
      : post ? '<span class="s-end">' + esc(m.detail || "Ende") + (opts.day ? " · " + esc(when(m.date)) : "") + "</span>"
      : '<span class="s-time">' + esc(when(m.date)) + "</span>";
    var head = '<div class="s-meta"><span class="s-comp">' + (m.sport === "tn" ? "🎾 " : "⚽️ ") + esc(m.comp) +
      (m.round ? " · " + esc(m.round) : "") + "</span>" + right + "</div>";
    function side(s) {
      var name = '<span class="s-name' + (post && s.win ? " s-win" : "") + '">' + esc(s.n) + (flag(s.c) ? " " + flag(s.c) : "") + "</span>";
      var score = "";
      if (m.sport === "tn" && s.sets && s.sets.length) {
        score = '<span class="s-sets">' + s.sets.map(function (v) { return "<b>" + esc(v) + "</b>"; }).join("") + "</span>";
      } else if (m.sport === "fb" && s.score != null && m.state !== "pre") {
        score = '<span class="s-score">' + esc(s.score) + "</span>";
      }
      return '<div class="s-side">' + name + score + "</div>";
    }
    return '<div class="s-match' + (live ? " is-live" : "") + (m.prio === 1 ? " is-fav" : "") + '">' + head +
      side(m.a) + side(m.b) + "</div>";
  }

  // ---------- Kalender: kommt nicht aus dem Netz, sondern von der Hubert-App ----------
  // Warum: Die native App liest die Termine direkt aus dem Gerät (alle Kalender,
  // nichts verlässt das Gerät) und ruft dafür HubertNative.setCalendar(...) auf.
  function inApp() { return !!window.HUBERT_APP; }
  window.HubertNative = {
    setCalendar: function (events, status) {
      var entry = { at: Date.now(), data: { status: status || "ok", events: events || [] } };
      mem.set("feed:kalender", entry);
      listeners.kalender.forEach(function (fn) { try { fn(entry); } catch (e) { console.error(e); } });
    }
  };

  window.Hubert = window.Hubert || {};
  Hubert.Feeds = {
    cloud: cloud, inApp: inApp, cached: cached, load: load, subscribe: subscribe, keepFresh: keepFresh,
    hhmm: hhmm, when: when, ago: ago, dayDiff: dayDiff, weather: weather, matchHtml: matchHtml, flag: flag
  };
})();
