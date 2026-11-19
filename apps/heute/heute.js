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

  // ---------- Wetter ----------
  function drawWeather() {
    var box = $("h-weather"), c = F.cached("wetter");
    if (!box) return;
    if (!c || !c.data || !c.data.current) { box.innerHTML = '<div class="h-muted">Wetter lädt …</div>'; return; }
    var w = c.data, cur = w.current, d = w.daily;
    var now = F.weather(cur.weather_code, cur.is_day);
    // Regen in den nächsten Stunden? Warum: "Schirm mitnehmen?" ist die eigentliche Frage.
    var rain = 0, rainAt = null, h = w.hourly, nowMs = Date.now();
    for (var i = 0; h && i < h.time.length; i++) {
      var t = Date.parse(h.time[i]);
      if (t < nowMs - 3600000 || t > nowMs + 6 * 3600000) continue;
      if (h.precipitation_probability[i] > rain) { rain = h.precipitation_probability[i]; rainAt = t; }
    }
    var html = '<div class="h-w-now"><span class="h-w-ic">' + now[0] + '</span><span class="h-w-t">' +
      Math.round(cur.temperature_2m) + '°</span></div><div class="h-w-txt">' + esc(now[1]) +
      " · " + Math.round(d.temperature_2m_max[0]) + "° / " + Math.round(d.temperature_2m_min[0]) + "°</div>" +
      '<div class="h-w-rain">' + (rain >= 40 ? "☂️ Regen " + rain + " % " + (rainAt <= nowMs ? "jetzt" : "gegen " + F.hhmm(rainAt)) : "Kein Regen in Sicht") + "</div>";
    html += '<div class="h-w-days">';
    for (var k = 1; k < Math.min(4, d.time.length); k++) {
      var day = new Date(d.time[k]);
      html += '<div><span>' + ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"][day.getDay()] + "</span>" +
        F.weather(d.weather_code[k], 1)[0] + "<b>" + Math.round(d.temperature_2m_max[k]) + "°</b></div>";
    }
    box.innerHTML = html + "</div>";
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
    if (!next.length) {
      box.innerHTML = '<div class="h-muted">' + (bus.at ? "Kein Bus zum Hbf" : bus.err ? "Fahrplan nicht erreichbar" : "Bus lädt …") + "</div>";
      return;
    }
    box.innerHTML = next.map(function (x, i) {
      var m = Math.floor((x.leave - now) / 60000);
      var los = m < 1 ? "jetzt los" : "los in " + m + " Min";
      var cls = m < 1 ? "late" : m <= 5 ? "soon" : "";
      return '<div class="h-bus-row' + (i ? " h-bus-2" : "") + '"><span class="h-bus-line">' + esc(x.d.line) + "</span>" +
        '<span class="h-bus-los ' + cls + '">' + los + "</span>" +
        '<span class="h-bus-stop">ab ' + esc(x.s.title) + " " + F.hhmm(x.d.actual) + "</span></div>";
    }).join("");
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
    var h = '<div class="h-card-h"><span>⚽️ Sport ›</span>' + stamp(c) + "</div>";
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
    var h = '<div class="h-card-h" data-home-go="news"><span>📰 News ›</span>' + stamp(c) + "</div>";
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
    var parts = [];
    parts.push(planned.length ? esc(planned[0].icon + " " + planned[0].title) : "Noch nichts geplant");
    parts.push("🛒 " + open + (open === 1 ? " Sache" : " Sachen") + " kaufen");
    if (exp) parts.push('<span class="h-warn">⏳ ' + exp + " bald verbrauchen</span>");
    box.innerHTML = '<span class="h-k-h">🍳 Heute</span>' + parts.join('<span class="h-dot">·</span>');
  }

  // ---------- Ein- und Ausschalten ----------
  var stops = [], timers = [];
  Launcher.onHome({
    show: function () {
      drawWeather(); drawSport(); drawNews(); drawBus(); drawKueche();
      stops = [
        F.subscribe("wetter", drawWeather), F.subscribe("sport", drawSport), F.subscribe("news", drawNews),
        F.keepFresh("wetter"), F.keepFresh("sport"), F.keepFresh("news"),
        Launcher.store ? Launcher.store.subscribe(drawKueche) : function () {}
      ];
      if (Date.now() - bus.at > 50000) loadBus();
      timers = [
        setInterval(loadBus, 60000),
        // Countdown, "vor 5 Min" usw. aktuell halten, ohne neu zu laden
        setInterval(function () { drawBus(); drawSport(); drawNews(); }, 20000)
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
