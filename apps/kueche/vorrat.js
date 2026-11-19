// ============================================================
// Küche → Bereich "Vorrat & Kühlschrank"
// - Was ist da? (Kühlschrank, Vorrat, Tiefkühler), optional mit MHD
// - "Bald verbrauchen": Ablaufendes oben, rot/gelb markiert
// - "Was kann ich kochen?": Rezepte nach vorhandenen Zutaten sortiert,
//   Rezepte mit bald ablaufenden Zutaten zuerst
// Gespeichert pro Artikel unter "pantry:<id>" → synchron mit dem Handy.
// ============================================================
(function () {
  var K = window.Kueche, esc = K.esc, S = function () { return Launcher.store; };
  var PLACES = ["Kühlschrank", "Vorrat", "Tiefkühler"];
  // Häufige Grundzutaten zum schnellen Antippen
  var QUICK = ["Reis", "Nudeln", "Eier", "Milch", "Butter", "Zwiebeln", "Knoblauch", "Öl", "Olivenöl", "Mehl", "Zucker",
    "Sojasauce", "Tomaten (Dose)", "Kartoffeln", "Käse", "Joghurt", "Sahne", "Hähnchen", "Hackfleisch", "Paprika",
    "Karotten", "Ingwer", "Limetten", "Zitrone", "Kokosmilch", "Brühe", "Honig", "Senf"];

  function mhdLabel(iso) {
    if (!iso) return "";
    var d = K.daysUntil(iso);
    return d < 0 ? "abgelaufen" : d === 0 ? "heute" : d === 1 ? "morgen" : d <= 7 ? "in " + d + " Tagen" : K.fmtDate(K.parseIso(iso));
  }
  function mhdClass(iso) {
    if (!iso) return "";
    var d = K.daysUntil(iso);
    return d <= 1 ? "red" : d <= 4 ? "yellow" : "";
  }

  K.register({
    id: "vorrat", name: "Vorrat", icon: "🧺",
    badge: function () {
      var n = K.pantryItems().filter(function (p) { return p.mhd && K.daysUntil(p.mhd) <= 2; }).length;
      return n ? { text: n + " ⏳", warn: true } : "";
    },
    render: function (el, ctx) {
      el.innerHTML = '<div class="v-wrap"><div class="v-cols">' +
        '<div class="v-left">' +
        '<form class="v-add"><input class="k-input v-name" placeholder="z. B. Hähnchenbrust" autocomplete="off">' +
        '<select class="k-input v-place">' + PLACES.map(function (p) { return "<option>" + p + "</option>"; }).join("") + "</select>" +
        '<button class="primary">+</button></form>' +
        '<div class="v-mhd-row"><span class="k-muted">MHD:</span>' +
        '<button type="button" data-d="">keins</button><button type="button" data-d="2">+2 Tage</button>' +
        '<button type="button" data-d="5">+5 Tage</button><button type="button" data-d="14">+2 Wochen</button>' +
        '<input type="date" class="k-input v-date"></div>' +
        '<div class="k-h2">Schnell hinzufügen</div><div class="v-quick"></div>' +
        '<div class="v-list"></div></div>' +
        '<div class="v-right"><div class="k-h2">Was kann ich kochen?</div><div class="v-cook"><div class="k-muted">Lade …</div></div></div>' +
        "</div></div>";

      var dateIn = el.querySelector(".v-date");
      // MHD-Schnellwahl setzt das Datumsfeld
      el.querySelectorAll(".v-mhd-row [data-d]").forEach(function (b) {
        b.onclick = function () {
          var n = b.getAttribute("data-d");
          if (!n) { dateIn.value = ""; return; }
          var d = new Date(); d.setDate(d.getDate() + (+n)); dateIn.value = K.isoDate(d);
        };
      });
      el.querySelector(".v-add").onsubmit = function (ev) {
        ev.preventDefault();
        var n = el.querySelector(".v-name");
        if (!n.value.trim()) return;
        K.addPantry(n.value.trim(), el.querySelector(".v-place").value, dateIn.value);
        n.value = ""; dateIn.value = "";
      };

      var recipes = null;
      K.loadIndex().then(function (r) { recipes = r; drawCook(); });

      function drawList() {
        var items = K.pantryItems();
        // Schnell-Knöpfe nur für Dinge, die noch fehlen
        el.querySelector(".v-quick").innerHTML = QUICK.filter(function (q) {
          return !items.some(function (p) { return K.keyWord(p.name) === K.keyWord(q); });
        }).map(function (q) { return '<button class="v-q">' + esc(q) + "</button>"; }).join("");
        el.querySelectorAll(".v-q").forEach(function (b) {
          b.onclick = function () {
            var q = b.textContent;
            var fridge = ["Milch", "Butter", "Eier", "Käse", "Joghurt", "Sahne", "Hähnchen", "Hackfleisch", "Paprika", "Karotten", "Limetten", "Zitrone", "Ingwer"];
            K.addPantry(q, fridge.indexOf(q) >= 0 ? "Kühlschrank" : "Vorrat", "");
          };
        });

        var h = "";
        PLACES.forEach(function (place) {
          var list = items.filter(function (p) { return (p.place || "Vorrat") === place; })
            .sort(function (a, b) { return (a.mhd || "9999") < (b.mhd || "9999") ? -1 : (a.mhd || "9999") > (b.mhd || "9999") ? 1 : a.name.localeCompare(b.name); });
          if (!list.length) return;
          h += '<div class="k-h2">' + (place === "Kühlschrank" ? "❄️ " : place === "Tiefkühler" ? "🧊 " : "🥫 ") + place + " · " + list.length + "</div><div class=\"v-items\">";
          list.forEach(function (p) {
            h += '<div class="v-item ' + mhdClass(p.mhd) + '"><span class="v-n">' + esc(p.name) + "</span>" +
              (p.mhd ? '<span class="v-m">' + mhdLabel(p.mhd) + "</span>" : "") +
              '<button class="v-buy" data-k="' + p.key + '" title="Aufgebraucht, nachkaufen">🛒</button>' +
              '<button class="v-del" data-k="' + p.key + '" title="Aufgebraucht">✕</button></div>';
          });
          h += "</div>";
        });
        if (!items.length) h = '<div class="k-muted" style="margin-top:16px">Noch nichts im Vorrat. Tipp: Oben die Grundzutaten antippen, die du zu Hause hast.</div>';
        el.querySelector(".v-list").innerHTML = h;
        var byKey = {}; items.forEach(function (p) { byKey[p.key] = p; });
        el.querySelectorAll(".v-del").forEach(function (b) { b.onclick = function () { S().remove(b.getAttribute("data-k")); }; });
        el.querySelectorAll(".v-buy").forEach(function (b) {
          b.onclick = function () {
            var p = byKey[b.getAttribute("data-k")];
            S().remove(p.key);
            K.addToShopping([{ name: p.name, amount: "" }], "");
            K.toast(p.name + " ist jetzt auf der Einkaufsliste");
          };
        });
      }

      function drawCook() {
        if (!recipes) return;
        var items = K.pantryItems();
        var expiring = items.filter(function (p) { return p.mhd && K.daysUntil(p.mhd) <= 3; });
        // Bewertung: Anteil vorhandener Zutaten, Bonus für bald ablaufende
        var scored = recipes.map(function (r) {
          var need = (r.ing || []).filter(function (n) { return !K.isBasic(n); });
          var have = need.filter(function (n) { return K.inPantry(n); });
          var missing = [], seen = {};
          need.forEach(function (n) { // doppelte Zutaten (z. B. Stärke in Marinade und Sauce) nur einmal
            var k = K.keyWord(n);
            if (!K.inPantry(n) && !seen[k]) { seen[k] = 1; missing.push(n); }
          });
          var usesExp = expiring.filter(function (p) { return need.some(function (n) { return K.sameThing(n, p.name); }); });
          return { r: r, need: need.length, have: have.length, missing: missing, exp: usesExp,
            score: (need.length ? have.length / need.length : 0) + usesExp.length * 0.3 };
        }).filter(function (x) { return x.have >= 2; })
          .sort(function (a, b) { return b.score - a.score || a.missing.length - b.missing.length; })
          .slice(0, 12);
        var box = el.querySelector(".v-cook");
        if (!items.length) { box.innerHTML = '<div class="k-muted">Trag ein paar Sachen in den Vorrat ein, dann schlage ich hier passende Rezepte vor.</div>'; return; }
        if (!scored.length) { box.innerHTML = '<div class="k-muted">Noch zu wenig im Vorrat für einen Vorschlag.</div>'; return; }
        box.innerHTML = scored.map(function (x) {
          var pct = Math.round(x.have / x.need * 100);
          return '<div class="v-rec"><button class="v-open" data-id="' + esc(x.r.id) + '"><span class="k-ic">' + esc(x.r.icon) + "</span>" +
            '<span class="v-rt">' + esc(x.r.title) + "<small>" + x.have + " von " + x.need + " Zutaten da" +
            (x.missing.length ? " · fehlt: " + esc(x.missing.slice(0, 4).map(function (m) { return m.split(",")[0]; }).join(", ")) + (x.missing.length > 4 ? " …" : "") : "") +
            "</small>" + (x.exp.length ? '<small class="v-exp">⏳ verbraucht ' + esc(x.exp.map(function (p) { return p.name; }).join(", ")) + "</small>" : "") +
            '</span><span class="v-pct" style="--p:' + pct + '%">' + pct + "%</span></button>" +
            (x.missing.length ? '<button class="v-miss" data-id="' + esc(x.r.id) + '" title="Fehlendes auf die Einkaufsliste">🛒</button>' : "") + "</div>";
        }).join("");
        var byId = {}; scored.forEach(function (x) { byId[x.r.id] = x; });
        box.querySelectorAll(".v-open").forEach(function (b) { b.onclick = function () { ctx.go("rezept/" + b.getAttribute("data-id")); }; });
        box.querySelectorAll(".v-miss").forEach(function (b) {
          b.onclick = function () {
            var x = byId[b.getAttribute("data-id")];
            K.loadRecipe(x.r.id).then(function (R) {
              var res = K.addToShopping(R.ingredients.filter(function (i) { return i.name; }).map(function (i) { return { name: i.name, amount: i.amount }; }), R.title);
              K.toast((res.added + res.merged) + " fehlende Zutaten für " + R.title + " auf der Liste");
            });
          };
        });
      }

      function draw() { drawList(); drawCook(); }
      draw();
      ctx.onCleanup(S().subscribe(draw));
    },
    css: [
      ".v-wrap { padding: 14px 24px; }",
      ".v-cols { display: flex; gap: 24px; align-items: flex-start; }",
      ".v-left { flex: 1; min-width: 0; } .v-right { flex: 1; min-width: 0; }",
      "@media (orientation: portrait) { .v-cols { flex-direction: column; } .v-right { width: 100%; } }",
      ".v-add { display: flex; gap: 8px; } .v-name { flex: 1; min-width: 0; } .v-add button { width: 56px; font-size: 24px; }",
      ".v-mhd-row { display: flex; align-items: center; gap: 6px; margin-top: 10px; flex-wrap: wrap; }",
      ".v-mhd-row button { font-size: 15px; min-height: 40px; padding: 4px 10px; } .v-date { font-size: 16px; min-height: 40px; padding: 4px 8px; }",
      ".v-quick { display: flex; flex-wrap: wrap; gap: 6px; }",
      ".v-q { font-size: 15px; min-height: 38px; padding: 4px 12px; border-radius: 20px; border-style: dashed; }",
      ".v-items { display: flex; flex-direction: column; gap: 6px; }",
      ".v-item { display: flex; align-items: center; gap: 10px; background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 6px 6px 6px 14px; }",
      ".v-n { flex: 1; font-size: 18px; } .v-m { font-size: 14px; font-weight: 600; color: var(--quiet); }",
      ".v-item.red { border-color: #F2B8B5; background: #FDECEA; } .v-item.red .v-m { color: #D7262F; }",
      ".v-item.yellow { border-color: #F3D9A4; background: #FFF6E5; } .v-item.yellow .v-m { color: #B7791F; }",
      ".v-buy, .v-del { border: none; background: none; min-width: 44px; color: var(--quiet); }",
      ".v-rec { display: flex; align-items: stretch; gap: 6px; margin-bottom: 8px; }",
      ".v-open { flex: 1; display: flex; align-items: center; gap: 10px; text-align: left; }",
      ".v-rt { flex: 1; display: flex; flex-direction: column; font-size: 18px; font-weight: 600; }",
      ".v-rt small { font-size: 13px; font-weight: 400; color: var(--quiet); } .v-rt .v-exp { color: #B7791F; font-weight: 600; }",
      ".v-pct { font-size: 15px; font-weight: 700; color: #2E7D32; min-width: 48px; text-align: right; }",
      ".v-miss { min-width: 52px; }"
    ].join("\n")
  });
})();
