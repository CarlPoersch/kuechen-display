// ============================================================
// "Heute": die Startseite von Hubert.
// Ein Blick genügt: Uhr, Wetter, nächster Bus, Live-Sport, News, Küche.
// Darunter die Kacheln zu den Bereichen.
//
// Warum hier keine eigene App (Launcher.register): Die Startseite ist der
// Startbildschirm selbst. Sie meldet sich mit Launcher.onHome an und lädt
// nur, solange sie zu sehen ist (schont das alte iPad und die Datenquellen).
// ============================================================
(function () {
  var F = Hubert.Feeds, esc = Launcher.esc;
  function $(id) { return document.getElementById(id); }

  /** Kartenkopf: Symbol + Titel links, optional etwas rechts (z. B. "Alle ›") */
  function head(icon, title, right) {
    return '<div class="h-card-h"><span class="h-title"><span class="h-ic">' + icon + "</span>" + esc(title) + "</span>" + (right || "") + "</div>";
  }

  // ---------- Wetter ----------
  function drawWeather() {
    var box = $("h-weather"), c = F.cached("wetter");
    if (!box) return;
    if (!c || !c.data || !c.data.current) { box.innerHTML = '<div class="h-w-txt">Wetter lädt …</div>'; return; }
    var w = c.data, cur = w.current, d = w.daily;
    var now = F.weather(cur.weather_code, cur.is_day), temp = cur.temperature_2m, nowMs = Date.now();
    // Messwert der DWD-Station Regensburg hat Vorrang vor der Vorhersage (wenn nicht älter als 2 Std)
    var obs = w.obs && nowMs - Date.parse(w.obs.timestamp) < 2 * 3600000 ? w.obs : null;
    var wet = false;
    if (obs) {
      if (obs.temperature != null) temp = obs.temperature;
      var cond = { rain: ["🌧", "Regen"], drizzle: ["🌦", "Nieselregen"], sleet: ["🌨", "Schneeregen"], snow: ["🌨", "Schnee"],
        hail: ["🌨", "Hagel"], thunderstorm: ["⛈", "Gewitter"], fog: ["🌫", "Nebel"] }[obs.condition];
      if (cond) now = cond;
      wet = /rain|drizzle|sleet|snow|hail|thunderstorm/.test(obs.condition || "") || (obs.precipitation_10 || 0) > 0;
    }
    if ((cur.precipitation || 0) > 0) wet = true;
    // Regen in den nächsten Stunden? Warum: "Schirm mitnehmen?" ist die eigentliche Frage.
    var rain = 0, rainAt = null, h = w.hourly;
    for (var i = 0; h && i < h.time.length; i++) {
      var t = Date.parse(h.time[i]);
      if (t < nowMs || t > nowMs + 6 * 3600000) continue;
      if (h.precipitation_probability[i] > rain) { rain = h.precipitation_probability[i]; rainAt = t; }
    }
    var rainTxt = wet ? "☂️ Es regnet gerade" : rain >= 40 ? "☂️ Regen " + rain + " % gegen " + F.hhmm(rainAt) : "Kein Regen in Sicht";
    var html = '<div class="h-w-now"><span class="h-w-ic">' + now[0] + '</span><span class="h-w-t">' +
      Math.round(temp) + '°</span></div><div class="h-w-txt">' + esc(now[1]) +
      " · ↑" + Math.round(d.temperature_2m_max[0]) + "° ↓" + Math.round(d.temperature_2m_min[0]) + "°</div>" +
      '<div class="h-w-rain">' + rainTxt + "</div>";
    html += '<div class="h-w-days">';
    for (var k = 1; k < Math.min(4, d.time.length); k++) {
      var day = new Date(d.time[k]);
      html += '<div><span>' + ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"][day.getDay()] + "</span>" +
        F.weather(d.weather_code[k], 1)[0] + "<b>" + Math.round(d.temperature_2m_max[k]) + "°</b></div>";
    }
    box.innerHTML = html + "</div>";
  }

  // Begrüßung je nach Tageszeit
  function drawGreet() {
    var el = $("h-greet"), h = new Date().getHours();
    if (el) el.textContent = h < 5 ? "Gute Nacht" : h < 11 ? "Guten Morgen" : h < 18 ? "Guten Tag" : "Guten Abend";
  }

  // ---------- Nächster Bus (zum Hbf, wie in "Fahrten") ----------
  var bus = { list: [], at: 0, err: false };
  function loadBus() {
    if (!window.EFA) return;
    var routes = Launcher.storage("fahrten").get("routen", null) || EFA.seedRoutes();
    Promise.all(EFA.CFG.stops.map(function (s, i) {
      return EFA.loadDepartures(i, routes).then(function (deps) {
        return deps.map(function (d) { return { d: d, s: s, leave: d.actual.getTime() - s.walkMinutes * 60000 }; });
      }, function () { return null; });
    })).then(function (lists) {
      var all = [], ok = false;
      lists.forEach(function (l) { if (l) { ok = true; all = all.concat(l); } });
      if (ok) { bus.list = all.sort(function (a, b) { return a.leave - b.leave; }); bus.at = Date.now(); }
      bus.err = !ok;
      drawBus();
    });
  }
  function drawBus() {
    var box = $("h-bus");
    if (!box) return;
    var now = Date.now();
    var next = [];
    // Zwei Möglichkeiten zeigen, die zweite mindestens 2 Min später (sonst sagt sie nichts Neues)
    bus.list.forEach(function (x) {
      if (x.leave <= now - 30000 || next.length >= 2) return;
      if (!next.length || x.leave - next[0].leave >= 120000) next.push(x);
    });
    var top = head("🚌", "Nächster Bus zum Hbf");
    if (!next.length) {
      box.innerHTML = top + '<div class="h-muted">' + (bus.at ? "Gerade kein Bus" : bus.err ? "Fahrplan nicht erreichbar" : "Lädt …") + "</div>";
      return;
    }
    box.innerHTML = top + next.map(function (x, i) {
      var m = Math.floor((x.leave - now) / 60000);
      var los = m < 1 ? "jetzt los" : "los in " + m + " Min";
      var cls = m < 1 ? "late" : m <= 5 ? "soon" : "";
      return '<div class="h-bus-row' + (i ? " h-bus-2" : "") + '"><span class="h-bus-line">' + esc(x.d.line) + "</span>" +
        '<div class="h-bus-txt"><span class="h-bus-los ' + cls + '">' + los + "</span>" +
        '<span class="h-bus-stop">' + F.hhmm(x.d.actual) + " ab " + esc(x.s.title) + "</span></div></div>";
    }).join("");
  }

  // ---------- Termine (aus der Kalender-App des Geräts) ----------
  var DAYS = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"];
  function evRow(e, now) {
    var s = new Date(e.s), en = new Date(e.e);
    var running = !e.a && s.getTime() <= now && en.getTime() > now;
    var time = e.a ? "ganztägig" : running ? "läuft" : F.hhmm(s);
    return '<div class="h-ev' + (running ? " is-now" : "") + '"><span class="h-ev-time">' + time + "</span>" +
      '<span class="h-ev-bar" style="background:' + esc(e.f || "#8a7d72") + '"></span>' +
      '<span class="h-ev-txt"><span class="h-ev-t">' + esc(e.t) + "</span>" +
      (e.o || !e.a ? '<span class="h-ev-sub">' + (e.a ? "" : F.hhmm(s) + "–" + F.hhmm(en)) +
        (e.o ? (e.a ? "" : " · ") + esc(e.o) : "") + "</span>" : "") + "</span></div>";
  }
  function drawCalendar() {
    var box = $("h-cal");
    if (!box) return;
    var h = head("📅", "Termine");
    var c = F.cached("kalender"), now = Date.now();
    if (!F.inApp()) {
      box.innerHTML = h + '<div class="h-muted">Deine Termine siehst du in der Hubert-App.</div>';
      return;
    }
    if (!c) { box.innerHTML = h + '<div class="h-muted">Lädt …</div>'; return; }
    if (c.data.status === "denied") {
      box.innerHTML = h + '<div class="h-muted">Kein Zugriff auf den Kalender. Erlauben unter Einstellungen › Datenschutz › Kalender › Hubert.</div>';
      return;
    }
    var evs = (c.data.events || []).filter(function (e) { return Date.parse(e.e) > now; });
    var today = evs.filter(function (e) { return F.dayDiff(e.s) <= 0; });
    var tomorrow = evs.filter(function (e) { return F.dayDiff(e.s) === 1; });
    var out = "", left = 5;
    function block(label, list) {
      if (!list.length || left <= 0) return;
      out += '<div class="h-n-sec">' + label + "</div>" + list.slice(0, left).map(function (e) { return evRow(e, now); }).join("");
      left -= Math.min(left, list.length);
    }
    block("Heute", today);
    block("Morgen", tomorrow);
    if (!out) {
      var next = evs[0];
      out = '<div class="h-k-line h-k-main">Heute und morgen frei 🎉</div>' + (next ?
        '<div class="h-k-line h-muted">Nächster Termin: ' + DAYS[new Date(next.s).getDay()] + ", " + new Date(next.s).getDate() + "." +
        (new Date(next.s).getMonth() + 1) + ". · " + esc(next.t) + "</div>" : "");
    }
    box.innerHTML = h + out;
  }

  // ---------- Sport ----------
  /** Auswahl für die Startseite: Live zuerst, dann Favoriten (Bayern, DFB, Deutsche), dann Rest */
  function pickMatches(list) {
    var now = Date.now();
    var live = list.filter(function (m) { return m.state === "in"; });
    var next = list.filter(function (m) { return m.state === "pre"; }).sort(function (a, b) {
      // Favoriten zuerst, aber nur wenn sie in den nächsten 3 Tagen spielen
      var fa = a.prio === 1 && Date.parse(a.date) < now + 3 * 86400000 ? 0 : 1;
      var fb = b.prio === 1 && Date.parse(b.date) < now + 3 * 86400000 ? 0 : 1;
      return fa - fb || Date.parse(a.date) - Date.parse(b.date);
    });
    var done = list.filter(function (m) { return m.state === "post" && m.prio === 1; });
    return live.concat(next.slice(0, 3), done.slice(0, 2)).slice(0, 4);
  }
  function drawSport() {
    var box = $("h-sport"), c = F.cached("sport");
    if (!box) return;
    var h = head("⚽️", "Sport", stamp(c) || '<span class="h-more">Alle ›</span>');
    if (!F.cloud()) h += '<div class="h-muted">Nur in der Cloud-Version verfügbar.</div>';
    else if (!c) h += '<div class="h-muted">Lädt …</div>';
    else {
      var pick = pickMatches(c.data.matches || []);
      h += pick.length ? pick.map(function (m) { return F.matchHtml(m); }).join("")
        : '<div class="h-muted">Heute keine Spiele deiner Teams.</div>';
    }
    box.innerHTML = h;
  }

  // ---------- News ----------
  function newsLine(n) {
    return '<a class="h-n" href="' + esc(n.u) + '" target="_blank" rel="noopener">' +
      '<span class="h-n-t">' + esc(n.t) + '</span><span class="h-n-d">' + esc(F.ago(n.d)) + "</span></a>";
  }
  function drawNews() {
    var box = $("h-news"), br = $("h-breaking"), c = F.cached("news");
    if (!box) return;
    var d = c && c.data;
    // Eilmeldung: ganz oben, farbig
    if (br) {
      var b = d && d.breaking && d.breaking[0];
      br.innerHTML = b ? '<a class="h-break" href="' + esc(b.u) + '" target="_blank" rel="noopener"><b>EILMELDUNG</b> ' + esc(b.t) + "</a>" : "";
    }
    var h = head("📰", "News", stamp(c) || '<span class="h-more" data-home-go="news">Alle ›</span>');
    if (!F.cloud()) h += '<div class="h-muted">Nur in der Cloud-Version verfügbar.</div>';
    else if (!d) h += '<div class="h-muted">Lädt …</div>';
    else {
      [["de", "Deutschland"], ["welt", "Welt"], ["ki", "KI"]].forEach(function (r) {
        var list = (d[r[0]] || []).slice(0, 2);
        if (!list.length) return;
        h += '<div class="h-n-sec">' + r[1] + "</div>" + list.map(newsLine).join("");
      });
    }
    box.innerHTML = h;
  }

  /** "Stand 14:20", nur wenn der Stand älter ist – Warum: zeigt, dass eine Quelle hakt */
  function stamp(c) {
    if (!c) return "";
    var old = Date.now() - c.at > 15 * 60000;
    return old ? '<span class="h-stamp">Stand ' + F.hhmm(c.at) + "</span>" : "";
  }

  // ---------- Küche ----------
  var recipesById = null;
  function drawKueche() {
    var box = $("h-kueche"), K = window.Kueche;
    if (!box || !K) return;
    if (!recipesById) {
      recipesById = {};
      K.loadIndex().then(function (rs) { rs.forEach(function (r) { recipesById[r.id] = r; }); drawKueche(); });
    }
    var planned = K.planFor(K.isoDate(new Date())).map(function (p) { return recipesById[p.id]; }).filter(Boolean);
    var open = K.shopItems().filter(function (i) { return !i.done; }).length;
    var exp = K.pantryItems().filter(function (p) { return p.mhd && K.daysUntil(p.mhd) <= 2; }).length;
    var h = head("🍳", "Küche heute");
    h += '<div class="h-k-line h-k-main">' + (planned.length ? esc(planned[0].icon + " " + planned[0].title) : '<span class="h-muted">Noch nichts geplant</span>') + "</div>";
    h += '<div class="h-k-line">🛒 ' + (open ? open + (open === 1 ? " Sache" : " Sachen") + " auf der Liste" : "Einkaufsliste leer") + "</div>";
    if (exp) h += '<div class="h-k-line h-warn">⏳ ' + exp + " bald verbrauchen</div>";
    box.innerHTML = h;
  }

  // ---------- Ein- und Ausschalten ----------
  var stops = [], timers = [];
  Launcher.onHome({
    show: function () {
      drawGreet(); drawWeather(); drawCalendar(); drawSport(); drawNews(); drawBus(); drawKueche();
      stops = [
        F.subscribe("wetter", drawWeather), F.subscribe("sport", drawSport), F.subscribe("news", drawNews),
        F.subscribe("kalender", drawCalendar),
        F.keepFresh("wetter"), F.keepFresh("sport"), F.keepFresh("news"),
        Launcher.store ? Launcher.store.subscribe(drawKueche) : function () {}
      ];
      if (Date.now() - bus.at > 50000) loadBus();
      timers = [
        setInterval(loadBus, 60000),
        // Countdown, "vor 5 Min" usw. aktuell halten, ohne neu zu laden
        setInterval(function () { drawGreet(); drawCalendar(); drawBus(); drawSport(); drawNews(); }, 20000)
      ];
    },
    hide: function () {
      stops.forEach(function (fn) { fn(); });
      timers.forEach(clearInterval);
      stops = []; timers = [];
    }
  });

  document.addEventListener("click", function (e) {
    var t = e.target.closest && e.target.closest("[data-home-go]");
    if (t) Launcher.navigate(t.getAttribute("data-home-go"));
  });
})();
