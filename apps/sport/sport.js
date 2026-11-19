// ============================================================
// Unterapp "Sport": alle relevanten Spiele von gestern bis in 7 Tagen.
// Fußball: Bayern, Champions League, Pokal, deutsche Teams in Europa, DFB-Team.
// Tennis: deutsche Spieler/innen, bei den Herren auch alle Halbfinals/Finals.
// Nur anzeigen – keine Töne, keine Mitteilungen.
// ============================================================
(function () {
  var F = Hubert.Feeds, esc = Launcher.esc;

  function group(list) {
    var groups = [], byKey = {};
    list.forEach(function (m) {
      var key, dd = F.dayDiff(m.date);
      if (m.state === "in") key = "Jetzt live";
      else if (m.state === "post") key = "Ergebnisse";
      else key = dd === 0 ? "Heute" : dd === 1 ? "Morgen" : ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"][new Date(m.date).getDay()] +
        ", " + new Date(m.date).getDate() + "." + (new Date(m.date).getMonth() + 1) + ".";
      if (!byKey[key]) { byKey[key] = []; groups.push([key, byKey[key]]); }
      byKey[key].push(m);
    });
    // Ergebnisse ans Ende
    groups.sort(function (a, b) { return (a[0] === "Ergebnisse") - (b[0] === "Ergebnisse"); });
    return groups;
  }

  Launcher.register({
    id: "sport",
    name: "Sport",
    icon: "⚽️",
    color: "#2F6B4F",
    mount: function (el, ctx) {
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
  });
})();
