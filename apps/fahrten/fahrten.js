// ============================================================
// Unterapp "Fahrten" – die Anzeige vom Bus-Display, fürs iPad.
// Die Rechenlogik steckt in efa.js (aus der Firmware übernommen),
// hier geht es nur um die Darstellung.
//
// Spalten wie am Display:
//   Los = wann du zu Hause losgehen musst (Countdown)
//   Ab  = Abfahrt an der Haltestelle (rot bei Verspätung)
//   An  = Ankunft am Ziel
// ============================================================
(function () {
  var REFRESH_MS = 60 * 1000;  // Daten jede Minute neu laden (wie die Firmware)
  var TICK_MS = 5 * 1000;      // Countdown alle 5 s neu zeichnen
  var ROWS = { hbf: 4, philipp: 3 };

  // Linienfarben wie am Display: Stadtbusse farbig, Regionalbusse blau
  var LINE_COLORS = { "3": "#E8820C", "5": "#2E9E44", "6": "#D7262F", "C6": "#8E1B3C" };
  function lineColor(l) { return LINE_COLORS[l] || "#3D6FB6"; }

  function pad(n) { return (n < 10 ? "0" : "") + n; }
  function hhmm(d) { return d ? pad(d.getHours()) + ":" + pad(d.getMinutes()) : "–"; }
  // "Regensburg Hbf" -> "Hbf": Stadtname spart Platz
  function shortStop(s) { return String(s || "").replace(/^Regensburg,? /, ""); }

  var esc = function (s) { return Launcher.esc(s); };
  function badge(line) {
    return '<span class="f-badge" style="background:' + lineColor(line) + '">' + esc(line) + "</span>";
  }

  Launcher.register({
    id: "fahrten",
    name: "Fahrten",
    icon: "🚌",
    color: "#1C3550",

    mount: function (el, ctx) {
      var CFG = EFA.CFG;
      var dest = ctx.storage.get("ziel", "hbf");
      // Gelernte Routen merken. Warum: Nach einem Neuladen muss die App nicht neu lernen.
      var routes = ctx.storage.get("routen", null) || EFA.seedRoutes();
      var lastLearn = ctx.storage.get("gelernt", 0);
      var data = { hbf: [], philipp: [] };      // pro Ziel: Liste pro Haltestelle
      var status = { hbf: [], philipp: [] };    // pro Haltestelle: "ok" | "fehler"
      var updated = { hbf: null, philipp: null };
      var loading = false;

      el.innerHTML =
        '<div class="f-wrap">' +
        '<div class="f-top"><div class="f-title">Zuhause →</div>' +
        '<div class="f-seg"><button data-d="hbf">Hbf</button><button data-d="philipp">Philipp</button></div>' +
        '<div class="f-status"></div></div>' +
        '<div class="f-stops"></div></div>';

      var segBtns = el.querySelectorAll(".f-seg button");
      segBtns.forEach(function (b) {
        b.onclick = function () {
          dest = b.getAttribute("data-d");
          ctx.storage.set("ziel", dest);
          render();
          refresh();
        };
      });

      // ---------- Daten laden ----------
      function refresh() {
        if (loading) return;
        loading = true;
        var d = dest;
        render();
        // Alle Haltestellen parallel abfragen. Warum parallel: geht schneller als
        // nacheinander, und das iPad hat (anders als das ESP32) genug Speicher dafür.
        var jobs = CFG.stops.map(function (s, i) {
          var p = d === "hbf" ? EFA.loadDepartures(i, routes) : EFA.loadTrips(i);
          return p.then(function (list) {
            data[d][i] = list; status[d][i] = "ok";
          }, function (err) {
            status[d][i] = "fehler"; // alte Daten behalten, aber markieren
            console.warn("Fahrten", s.title, err);
          });
        });
        Promise.all(jobs).then(function () {
          loading = false;
          if (status[d].indexOf("ok") >= 0) updated[d] = new Date();
          render();
          // Danach (selten) die Linien zum Hbf nachlernen, wie die Firmware
          if (d === "hbf" && Date.now() - lastLearn > CFG.learnIntervalMs) {
            Promise.all(CFG.stops.map(function (s, i) {
              return EFA.learnRoutes(i, routes).catch(function () {});
            })).then(function () {
              lastLearn = Date.now();
              ctx.storage.set("routen", routes);
              ctx.storage.set("gelernt", lastLearn);
            });
          }
        });
      }

      // ---------- Anzeige ----------
      function render() {
        segBtns.forEach(function (b) { b.classList.toggle("on", b.getAttribute("data-d") === dest); });

        var st = el.querySelector(".f-status");
        var errors = status[dest].filter(function (x) { return x === "fehler"; }).length;
        var age = updated[dest] ? (Date.now() - updated[dest]) / 1000 : null;
        if (!updated[dest] && loading) st.innerHTML = "Lade Abfahrten …";
        else if (!updated[dest] && errors) st.innerHTML = '<span class="f-err">Abruf fehlgeschlagen – läuft server.py?</span>';
        else if (updated[dest]) {
          st.innerHTML = (errors ? '<span class="f-err">Fehler · </span>' : "") +
            "Stand " + hhmm(updated[dest]) + (age > 300 ? " (alt)" : "");
        }

        var now = Date.now(), html = "", best = null;
        var maxRows = ROWS[dest];

        CFG.stops.forEach(function (stop, s) {
          var walk = stop.walkMinutes * 60000;
          var list = data[dest][s] || [];
          var rows = [];
          list.forEach(function (d) {
            if (rows.length >= maxRows) return;
            // Los = Abfahrt minus Fußweg von zu Hause
            var leave = (d.walkStart || d.actual).getTime() - walk;
            if (leave < now - 30000) return; // nicht mehr erreichbar
            rows.push({ d: d, leave: leave, s: s });
            if (!best || leave < best.leave) best = { s: s, i: rows.length - 1, leave: leave };
          });
          html += '<section class="f-stop"><div class="f-head"><div class="f-stopname">' + esc(stop.title) +
            '</div><div class="f-col">Los</div><div class="f-col">Ab</div><div class="f-col">An</div></div>';
          if (!rows.length) {
            html += '<div class="f-empty">' + (data[dest][s] ? (dest === "hbf" ? "Keine Abfahrten zum Hbf" : "Keine Verbindung") : "…") + "</div>";
          }
          rows.forEach(function (r, i) {
            var d = r.d;
            var delay = d.realtime && d.planned ? Math.round((d.actual - d.planned) / 60000) : 0;
            var until = (r.leave - now) / 1000, los, losCls = "";
            // Los-Farben wie am Display: rot = jetzt los, gelb = fertig machen
            if (until < 60) { los = "jetzt"; losCls = "late"; }
            else if (until < 3600) {
              var m = Math.floor(until / 60);
              los = m + " min"; losCls = m <= 2 ? "late" : m <= 5 ? "soon" : "";
            } else { los = hhmm(new Date(r.leave)); losCls = "muted"; }

            var mid;
            if (d.transfer) {
              mid = '<div class="f-dest">Umstieg ' + esc(shortStop(d.transfer.stop)) + " " + badge(d.transfer.line) +
                '<div class="f-detail">an ' + hhmm(d.transfer.tin) + " · weiter " + hhmm(d.transfer.tout) +
                " · " + Math.round((d.transfer.tout - d.transfer.tin) / 60000) + " min Umstieg</div></div>";
            } else {
              mid = '<div class="f-dest">' + esc(shortStop(d.dest)) + "</div>";
            }
            html += '<div class="f-row" data-k="' + s + "-" + i + '">' + badge(d.line) + mid +
              '<div class="f-delay">' + (!d.transfer && delay > 0 ? "+" + delay : "") + "</div>" +
              '<div class="f-col f-los ' + losCls + '">' + los + "</div>" +
              '<div class="f-col' + (d.realtime && delay > 0 ? " late" : "") + '">' + hhmm(d.actual) + "</div>" +
              '<div class="f-col">' + hhmm(d.arrival) + "</div></div>";
          });
          html += "</section>";
        });
        el.querySelector(".f-stops").innerHTML = html;
        // Die nächste Fahrt, die du noch erreichst, bekommt einen Balken
        if (best) {
          var row = el.querySelector('.f-row[data-k="' + best.s + "-" + best.i + '"]');
          if (row) row.classList.add("best");
        }
      }

      render();
      refresh();
      var iv1 = setInterval(refresh, REFRESH_MS);
      var iv2 = setInterval(render, TICK_MS);
      // Warum: Beim Verlassen der App nicht weiter im Hintergrund abfragen
      ctx.onCleanup(function () { clearInterval(iv1); clearInterval(iv2); });
    },

    css: [
      ".f-wrap { padding: 12px 24px 24px; }",
      ".f-top { display: flex; align-items: center; gap: 16px; margin-bottom: 8px; }",
      ".f-title { font-size: 26px; font-weight: 600; }",
      ".f-seg { display: flex; border: 1px solid var(--line); border-radius: 12px; overflow: hidden; }",
      ".f-seg button { border: none; border-radius: 0; min-width: 110px; }",
      ".f-seg button.on { background: #1C3550; color: #fff; }",
      ".f-status { flex: 1; text-align: right; color: var(--quiet); font-size: 16px; }",
      ".f-err { color: #D7262F; }",
      ".f-stop { background: var(--card); border: 1px solid var(--line); border-radius: 16px; margin-top: 14px; padding: 4px 0 8px; }",
      ".f-head { display: flex; align-items: flex-end; padding: 8px 16px 4px; }",
      ".f-stopname { flex: 1; font-size: 20px; font-weight: 700; color: #1C3550; }",
      ".f-head .f-col { font-size: 14px; color: var(--quiet); text-transform: uppercase; letter-spacing: .05em; }",
      ".f-col { width: 84px; text-align: right; font-variant-numeric: tabular-nums; }",
      ".f-row { display: flex; align-items: center; gap: 12px; padding: 8px 16px; border-top: 1px solid var(--line); }",
      ".f-row.best { background: #E3EAF3; }",
      ".f-badge { display: inline-block; min-width: 48px; padding: 2px 8px; border-radius: 8px; color: #fff; font-weight: 700; text-align: center; font-size: 18px; vertical-align: middle; }",
      ".f-dest { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }",
      ".f-detail { font-size: 15px; color: var(--quiet); white-space: normal; }",
      ".f-delay { width: 40px; color: #D7262F; font-size: 16px; text-align: right; }",
      ".f-los { font-weight: 700; }",
      ".f-col.late { color: #D7262F; } .f-col.soon { color: #B7791F; } .f-col.muted { color: var(--quiet); font-weight: 400; }",
      ".f-empty { padding: 10px 16px; color: var(--quiet); border-top: 1px solid var(--line); }"
    ].join("\n")
  });
})();
