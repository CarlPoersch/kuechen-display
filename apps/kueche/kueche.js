// ============================================================
// Unterapp "Küche" – Rahmen mit Navigation und Übersicht.
//
// Adressen:
//   #kueche                 Übersicht
//   #kueche/rezepte         Rezeptliste
//   #kueche/rezept/<id>     ein Rezept
//   #kueche/plan            Wochenplan
//   #kueche/einkauf         Einkaufsliste
//   #kueche/vorrat          Vorrat & Kühlschrank
//   #kueche/airfryer        Airfryer-Spickzettel
//
// Jeder Bereich liegt in einer eigenen Datei und meldet sich mit
// Kueche.register({...}) an. Diese Datei verbindet sie.
// ============================================================
(function () {
  var K = window.Kueche, esc = K.esc;

  // ---------- Übersicht ----------
  // unshift statt register: Die Übersicht soll in der Navigation ganz vorne stehen,
  // die anderen Bereiche sind zu diesem Zeitpunkt schon angemeldet.
  K.sections.unshift({
    id: "", name: "Übersicht", icon: "🏠",
    render: function (el, ctx) {
      el.innerHTML = '<div class="k-dash"></div>';
      var box = el.firstChild;
      K.loadIndex().then(function (recipes) {
        var byId = {}; recipes.forEach(function (r) { byId[r.id] = r; });
        function draw() {
          var today = K.isoDate(new Date()), d = new Date();
          var planned = K.planFor(today).filter(function (p) { return byId[p.id]; });
          var open = K.shopItems().filter(function (i) { return !i.done; });
          var expiring = K.pantryItems().filter(function (p) { return p.mhd && K.daysUntil(p.mhd) <= 3; })
            .sort(function (a, b) { return a.mhd < b.mhd ? -1 : 1; });
          var last = recipes.filter(function (r) { return K.cooked(r.id); })
            .sort(function (a, b) { return K.cooked(b.id).last - K.cooked(a.id).last; }).slice(0, 3);

          var h = '<div class="k-hello">' + K.DAYS_LONG[d.getDay()] + ", " + d.getDate() + "." + (d.getMonth() + 1) + ".</div>";
          h += '<div class="k-cards">';
          // Heute
          h += '<div class="k-card k-c-today"><div class="k-card-h">🍽 Heute auf dem Plan</div>';
          if (planned.length) {
            planned.forEach(function (p) {
              var r = byId[p.id];
              h += '<button class="k-line" data-go="rezept/' + esc(r.id) + '"><span class="k-ic">' + esc(r.icon) + "</span>" + esc(r.title) + "</button>";
            });
          } else {
            h += '<div class="k-muted">Noch nichts geplant.</div>' +
              '<div class="k-row"><button class="k-btn" data-go="plan">📅 Planen</button><button class="k-btn primary" data-random>🎲 Vorschlag</button></div>';
          }
          h += "</div>";
          // Einkauf
          h += '<div class="k-card k-c-shop" data-go="einkauf"><div class="k-card-h">🛒 Einkaufsliste</div>' +
            '<div class="k-big">' + open.length + '</div><div class="k-muted">' + (open.length === 1 ? "Artikel offen" : "Artikel offen") + "</div>" +
            (open.length ? '<div class="k-small">' + esc(open.slice(0, 4).map(function (i) { return i.name; }).join(", ")) + (open.length > 4 ? " …" : "") + "</div>" : "") +
            "</div>";
          // Läuft ab
          h += '<div class="k-card k-c-mhd" data-go="vorrat"><div class="k-card-h">⏳ Bald verbrauchen</div>';
          if (expiring.length) {
            expiring.slice(0, 4).forEach(function (p) {
              var dd = K.daysUntil(p.mhd);
              h += '<div class="k-mhd ' + (dd <= 1 ? "red" : "yellow") + '">' + esc(p.name) + " <span>" +
                (dd < 0 ? "abgelaufen" : dd === 0 ? "heute" : dd === 1 ? "morgen" : "in " + dd + " Tagen") + "</span></div>";
            });
          } else h += '<div class="k-muted">Nichts läuft in den nächsten 3 Tagen ab.</div>';
          h += "</div>";
          // Zuletzt gekocht
          h += '<div class="k-card k-c-last"><div class="k-card-h">✓ Zuletzt gekocht</div>';
          if (last.length) last.forEach(function (r) {
            h += '<button class="k-line" data-go="rezept/' + esc(r.id) + '"><span class="k-ic">' + esc(r.icon) + "</span>" + esc(r.title) +
              '<span class="k-muted"> · ' + K.fmtDate(K.cooked(r.id).last) + "</span></button>";
          });
          else h += '<div class="k-muted">Noch nichts gekocht.</div>';
          h += "</div></div>";

          // Kacheln zu den Bereichen
          h += '<div class="k-tiles">';
          K.sections.forEach(function (s) {
            if (!s.id || s.hidden) return;
            h += '<button class="k-tile" data-go="' + s.id + '"><span>' + s.icon + "</span>" + esc(s.name) + "</button>";
          });
          h += "</div>";
          box.innerHTML = h;

          box.querySelectorAll("[data-go]").forEach(function (b) {
            b.onclick = function (e) { e.stopPropagation(); ctx.go(b.getAttribute("data-go")); };
          });
          var rnd = box.querySelector("[data-random]");
          if (rnd) rnd.onclick = function () {
            var r = recipes[Math.floor(Math.random() * recipes.length)];
            ctx.go("rezept/" + r.id);
          };
        }
        draw();
        ctx.onCleanup(Launcher.store.subscribe(draw));
      });
    }
  });

  // ---------- Rahmen ----------
  function findSection(id) {
    for (var i = 0; i < K.sections.length; i++) if (K.sections[i].id === id) return K.sections[i];
    return null;
  }

  Launcher.register({
    id: "kueche",
    name: "Küche",
    icon: "🍳",
    color: "#c2410c",
    mount: function (el, ctx) {
      K.migrate();
      var parts = (ctx.sub || "").split("/");
      var secId = parts[0], arg = parts.slice(1).join("/");
      // "rezept/<id>" gehört zum Bereich Rezepte
      var sec = secId === "rezept" ? findSection("rezepte") : findSection(secId);
      if (!sec) sec = findSection("");

      el.innerHTML = '<div class="k-nav"></div><div class="k-body"></div>';
      var nav = el.querySelector(".k-nav"), body = el.querySelector(".k-body");

      function drawNav() {
        var h = "";
        K.sections.forEach(function (s) {
          if (s.hidden) return;
          var badge = s.badge ? s.badge() : "";
          h += '<button class="k-tab' + (s === sec ? " on" : "") + '" data-s="' + s.id + '">' +
            '<span class="k-tab-ic">' + s.icon + "</span>" + esc(s.name) +
            (badge ? '<span class="k-badge' + (badge.warn ? " warn" : "") + '">' + esc(badge.text || badge) + "</span>" : "") + "</button>";
        });
        var on = Launcher.store.online();
        // Zeigt, ob die Daten gerade mit dem Server (und damit dem Handy) abgeglichen sind
        h += '<div class="k-sync ' + (on ? "ok" : on === false ? "off" : "") + '">' +
          (on ? "● synchron" : on === false ? "○ nur lokal" : "○ …") + "</div>";
        nav.innerHTML = h;
        nav.querySelectorAll(".k-tab").forEach(function (b) {
          b.onclick = function () { ctx.go(b.getAttribute("data-s")); };
        });
      }
      drawNav();
      ctx.onCleanup(Launcher.store.subscribe(drawNav));

      var sctx = {
        go: ctx.go, storage: ctx.storage, setTitle: ctx.setTitle, setBack: ctx.setBack,
        onCleanup: ctx.onCleanup, sub: ctx.sub
      };
      if (sec.id) ctx.setTitle("Küche · " + sec.name);
      sec.render(body, sctx, secId === "rezept" ? arg : null);
    }
  });

  // Aussehen: gemeinsame Küche-Styles + die CSS aller Bereiche in einem Block
  var css = [
    ".k-nav { display: flex; align-items: center; gap: 6px; padding: 10px 16px; overflow-x: auto; border-bottom: 1px solid var(--line); background: var(--bg); position: sticky; top: 0; z-index: 5; }",
    ".k-tab { flex: 0 0 auto; border-radius: 22px; padding: 6px 14px; min-height: 44px; font-size: 17px; display: flex; align-items: center; gap: 6px; }",
    ".k-tab.on { background: var(--ink); color: #fff; border-color: var(--ink); }",
    ".k-tab-ic { font-size: 20px; }",
    ".k-badge { background: var(--accent); color: #fff; border-radius: 10px; font-size: 13px; padding: 1px 7px; font-weight: 700; }",
    ".k-badge.warn { background: #D7262F; }",
    ".k-sync { margin-left: auto; flex: 0 0 auto; font-size: 13px; color: var(--quiet); padding-left: 8px; }",
    ".k-sync.ok { color: #2E7D32; } .k-sync.off { color: #B7791F; }",
    ".k-body { padding-bottom: 24px; }",
    ".k-btn { font-size: 17px; }",
    ".k-muted { color: var(--quiet); font-size: 16px; }",
    ".k-small { color: var(--quiet); font-size: 15px; margin-top: 6px; }",
    ".k-row { display: flex; gap: 10px; margin-top: 12px; flex-wrap: wrap; }",
    ".k-input { font: inherit; font-size: 18px; padding: 10px 14px; border: 1px solid var(--line); border-radius: 12px; background: var(--card); color: var(--ink); min-height: 48px; }",
    ".k-h2 { font-size: 15px; letter-spacing: .06em; text-transform: uppercase; color: var(--quiet); margin: 22px 0 10px; }",
    // Übersicht
    ".k-dash { padding: 16px 24px; }",
    ".k-hello { font-size: 30px; font-weight: 700; margin-bottom: 14px; }",
    ".k-cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 14px; }",
    ".k-card { background: var(--card); border: 1px solid var(--line); border-radius: 20px; padding: 16px 18px; cursor: pointer; }",
    ".k-card-h { font-weight: 700; font-size: 18px; margin-bottom: 8px; }",
    ".k-c-today { border-top: 5px solid var(--accent); } .k-c-shop { border-top: 5px solid #2563eb; }",
    ".k-c-mhd { border-top: 5px solid #B7791F; } .k-c-last { border-top: 5px solid #2E7D32; }",
    ".k-big { font-size: 48px; font-weight: 700; line-height: 1; }",
    ".k-line { display: flex; align-items: center; gap: 10px; width: 100%; text-align: left; border: none; background: none; padding: 6px 0; min-height: 40px; font-size: 18px; }",
    ".k-ic { font-size: 24px; }",
    ".k-mhd { padding: 4px 0; font-size: 17px; } .k-mhd span { font-size: 14px; font-weight: 600; }",
    ".k-mhd.red span { color: #D7262F; } .k-mhd.yellow span { color: #B7791F; }",
    ".k-tiles { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 12px; margin-top: 18px; }",
    ".k-tile { height: 110px; border-radius: 20px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; font-size: 18px; font-weight: 600; }",
    ".k-tile span { font-size: 40px; }",
    // Dialog + Meldung
    ".k-overlay { position: fixed; left: 0; right: 0; top: 0; bottom: 0; background: rgba(43,36,32,.45); z-index: 20; display: flex; align-items: center; justify-content: center; }",
    ".k-dialog { background: var(--card); border-radius: 24px; padding: 24px 28px; width: 560px; max-width: 92%; max-height: 85%; overflow-y: auto; box-shadow: 0 10px 40px rgba(0,0,0,.2); }",
    ".k-dialog h3 { margin: 0 0 14px; font-size: 24px; }",
    ".k-toast { position: fixed; left: 50%; bottom: 100px; transform: translate(-50%, 20px); background: var(--ink); color: #fff; padding: 12px 20px; border-radius: 14px; font-size: 17px; opacity: 0; transition: all .25s; z-index: 30; max-width: 80%; text-align: center; }",
    ".k-toast.show { opacity: 1; transform: translate(-50%, 0); }"
  ];
  var st = document.createElement("style");
  st.textContent = css.join("\n") + "\n" + K.sections.map(function (s) { return s.css || ""; }).join("\n");
  document.head.appendChild(st);
})();
