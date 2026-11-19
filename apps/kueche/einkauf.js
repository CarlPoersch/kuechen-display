// ============================================================
// Küche → Bereich "Einkaufsliste"
// Füllt sich aus Rezepten und dem Wochenplan, oder per Hand.
// Abgehakte Artikel wandern (wenn eingeschaltet) automatisch in den Vorrat.
// Gespeichert pro Artikel unter "shop:<id>" → synchron mit dem Handy.
// Warum pro Artikel und nicht eine ganze Liste: So können iPad und Handy
// gleichzeitig abhaken, ohne sich gegenseitig zu überschreiben.
// ============================================================
(function () {
  var K = window.Kueche, esc = K.esc, S = function () { return Launcher.store; };

  K.register({
    id: "einkauf", name: "Einkauf", icon: "🛒",
    badge: function () {
      var n = K.shopItems().filter(function (i) { return !i.done; }).length;
      return n ? { text: String(n) } : "";
    },
    render: function (el, ctx) {
      el.innerHTML = '<div class="e-wrap">' +
        '<form class="e-add"><input class="k-input e-name" placeholder="Was fehlt? z. B. Milch" autocomplete="off">' +
        '<input class="k-input e-amount" placeholder="Menge" autocomplete="off"><button class="primary">Hinzufügen</button></form>' +
        '<div class="e-tools"><button class="e-copy">📋 Liste kopieren</button>' +
        '<label class="e-auto"><input type="checkbox" class="e-auto-cb"> Gekauftes in den Vorrat übernehmen</label></div>' +
        '<div class="e-list"></div></div>';

      var autoKey = "setting:einkauf-in-vorrat";
      var cb = el.querySelector(".e-auto-cb");

      el.querySelector(".e-add").onsubmit = function (ev) {
        ev.preventDefault(); // Warum: Ein Formular würde sonst die Seite neu laden
        var n = el.querySelector(".e-name"), a = el.querySelector(".e-amount");
        if (!n.value.trim()) return;
        K.addToShopping([{ name: n.value.trim(), amount: a.value.trim() }], "");
        n.value = ""; a.value = ""; n.focus();
      };
      cb.onchange = function () { S().set(autoKey, cb.checked); };

      el.querySelector(".e-copy").onclick = function () {
        var open = K.shopItems().filter(function (i) { return !i.done; });
        if (!open.length) { K.toast("Die Liste ist leer."); return; }
        var text = "Einkaufsliste\n" + open.map(function (i) { return "- " + (i.amount ? i.amount + " " : "") + i.name; }).join("\n");
        K.toast(K.copyText(text) ? "Kopiert – z. B. in Notizen oder WhatsApp einfügen" : "Kopieren hat nicht geklappt");
      };

      function toggle(item) {
        var k = item.key, copy = JSON.parse(JSON.stringify(item)); delete copy.key;
        copy.done = !copy.done;
        copy.doneAt = copy.done ? Date.now() : 0;
        S().set(k, copy);
        if (copy.done && S().get(autoKey, true)) K.addPantry(copy.name, "Vorrat", "");
      }

      function draw() {
        cb.checked = S().get(autoKey, true);
        var items = K.shopItems();
        var open = items.filter(function (i) { return !i.done; });
        var done = items.filter(function (i) { return i.done; }).sort(function (a, b) { return (b.doneAt || 0) - (a.doneAt || 0); });
        var h = '<div class="k-h2">Offen · ' + open.length + "</div>";
        if (!open.length) h += '<div class="k-muted">Alles erledigt. Zutaten kommen über „🛒“ im Rezept oder den Wochenplan hierher.</div>';
        h += open.map(function (i) { return row(i); }).join("");
        if (done.length) {
          h += '<div class="k-h2 e-done-h">Im Wagen · ' + done.length + '<button class="e-clear">Erledigte löschen</button></div>';
          h += done.map(function (i) { return row(i); }).join("");
        }
        el.querySelector(".e-list").innerHTML = h;
        var all = {}; items.forEach(function (i) { all[i.key] = i; });
        el.querySelectorAll(".e-row").forEach(function (r) {
          r.onclick = function () { toggle(all[r.getAttribute("data-k")]); };
        });
        el.querySelectorAll(".e-del").forEach(function (b) {
          b.onclick = function (ev) { ev.stopPropagation(); S().remove(b.getAttribute("data-k")); };
        });
        var clr = el.querySelector(".e-clear");
        if (clr) clr.onclick = function () { done.forEach(function (i) { S().remove(i.key); }); };
      }
      function row(i) {
        var have = !i.done && K.inPantry(i.name);
        return '<div class="e-row' + (i.done ? " done" : "") + '" data-k="' + i.key + '"><div class="r-box">' + (i.done ? "✓" : "") + "</div>" +
          '<div class="e-txt"><b>' + esc(i.name) + "</b>" + (i.amount ? ' <span class="e-amt">' + esc(i.amount) + "</span>" : "") +
          (i.recipes && i.recipes.length ? '<small>für ' + esc(i.recipes.join(", ")) + "</small>" : "") +
          (have ? '<small class="e-have">laut Vorrat schon da</small>' : "") + "</div>" +
          '<button class="e-del" data-k="' + i.key + '">✕</button></div>';
      }
      draw();
      ctx.onCleanup(S().subscribe(draw));
    },
    css: [
      ".e-wrap { padding: 14px 24px; }",
      ".e-add { display: flex; gap: 10px; } .e-name { flex: 1; } .e-amount { width: 140px; }",
      ".e-tools { display: flex; align-items: center; gap: 16px; margin-top: 12px; flex-wrap: wrap; }",
      ".e-auto { font-size: 16px; color: var(--quiet); display: flex; align-items: center; gap: 8px; }",
      ".e-auto input { width: 22px; height: 22px; }",
      ".e-row { display: flex; align-items: center; gap: 14px; background: var(--card); border: 1px solid var(--line); border-radius: 14px; padding: 10px 14px; margin-bottom: 8px; cursor: pointer; }",
      ".e-row .r-box { flex: 0 0 30px; height: 30px; border-radius: 8px; border: 2px solid var(--quiet); display: flex; align-items: center; justify-content: center; color: #fff; font-weight: 700; }",
      ".e-row.done .r-box { background: var(--done); border-color: var(--done); }",
      ".e-row.done .e-txt { color: var(--done); text-decoration: line-through; }",
      ".e-txt { flex: 1; display: flex; flex-direction: column; font-size: 19px; } .e-txt b { font-weight: 600; }",
      ".e-txt small { font-size: 14px; color: var(--quiet); } .e-amt { color: var(--quiet); font-size: 16px; }",
      ".e-txt .e-have { color: #2E7D32; }",
      ".e-del { border: none; background: none; color: var(--quiet); min-width: 44px; }",
      ".e-done-h { display: flex; align-items: center; gap: 12px; } .e-clear { font-size: 14px; min-height: 36px; padding: 4px 12px; text-transform: none; letter-spacing: 0; }"
    ].join("\n")
  });
})();
