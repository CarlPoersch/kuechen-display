// ============================================================
// Küche → Bereich "Wochenplan"
// Rezepte auf Tage legen. Mit einem Knopf landen alle Zutaten der
// geplanten Tage auf der Einkaufsliste (ohne das, was im Vorrat ist).
// Gespeichert pro Tag unter "plan:JJJJ-MM-TT" → synchron mit dem Handy.
// ============================================================
(function () {
  var K = window.Kueche, esc = K.esc;

  /** Montag der Woche, in der "d" liegt */
  function monday(d) {
    var m = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    var wd = (m.getDay() + 6) % 7; // Mo = 0
    m.setDate(m.getDate() - wd);
    return m;
  }

  K.register({
    id: "plan", name: "Wochenplan", icon: "📅",
    badge: function () {
      var n = K.planFor(K.isoDate(new Date())).length;
      return n ? { text: "heute " + n } : "";
    },
    render: function (el, ctx) {
      var offset = 0; // 0 = diese Woche, 1 = nächste ...
      el.innerHTML = '<div class="p-wrap"><div class="p-head"><button class="p-prev">‹</button>' +
        '<div class="p-title"></div><button class="p-next">›</button>' +
        '<button class="primary p-shop">🛒 Zutaten der Woche auf die Liste</button></div>' +
        '<div class="p-days"></div></div>';

      K.loadIndex().then(function (recipes) {
        var byId = {}; recipes.forEach(function (r) { byId[r.id] = r; });

        function weekDays() {
          var start = monday(new Date()); start.setDate(start.getDate() + offset * 7);
          var out = [];
          for (var i = 0; i < 7; i++) { var d = new Date(start); d.setDate(start.getDate() + i); out.push(d); }
          return out;
        }

        function draw() {
          var days = weekDays(), today = K.isoDate(new Date());
          el.querySelector(".p-title").textContent = offset === 0 ? "Diese Woche" : offset === 1 ? "Nächste Woche" :
            offset === -1 ? "Letzte Woche" : days[0].getDate() + "." + (days[0].getMonth() + 1) + ". – " + days[6].getDate() + "." + (days[6].getMonth() + 1) + ".";
          var h = "";
          days.forEach(function (d) {
            var iso = K.isoDate(d), list = K.planFor(iso);
            var past = iso < today;
            h += '<div class="p-day' + (iso === today ? " today" : "") + (past ? " past" : "") + '">' +
              '<div class="p-dname">' + K.DAYS[d.getDay()] + '<span>' + d.getDate() + "." + (d.getMonth() + 1) + ".</span></div><div class=\"p-items\">";
            list.forEach(function (p, i) {
              var r = byId[p.id]; if (!r) return;
              var c = K.cooked(r.id);
              h += '<div class="p-item"><button class="p-open" data-id="' + esc(r.id) + '"><span class="k-ic">' + esc(r.icon) + "</span>" +
                '<span class="p-it">' + esc(r.title) + '<small>' + p.portions + " Port." + (c ? " · ✓ gekocht" : "") + "</small></span></button>" +
                '<button class="p-del" data-iso="' + iso + '" data-i="' + i + '">✕</button></div>';
            });
            if (!past) h += '<button class="p-add" data-iso="' + iso + '">+ Rezept</button>';
            h += "</div></div>";
          });
          el.querySelector(".p-days").innerHTML = h;

          el.querySelectorAll(".p-open").forEach(function (b) { b.onclick = function () { ctx.go("rezept/" + b.getAttribute("data-id")); }; });
          el.querySelectorAll(".p-del").forEach(function (b) {
            b.onclick = function () {
              var iso = b.getAttribute("data-iso"), list = K.planFor(iso).slice();
              list.splice(+b.getAttribute("data-i"), 1);
              if (list.length) Launcher.store.set("plan:" + iso, list); else Launcher.store.remove("plan:" + iso);
            };
          });
          el.querySelectorAll(".p-add").forEach(function (b) { b.onclick = function () { picker(b.getAttribute("data-iso")); }; });
        }

        // Rezept-Auswahl: Suche + Zufall, bevorzugt noch nicht gekochte
        function picker(iso) {
          var d = K.parseIso(iso);
          var box = K.dialog(el, "<h3>" + K.DAYS_LONG[d.getDay()] + ", " + d.getDate() + "." + (d.getMonth() + 1) + ".</h3>" +
            '<div class="k-row" style="margin-top:0"><input class="k-input p-search" placeholder="Suchen …" style="flex:1">' +
            '<button class="p-rnd">🎲</button></div><div class="p-pick"></div>' +
            '<div class="k-row"><button class="p-close">Abbrechen</button></div>');
          var input = box.querySelector(".p-search");
          function list() {
            var q = input.value.trim().toLowerCase();
            var found = recipes.filter(function (r) {
              return !q || r.title.toLowerCase().indexOf(q) >= 0 || (r.cuisine || "").toLowerCase().indexOf(q) >= 0;
            }).slice(0, 40);
            box.querySelector(".p-pick").innerHTML = found.map(function (r) {
              return '<button class="k-line" data-id="' + esc(r.id) + '"><span class="k-ic">' + esc(r.icon) + "</span>" + esc(r.title) +
                '<span class="k-muted"> · ' + esc(r.cuisine || "") + "</span></button>";
            }).join("") || '<div class="k-muted">Nichts gefunden.</div>';
            box.querySelectorAll(".p-pick [data-id]").forEach(function (b) { b.onclick = function () { choose(b.getAttribute("data-id")); }; });
          }
          function choose(id) {
            K.addToPlan(iso, id, K.local().get("portionen-" + id, byId[id].servings));
            box.close();
          }
          input.oninput = list;
          box.querySelector(".p-rnd").onclick = function () {
            var fresh = recipes.filter(function (r) { return !K.cooked(r.id); });
            var pool = fresh.length ? fresh : recipes;
            choose(pool[Math.floor(Math.random() * pool.length)].id);
          };
          box.querySelector(".p-close").onclick = box.close;
          list();
        }

        el.querySelector(".p-prev").onclick = function () { offset--; draw(); };
        el.querySelector(".p-next").onclick = function () { offset++; draw(); };

        // Alle Zutaten der (heute und künftigen) Tage dieser Woche auf die Liste
        el.querySelector(".p-shop").onclick = function () {
          var today = K.isoDate(new Date());
          var entries = [];
          weekDays().forEach(function (d) {
            var iso = K.isoDate(d);
            if (iso >= today) K.planFor(iso).forEach(function (p) { entries.push(p); });
          });
          if (!entries.length) { K.toast("In dieser Woche ist nichts mehr geplant."); return; }
          var weekKey = "setting:plan-einkauf-" + K.isoDate(weekDays()[0]);
          var prev = Launcher.store.get(weekKey, null);
          function run() {
            Promise.all(entries.map(function (p) { return K.loadRecipe(p.id).then(function (R) { return { R: R, p: p }; }); }))
              .then(function (all) {
                var added = 0, skipped = 0;
                all.forEach(function (x) {
                  var f = x.p.portions / x.R.servings;
                  var items = x.R.ingredients.filter(function (i) { return i.name; })
                    .map(function (i) { return { name: i.name, amount: K.scaleAmount(i.amount, f) }; });
                  var res = K.addToShopping(items, x.R.title);
                  added += res.added + res.merged; skipped += res.skipped.length;
                });
                Launcher.store.set(weekKey, Date.now());
                K.toast(added + " Zutaten für " + all.length + " Gerichte auf der Liste" + (skipped ? " · " + skipped + " schon da" : ""));
              });
          }
          // Schutz vor doppeltem Hinzufügen
          if (prev) {
            var box = K.dialog(el, "<h3>Schon erledigt?</h3><div>Die Zutaten dieser Woche hast du am " + K.fmtDate(prev) +
              " schon auf die Liste gesetzt. Nochmal hinzufügen? (Gleiche Zutaten werden zusammengezählt.)</div>" +
              '<div class="k-row"><button class="p-no">Abbrechen</button><button class="primary p-yes">Trotzdem hinzufügen</button></div>');
            box.querySelector(".p-no").onclick = box.close;
            box.querySelector(".p-yes").onclick = function () { box.close(); run(); };
          } else run();
        };

        draw();
        ctx.onCleanup(Launcher.store.subscribe(draw));
      });
    },
    css: [
      ".p-wrap { padding: 14px 24px; }",
      ".p-head { display: flex; align-items: center; gap: 10px; margin-bottom: 14px; flex-wrap: wrap; }",
      ".p-head .p-prev, .p-head .p-next { width: 48px; font-size: 24px; padding: 0; }",
      ".p-title { font-size: 22px; font-weight: 700; min-width: 160px; text-align: center; }",
      ".p-shop { margin-left: auto; }",
      ".p-days { display: flex; flex-direction: column; gap: 8px; }",
      ".p-day { display: flex; gap: 14px; background: var(--card); border: 1px solid var(--line); border-radius: 16px; padding: 10px 14px; align-items: flex-start; }",
      ".p-day.today { border: 2px solid var(--accent); }",
      ".p-day.past { opacity: .55; }",
      ".p-dname { width: 56px; font-size: 22px; font-weight: 700; display: flex; flex-direction: column; padding-top: 6px; }",
      ".p-dname span { font-size: 14px; font-weight: 400; color: var(--quiet); }",
      ".p-items { flex: 1; display: flex; flex-wrap: wrap; gap: 8px; align-items: center; min-height: 52px; }",
      ".p-item { display: flex; align-items: stretch; border: 1px solid var(--line); border-radius: 14px; overflow: hidden; background: var(--bg); }",
      ".p-open { border: none; border-radius: 0; display: flex; align-items: center; gap: 8px; text-align: left; background: none; }",
      ".p-it { display: flex; flex-direction: column; font-size: 17px; font-weight: 600; } .p-it small { font-size: 13px; font-weight: 400; color: var(--quiet); }",
      ".p-del { border: none; border-radius: 0; border-left: 1px solid var(--line); color: var(--quiet); min-width: 44px; background: none; }",
      ".p-add { border-style: dashed; color: var(--quiet); }",
      ".p-pick { max-height: 380px; overflow-y: auto; margin-top: 10px; }"
    ].join("\n")
  });
})();
