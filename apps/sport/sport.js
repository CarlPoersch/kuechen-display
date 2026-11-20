// ============================================================
// Unterapp "Sport": alle relevanten Spiele von gestern bis in 7 Tagen.
// Fußball: Bayern, Champions League, Pokal, deutsche Teams in Europa, DFB-Team.
// Tennis: deutsche Spieler/innen, bei den Herren auch alle Halbfinals/Finals.
// Nur anzeigen – keine Töne, keine Mitteilungen.
//
// Antippen eines Spiels öffnet die Details (#sport/m/<id>):
//   Fußball: Spielstand, Tore/Karten/Wechsel, Statistik, Aufstellungen
//   Tennis:  Sätze mit Tiebreaks, Weltranglistenplätze, Ergebnis, Ort
// ============================================================
(function () {
  var F = Hubert.Feeds, esc = Launcher.esc;
  var WD = ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"];

  function dayLabel(d) {
    var dd = F.dayDiff(d), x = new Date(d);
    return dd === 0 ? "Heute" : dd === 1 ? "Morgen" : dd === -1 ? "Gestern" : WD[x.getDay()] + ", " + x.getDate() + "." + (x.getMonth() + 1) + ".";
  }

  function group(list) {
    var groups = [], byKey = {};
    list.forEach(function (m) {
      var key = m.state === "in" ? "Jetzt live" : m.state === "post" ? "Ergebnisse" : dayLabel(m.date);
      if (!byKey[key]) { byKey[key] = []; groups.push([key, byKey[key]]); }
      byKey[key].push(m);
    });
    // Ergebnisse ans Ende
    groups.sort(function (a, b) { return (a[0] === "Ergebnisse") - (b[0] === "Ergebnisse"); });
    return groups;
  }

  // ---------- Liste ----------
  function mountList(el, ctx) {
    var tab = ctx.storage.get("tab", "fb");
    el.innerHTML = '<div class="sp-wrap"><div class="sp-tabs"><button data-t="fb">⚽️ Fußball</button><button data-t="tn">🎾 Tennis</button></div>' +
      '<div class="sp-list"></div><div class="sp-foot"></div></div>';
    var listEl = el.querySelector(".sp-list"), foot = el.querySelector(".sp-foot");
    var btns = el.querySelectorAll(".sp-tabs button");
    btns.forEach(function (b) {
      b.onclick = function () { tab = b.getAttribute("data-t"); ctx.storage.set("tab", tab); draw(); };
    });

    function draw() {
      btns.forEach(function (b) { b.classList.toggle("on", b.getAttribute("data-t") === tab); });
      var c = F.cached("sport");
      if (!F.cloud()) { listEl.innerHTML = '<div class="empty">Sport gibt es nur in der Cloud-Version.</div>'; return; }
      if (!c) { listEl.innerHTML = '<div class="empty">Lädt …</div>'; return; }
      var list = (c.data.matches || []).filter(function (m) { return m.sport === tab; });
      if (!list.length) {
        listEl.innerHTML = '<div class="empty">' + (tab === "fb" ? "Keine Spiele deiner Teams zwischen gestern und nächster Woche."
          : "Gerade keine Matches mit deutscher Beteiligung oder Halbfinals/Finals.") + "</div>";
      } else {
        listEl.innerHTML = group(list).map(function (g) {
          return '<div class="sp-day">' + esc(g[0]) + '</div><div class="sp-grid">' +
            g[1].map(function (m) { return F.matchHtml(m, { day: true }); }).join("") + "</div>";
        }).join("");
      }
      foot.textContent = "Stand " + F.hhmm(c.at) + " · Quelle: ESPN";
    }

    draw();
    ctx.onCleanup(F.subscribe("sport", draw));
    ctx.onCleanup(F.keepFresh("sport"));
    var t = setInterval(draw, 30000); // "morgen 20:45" usw. aktuell halten
    ctx.onCleanup(function () { clearInterval(t); });
  }

  // ---------- Details ----------
  function findMatch(id) {
    var c = F.cached("sport");
    return c && (c.data.matches || []).filter(function (m) { return m.id === id; })[0];
  }

  /** Kopf mit beiden Seiten und Ergebnis (für Fußball und Tennis gleich aufgebaut) */
  function scoreHead(m, a, b, mid, sub) {
    var status = m.state === "in" ? '<span class="s-live">' + esc(m.detail || "live") + "</span>"
      : m.state === "post" ? esc(m.detail || "Ende") : esc(dayLabel(m.date) + ", " + F.hhmm(m.date) + " Uhr");
    return '<div class="md-head"><div class="md-comp">' + (m.sport === "tn" ? "🎾 " : "⚽️ ") + esc(m.comp) +
      (m.round ? " · " + esc(m.round) : "") + "</div>" +
      '<div class="md-score"><div class="md-team' + (a.win ? " s-win" : "") + '">' + a.html + "</div>" +
      '<div class="md-mid"><div class="md-res">' + mid + '</div><div class="md-status">' + status + "</div>" +
      (sub ? '<div class="md-sub">' + sub + "</div>" : "") + "</div>" +
      '<div class="md-team' + (b.win ? " s-win" : "") + '">' + b.html + "</div></div></div>";
  }

  var ICON = { goal: "⚽️", pen: "⚽️", own: "⚽️", yellow: "🟨", red: "🟥", sub: "🔁" };
  var KIND = { pen: " (Elfmeter)", own: " (Eigentor)" };

  function footballHtml(m, d) {
    var h = scoreHead(m,
      { html: esc(m.a.n), win: d && d.h.win }, { html: esc(m.b.n), win: d && d.a.win },
      m.state === "pre" ? "–:–" : esc((d ? d.h.score : m.a.score) || "0") + " : " + esc((d ? d.a.score : m.b.score) || "0"),
      d && m.state !== "pre" && d.h.ht != null && d.a.ht != null ? "Halbzeit " + esc(d.h.ht) + ":" + esc(d.a.ht) : "");
    if (!d) return h + '<div class="md-sec"><div class="h-muted">Details laden …</div></div>';

    // Spielverlauf: Heim links, Gast rechts
    var evs = d.events || [];
    if (evs.length) {
      h += '<div class="md-sec"><div class="md-sec-h">Spielverlauf</div>' + evs.map(function (e) {
        var txt = '<b>' + esc(e.who) + "</b>" + (KIND[e.kind] || "") + (e.extra ? '<span class="md-x">' + esc(e.extra) + "</span>" : "");
        var cell = '<span class="md-ic">' + (ICON[e.kind] || "•") + "</span><span>" + txt + "</span>";
        return '<div class="md-ev' + (e.kind === "sub" ? " is-sub" : "") + '">' +
          '<div class="md-ev-h">' + (e.side === "h" ? cell : "") + "</div>" +
          '<div class="md-min">' + esc(e.min) + "</div>" +
          '<div class="md-ev-a">' + (e.side === "a" ? cell : "") + "</div></div>";
      }).join("") + "</div>";
    } else if (m.state !== "pre") {
      h += '<div class="md-sec"><div class="md-sec-h">Spielverlauf</div><div class="h-muted">Noch keine Tore oder Karten.</div></div>';
    }

    // Statistik mit Balken
    if ((d.stats || []).length) {
      h += '<div class="md-sec"><div class="md-sec-h">Statistik</div>' + d.stats.map(function (r) {
        var x = parseFloat(r[1]) || 0, y = parseFloat(r[2]) || 0, sum = x + y || 1;
        var pct = r[0] === "Ballbesitz" ? "%" : "";
        return '<div class="md-st"><div class="md-st-row"><b>' + esc(r[1]) + pct + "</b><span>" + esc(r[0]) + "</span><b>" + esc(r[2]) + pct + "</b></div>" +
          '<div class="md-bar"><i style="width:' + Math.round(100 * x / sum) + '%"></i><i style="width:' + Math.round(100 * y / sum) + '%"></i></div></div>';
      }).join("") + "</div>";
    }

    // Aufstellungen
    var lu = d.lineups || {};
    if (lu.h || lu.a) {
      var col = function (l, name) {
        if (!l) return '<div class="md-lu"><div class="md-lu-h">' + esc(name) + '</div><div class="h-muted">Noch nicht bekannt</div></div>';
        return '<div class="md-lu"><div class="md-lu-h">' + esc(name) + (l.form ? " · " + esc(l.form) : "") + "</div>" +
          l.xi.map(function (p) { return '<div class="md-pl"><span class="md-nr">' + esc(p.nr) + "</span>" + esc(p.n) + "</div>"; }).join("") +
          (l.bench.length ? '<div class="md-bench">Bank: ' + l.bench.map(function (p) { return esc(p.n); }).join(", ") + "</div>" : "") + "</div>";
      };
      h += '<div class="md-sec"><div class="md-sec-h">Aufstellung</div><div class="md-lus">' + col(lu.h, m.a.n) + col(lu.a, m.b.n) + "</div></div>";
    } else if (m.state === "pre") {
      h += '<div class="md-sec"><div class="h-muted">Die Aufstellungen gibt es meist etwa eine Stunde vor Anpfiff.</div></div>';
    }

    var info = [];
    if (d.venue) info.push("🏟 " + esc(d.venue));
    if (d.ref) info.push("Schiedsrichter: " + esc(d.ref));
    if (info.length) h += '<div class="sp-foot">' + info.join(" · ") + "</div>";
    return h;
  }

  function tennisHtml(m) {
    var who = function (s) {
      return esc(s.n) + (F.flag(s.c) ? " " + F.flag(s.c) : s.c ? ' <small>' + esc(s.c) + "</small>" : "") +
        (s.r ? '<div class="md-rank">Weltrangliste ' + esc(s.r) + "</div>" : "");
    };
    var setsWon = function (s, o) {
      var n = 0;
      (s.sets || []).forEach(function (v, i) { if (v > ((o.sets || [])[i] || 0)) n++; });
      return n;
    };
    var mid = m.state === "pre" ? "–:–" : setsWon(m.a, m.b) + " : " + setsWon(m.b, m.a);
    var h = scoreHead(m, { html: who(m.a), win: m.a.win }, { html: who(m.b), win: m.b.win }, mid, "Sätze");
    var n = Math.max((m.a.sets || []).length, (m.b.sets || []).length);
    if (n) {
      var cell = function (s, i) {
        var tb = (s.tb || [])[i];
        return "<td>" + esc((s.sets || [])[i] != null ? s.sets[i] : "") + (tb != null ? "<sup>" + esc(tb) + "</sup>" : "") + "</td>";
      };
      var row = function (s) {
        var c = ""; for (var i = 0; i < n; i++) c += cell(s, i);
        return '<tr><th>' + esc(s.n) + "</th>" + c + "</tr>";
      };
      var head = ""; for (var i = 0; i < n; i++) head += "<td>" + (i + 1) + ".</td>";
      h += '<div class="md-sec"><div class="md-sec-h">Sätze</div><table class="md-sets"><tr><th></th>' + head + "</tr>" +
        row(m.a) + row(m.b) + "</table></div>";
    }
    if (m.note) h += '<div class="md-sec"><div class="md-sec-h">Ergebnis</div><div>' + esc(m.note) + "</div></div>";
    var info = [];
    if (m.venue) info.push("📍 " + esc(m.venue));
    info.push(esc(dayLabel(m.date)) + ", " + F.hhmm(m.date) + " Uhr");
    h += '<div class="sp-foot">' + info.join(" · ") + "</div>";
    return h;
  }

  function mountMatch(el, ctx, id) {
    ctx.setTitle("Spiel");
    ctx.setBack("Zurück", null);
    var detail = null, alive = true, timer = null;
    ctx.onCleanup(function () { alive = false; clearTimeout(timer); });

    function draw() {
      var m = findMatch(id);
      if (!m) { el.innerHTML = '<div class="empty">Dieses Spiel ist nicht mehr in der Liste.</div>'; return; }
      el.innerHTML = '<div class="md">' + (m.sport === "tn" ? tennisHtml(m) : footballHtml(m, detail)) + "</div>";
    }
    function loadDetail() {
      var m = findMatch(id);
      if (!alive || !m || m.sport !== "fb" || !m.lg) return;
      F.api("match?lg=" + encodeURIComponent(m.lg) + "&id=" + encodeURIComponent(m.eid)).then(function (d) {
        if (!alive) return;
        detail = d;
        // Spielstand aus den Details übernehmen, damit Kopf und Verlauf zusammenpassen
        m.state = d.state; m.detail = d.detail;
        draw();
      }, function () {}).then(function () {
        // Live: alle 30 s, sonst alle 5 min
        if (alive) timer = setTimeout(loadDetail, (findMatch(id) || {}).state === "in" ? 30000 : 300000);
      });
    }
    draw();
    loadDetail();
    ctx.onCleanup(F.subscribe("sport", draw));
    ctx.onCleanup(F.keepFresh("sport"));
  }

  Launcher.register({
    id: "sport",
    name: "Sport",
    icon: "⚽️",
    color: "#2F6B4F",
    mount: function (el, ctx) {
      if (ctx.sub.indexOf("m/") === 0) mountMatch(el, ctx, ctx.sub.slice(2));
      else mountList(el, ctx);
    }
  });
})();
