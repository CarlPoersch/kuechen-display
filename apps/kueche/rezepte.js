// ============================================================
// Küche → Bereich "Rezepte"
//   #kueche/rezepte          Liste (Tabs: Rezepte, Airfryer, Gekocht)
//   #kueche/rezept/<id>      ein Rezept: abhaken, Portionen, Einkauf, Einplanen
// Rezepte liegen als JSON-Dateien in apps/rezepte/data/.
// "Gekocht" liegt im gemeinsamen Speicher (synchron mit dem Handy),
// der Abhak-Stand nur auf diesem Gerät.
// ============================================================
(function () {
  var K = window.Kueche, esc = K.esc, fmtDate = K.fmtDate;
  var loadIndex = K.loadIndex;
  var local = K.local();

  function showList(el, ctx) {
    el.innerHTML = '<div class="empty">Lade Rezepte …</div>';
    loadIndex().then(function (recipes) {
      // Zwei Tabs: "Rezepte" (klassisch) und "Airfryer" (speziell für den Airfryer).
      // Welcher Tab ein Rezept hat, steht im Feld "tab" in index.json.
      // Dritter Tab "Gekocht": alle gekochten Rezepte, egal aus welcher Küche oder welchem Tab.
      var tab = local.get("tab", "rezepte");
      var filter = local.get("filter", "Alle");
      var status = local.get("status", "alle"); // alle | offen | gekocht
      var lastRandom = null;
      // Gekocht-Stand aus dem gemeinsamen Speicher als einfache Map
      var cooked = {};
      recipes.forEach(function (r) { var c = K.cooked(r.id); if (c) cooked[r.id] = c; });
      function tabOf(r) { return r.tab === "airfryer" ? "airfryer" : "rezepte"; }
      function inTab() {
        if (tab === "gekocht") {
          return recipes.filter(function (r) { return cooked[r.id]; })
            .sort(function (a, b) { return cooked[b.id].last - cooked[a.id].last; }); // zuletzt gekocht zuerst
        }
        return recipes.filter(function (r) { return tabOf(r) === tab; });
      }
      var tabCount = { rezepte: 0, airfryer: 0 };
      recipes.forEach(function (r) { tabCount[tabOf(r)]++; });
      var cookedCount = recipes.filter(function (r) { return cooked[r.id]; }).length;

      el.innerHTML =
        '<div class="r-tabs"><button data-t="rezepte">Rezepte <span>' + tabCount.rezepte + "</span></button>" +
        '<button data-t="airfryer">🔥 Airfryer <span>' + tabCount.airfryer + "</span></button>" +
        '<button data-t="gekocht">✓ Gekocht <span>' + cookedCount + "</span></button></div>" +
        '<div class="r-toolbar"><button class="primary r-random">🎲 Zufallsrezept</button>' +
        '<div class="r-status"><button data-s="alle">Alle</button><button data-s="offen">Noch nicht gekocht</button>' +
        '<button data-s="gekocht">Schon gekocht</button></div>' +
        '<div class="r-count"></div></div>' +
        '<div class="r-chips"></div><div class="r-grid"></div>' +
        '<div class="r-overlay"><div class="r-suggest"></div></div>';

      el.querySelectorAll(".r-tabs button").forEach(function (b) {
        b.onclick = function () {
          tab = b.dataset.t; local.set("tab", tab);
          filter = "Alle"; local.set("filter", filter);
          buildChips(); renderGrid();
        };
      });
      el.querySelectorAll(".r-status button").forEach(function (b) {
        b.onclick = function () { status = b.dataset.s; local.set("status", status); renderGrid(); };
      });

      // Filter-Knöpfe pro Küche, neu aufgebaut je Tab (die Küchen unterscheiden sich)
      var chips = el.querySelector(".r-chips");
      function buildChips() {
        var list = inTab(), counts = {};
        // Im Tab "Gekocht" keine Küchen-Filter: dort zählt nur, was du gekocht hast
        chips.style.display = tab === "gekocht" ? "none" : "";
        list.forEach(function (r) { var c = r.cuisine || "Sonstige"; counts[c] = (counts[c] || 0) + 1; });
        if (filter !== "Alle" && !counts[filter]) filter = "Alle";
        chips.innerHTML = "";
        ["Alle"].concat(Object.keys(counts).sort()).forEach(function (c) {
          var b = document.createElement("button");
          b.className = "r-chip";
          b.dataset.c = c;
          b.innerHTML = esc(c) + ' <span>' + (c === "Alle" ? list.length : counts[c]) + "</span>";
          b.onclick = function () { filter = c; local.set("filter", c); renderGrid(); };
          chips.appendChild(b);
        });
      }

      function visible() {
        return inTab().filter(function (r) {
          if (tab === "gekocht") return true;
          if (filter !== "Alle" && (r.cuisine || "Sonstige") !== filter) return false;
          if (status === "offen") return !cooked[r.id];
          if (status === "gekocht") return !!cooked[r.id];
          return true;
        });
      }

      function renderGrid() {
        el.querySelectorAll(".r-tabs button").forEach(function (b) { b.classList.toggle("on", b.dataset.t === tab); });
        chips.querySelectorAll(".r-chip").forEach(function (b) { b.classList.toggle("on", b.dataset.c === filter); });
        var stBox = el.querySelector(".r-status");
        stBox.style.display = tab === "gekocht" ? "none" : "";
        stBox.querySelectorAll("button").forEach(function (b) { b.classList.toggle("on", b.dataset.s === status); });
        var list = visible();
        el.querySelector(".r-count").textContent = list.length + " Rezepte";
        if (tab === "gekocht" && !list.length) {
          el.querySelector(".r-grid").innerHTML = '<div class="empty" style="grid-column:1/-1">Noch nichts gekocht.<br>' +
            "Im Rezept auf „✓ Als gekocht markieren“ tippen, dann erscheint es hier.</div>";
          return;
        }
        el.querySelector(".r-random").textContent = "🎲 Zufallsrezept" + (filter === "Alle" ? "" : " · " + filter);
        var grid = el.querySelector(".r-grid");
        grid.innerHTML = "";
        list.forEach(function (r) {
          var st = local.get("stand-" + r.id, null);
          var started = st && Object.keys(st.step || {}).some(function (k) { return st.step[k]; });
          var b = document.createElement("button");
          b.className = "r-card";
          var c = cooked[r.id];
          var meta = tab === "gekocht" && c
            ? esc((r.cuisine ? r.cuisine + " · " : "") + "zuletzt " + fmtDate(c.last) + " · " + c.count + "× gekocht")
            : esc((r.cuisine ? r.cuisine + " · " : "") + r.time);
          b.innerHTML =
            '<div class="r-card-icon">' + esc(r.icon || "🍽") + "</div>" +
            '<div class="r-card-body"><div class="r-card-title">' + esc(r.title) + "</div>" +
            '<div class="r-card-meta">' + meta +
            // Klassische Rezepte, die auf den Airfryer umgestellt wurden, bekommen ein kleines Symbol
            (r.airfryer && tab === "rezepte" ? ' · <span class="r-af">🔥 Airfryer</span>' : "") + "</div></div>" +
            (started ? '<div class="r-badge">angefangen</div>' : "") +
            (c && tab !== "gekocht" ? '<div class="r-badge r-badge-ok">✓ ' + c.count + "×</div>" : "");
          b.onclick = function () { ctx.go("rezept/" + r.id); };
          grid.appendChild(b);
        });
      }

      // ---------- Zufallsrezept ----------
      // Wählt aus der aktuell gefilterten Küche, nie zweimal hintereinander dasselbe.
      var overlay = el.querySelector(".r-overlay");
      function suggest() {
        var list = visible();
        if (!list.length) return;
        var pick, tries = 0;
        do { pick = list[Math.floor(Math.random() * list.length)]; tries++; }
        while (list.length > 1 && lastRandom && pick.id === lastRandom && tries < 10);
        lastRandom = pick.id;
        el.querySelector(".r-suggest").innerHTML =
          '<div class="r-s-label">Wie wär\'s mit …</div>' +
          '<div class="r-s-icon">' + esc(pick.icon || "🍽") + "</div>" +
          '<div class="r-s-title">' + esc(pick.title) + "</div>" +
          '<div class="r-s-meta">' + esc((pick.cuisine || "") + " · " + pick.servings + " Portionen · " + pick.time) + "</div>" +
          '<div class="r-s-actions"><button class="r-s-close">Schließen</button>' +
          '<button class="r-s-again">🎲 Nochmal</button><button class="primary r-s-go">Kochen</button></div>';
        el.querySelector(".r-s-close").onclick = function () { overlay.classList.remove("open"); };
        el.querySelector(".r-s-again").onclick = suggest;
        el.querySelector(".r-s-go").onclick = function () { ctx.go("rezept/" + pick.id); };
        overlay.classList.add("open");
      }
      el.querySelector(".r-random").onclick = suggest;
      // Tippen auf den abgedunkelten Hintergrund schließt den Vorschlag
      overlay.onclick = function (ev) { if (ev.target === overlay) overlay.classList.remove("open"); };

      buildChips();
      renderGrid();
    }).catch(function () {
      el.innerHTML = '<div class="empty">Rezepte konnten nicht geladen werden.<br>Läuft der Server?</div>';
    });
  }

  // ---------- Ein Rezept ----------
  function showRecipe(el, ctx, id) {
    el.innerHTML = '<div class="empty">Lade Rezept …</div>';
    K.loadRecipe(id).then(function (R) { renderRecipe(el, ctx, R); }).catch(function () {
      el.innerHTML = '<div class="empty">Rezept „' + esc(id) + '“ nicht gefunden.</div>';
    });
  }

  function renderRecipe(el, ctx, R) {
    ctx.setTitle(R.title);
    ctx.setBack("Rezepte", "rezepte");
    var KEY = "stand-" + R.id;
    // Portionsrechner: gewählte Portionen merken (pro Rezept, nur auf diesem Gerät)
    var portions = local.get("portionen-" + R.id, R.servings);
    function factor() { return portions / R.servings; }
    var state = local.get(KEY, { ing: {}, step: {} });
    function save() { local.set(KEY, state); }

    el.innerHTML =
      '<div class="r-head"><div class="r-portions"><button class="r-p-minus">−</button>' +
      '<div class="r-p-val"></div><button class="r-p-plus">+</button></div>' +
      '<div class="r-meta">' + esc(R.time) + "</div>" +
      '<div class="r-head-btns"><button class="r-cooked"></button><button class="r-uncook" title="Markierung entfernen">✕</button>' +
      '<button class="r-reset">Neu starten</button></div></div>' +
      '<div class="r-actions"><button class="r-shop">🛒 Zutaten auf Einkaufsliste</button>' +
      '<button class="r-plan">📅 Einplanen</button><div class="r-pantry-info"></div></div>' +
      '<div class="r-progress"><div></div></div>' +
      '<div class="r-main">' +
      '<section class="r-col r-ing"><h2>Zutaten</h2><div class="r-ing-list"></div></section>' +
      '<section class="r-col r-steps"><h2>Zubereitung</h2><div class="r-step-list"></div>' +
      '<div class="r-done">Fertig – guten Appetit!<br><button class="primary r-done-mark">✓ Als gekocht speichern</button></div></section></div>';

    var ingBox = el.querySelector(".r-ing-list");
    var stepBox = el.querySelector(".r-step-list");
    var timerButtons = [];
    var ingRows = [];

    function item(html) {
      var d = document.createElement("div");
      d.className = "r-item";
      d.innerHTML = '<div class="r-box"></div><div class="r-text">' + html + "</div>";
      return d;
    }

    R.ingredients.forEach(function (ing, i) {
      if (ing.group) {
        var g = document.createElement("div");
        g.className = "r-group";
        g.textContent = ing.group;
        ingBox.appendChild(g);
        return;
      }
      var d = item('<span class="r-amount"></span> ' + esc(ing.name) + '<span class="r-have">im Vorrat</span>');
      d.dataset.kind = "ing"; d.dataset.idx = i;
      ingRows.push({ el: d, ing: ing });
      d.onclick = function () { state.ing[i] = !state.ing[i]; save(); render(); };
      ingBox.appendChild(d);
    });

    R.steps.forEach(function (st, i) {
      var d = item('<div class="r-num">Schritt ' + (i + 1) + "</div>" + esc(st.text));
      d.classList.add("r-step");
      d.dataset.kind = "step"; d.dataset.idx = i;
      if (st.minutes) {
        // Timer läuft über den zentralen Timer-Dienst → läuft auch weiter, wenn du die App verlässt
        var key = "rezepte/" + R.id + "/" + i;
        var b = document.createElement("button");
        b.className = "r-timer";
        b.onclick = function (ev) {
          ev.stopPropagation(); // Warum: Tipp auf den Timer soll den Schritt nicht abhaken
          if (Launcher.timers.get(key)) Launcher.timers.cancel(key);
          else Launcher.timers.start(key, R.title + " · Schritt " + (i + 1), st.minutes * 60);
        };
        timerButtons.push({ btn: b, key: key, minutes: st.minutes });
        d.querySelector(".r-text").appendChild(b);
      }
      d.onclick = function () {
        state.step[i] = !state.step[i]; save(); render();
        setTimeout(scrollToCurrent, 50);
      };
      stepBox.appendChild(d);
    });

    function updateTimers() {
      timerButtons.forEach(function (tb) {
        var t = Launcher.timers.get(tb.key);
        if (!t) { tb.btn.className = "r-timer"; tb.btn.textContent = "⏱ " + tb.minutes + " Min. starten"; }
        else if (t.ringing) { tb.btn.className = "r-timer ringing"; tb.btn.textContent = "⏰ Zeit ist um! Tippen zum Stoppen"; }
        else { tb.btn.className = "r-timer running"; tb.btn.textContent = "⏱ " + Launcher.timers.fmt(Launcher.timers.left(t)) + " · Tippen zum Stoppen"; }
      });
    }
    // Warum onCleanup: Beim Verlassen der Seite das Abo beenden, sonst würde es ins Leere aktualisieren.
    ctx.onCleanup(Launcher.timers.subscribe(updateTimers));
    updateTimers();

    function render() {
      var current = -1, done = 0;
      el.querySelectorAll(".r-item").forEach(function (d) {
        var on = d.dataset.kind === "ing" ? state.ing[d.dataset.idx] : state.step[d.dataset.idx];
        d.classList.toggle("checked", !!on);
        d.querySelector(".r-box").textContent = on ? "✓" : "";
      });
      for (var i = 0; i < R.steps.length; i++) { if (!state.step[i]) { current = i; break; } }
      el.querySelectorAll(".r-step").forEach(function (d) {
        var idx = Number(d.dataset.idx);
        d.classList.toggle("current", idx === current);
        if (state.step[idx]) done++;
      });
      el.querySelector(".r-progress > div").style.width = (done / R.steps.length * 100) + "%";
      el.classList.toggle("r-all-done", current === -1);
    }

    function scrollToCurrent() {
      var c = el.querySelector(".r-step.current");
      if (c) c.scrollIntoView({ behavior: "smooth", block: "center" });
    }

    // "Gekocht"-Knöpfe: oben jederzeit, unten nach dem letzten Schritt
    function renderCooked() {
      var c = K.cooked(R.id);
      var b = el.querySelector(".r-cooked");
      b.className = "r-cooked" + (c ? " on" : "");
      b.textContent = c ? "✓ " + c.count + "× gekocht · zuletzt " + fmtDate(c.last) : "✓ Als gekocht markieren";
      el.querySelector(".r-uncook").style.display = c ? "" : "none";
      var dm = el.querySelector(".r-done-mark");
      dm.textContent = c && Date.now() - c.last < 3 * 3600000 ? "✓ Gespeichert" : "✓ Als gekocht speichern";
    }
    function mark() {
      var c = K.cooked(R.id);
      // Doppeltipp-Schutz: innerhalb von 3 Stunden zählt dasselbe Rezept nur einmal
      if (c && Date.now() - c.last < 3 * 3600000) return;
      K.markCooked(R.id); renderCooked();
    }
    el.querySelector(".r-cooked").onclick = mark;
    el.querySelector(".r-done-mark").onclick = mark;
    el.querySelector(".r-uncook").onclick = function () { K.unmarkCooked(R.id); renderCooked(); };
    renderCooked();

    // ---------- Portionen + Vorrat ----------
    function renderIngredients() {
      el.querySelector(".r-p-val").textContent = portions + (portions === 1 ? " Portion" : " Portionen");
      var have = 0, total = 0;
      ingRows.forEach(function (r) {
        r.el.querySelector(".r-amount").textContent = K.scaleAmount(r.ing.amount, factor());
        var inP = K.inPantry(r.ing.name);
        r.el.classList.toggle("in-pantry", inP && !K.isBasic(r.ing.name));
        if (!K.isBasic(r.ing.name)) { total++; if (inP) have++; }
      });
      el.querySelector(".r-pantry-info").textContent = have ? have + " von " + total + " Zutaten im Vorrat" : "";
    }
    el.querySelector(".r-p-minus").onclick = function () {
      if (portions > 1) { portions--; local.set("portionen-" + R.id, portions); renderIngredients(); }
    };
    el.querySelector(".r-p-plus").onclick = function () {
      if (portions < 20) { portions++; local.set("portionen-" + R.id, portions); renderIngredients(); }
    };
    renderIngredients();
    // Vorrat kann sich auf einem anderen Gerät ändern -> Markierungen aktuell halten
    ctx.onCleanup(Launcher.store.subscribe(function () { renderIngredients(); renderCooked(); }));

    el.querySelector(".r-shop").onclick = function () {
      var items = ingRows.map(function (r) { return { name: r.ing.name, amount: K.scaleAmount(r.ing.amount, factor()) }; });
      var res = K.addToShopping(items, R.title);
      K.toast((res.added + res.merged) + " Zutaten auf die Einkaufsliste" +
        (res.skipped.length ? " · " + res.skipped.length + " schon da" : ""));
    };

    el.querySelector(".r-plan").onclick = function () {
      // Die nächsten 7 Tage zur Auswahl
      var h = "<h3>📅 Wann kochst du " + esc(R.title) + "?</h3><div class=\"r-days\">";
      for (var i = 0; i < 7; i++) {
        var d = new Date(); d.setDate(d.getDate() + i);
        var n = K.planFor(K.isoDate(d)).length;
        h += '<button data-d="' + K.isoDate(d) + '">' + (i === 0 ? "Heute" : i === 1 ? "Morgen" : K.DAYS_LONG[d.getDay()]) +
          '<span>' + d.getDate() + "." + (d.getMonth() + 1) + "." + (n ? " · " + n + " geplant" : "") + "</span></button>";
      }
      h += '</div><div class="k-row"><button class="r-d-close">Abbrechen</button></div>';
      var box = K.dialog(el, h);
      box.querySelector(".r-d-close").onclick = box.close;
      box.querySelectorAll("[data-d]").forEach(function (b) {
        b.onclick = function () {
          K.addToPlan(b.getAttribute("data-d"), R.id, portions);
          box.close();
          K.toast("Eingeplant für " + b.firstChild.textContent);
        };
      });
    };

    el.querySelector(".r-reset").onclick = function () {
      state = { ing: {}, step: {} }; save(); render(); scrollToCurrent();
    };

    render();
    setTimeout(scrollToCurrent, 300);
  }

  K.register({
    id: "rezepte",
    name: "Rezepte",
    icon: "📖",
    render: function (el, ctx, arg) {
      if (arg) showRecipe(el, ctx, arg);
      else showList(el, ctx);
    },
    // Aussehen. Präfix "r-", damit es nicht mit anderen Bereichen kollidiert.
    css: [
      ".r-tabs { display: flex; gap: 0; margin: 16px 24px 0; border: 1px solid var(--line); border-radius: 14px; overflow: hidden; width: max-content; }",
      ".r-tabs button { border: none; border-radius: 0; font-size: 20px; padding: 10px 28px; }",
      ".r-tabs button span { color: var(--quiet); font-size: 15px; margin-left: 4px; }",
      ".r-tabs button.on { background: var(--ink); color: #fff; }",
      ".r-tabs button.on span { color: rgba(255,255,255,.7); }",
      ".r-af { color: var(--accent); }",
      ".r-portions { display: flex; align-items: center; gap: 4px; }",
      ".r-portions button { width: 48px; font-size: 24px; padding: 0; }",
      ".r-p-val { min-width: 120px; text-align: center; font-weight: 600; font-size: 18px; }",
      ".r-head { gap: 12px; }",
      ".r-actions { display: flex; align-items: center; gap: 10px; padding: 0 24px 10px; flex-wrap: wrap; }",
      ".r-actions button { font-size: 17px; }",
      ".r-pantry-info { color: #2E7D32; font-size: 16px; }",
      ".r-have { display: none; margin-left: 8px; font-size: 13px; color: #2E7D32; background: #E3F1E4; border-radius: 8px; padding: 1px 6px; white-space: nowrap; }",
      ".r-item.in-pantry .r-have { display: inline-block; }",
      ".r-days { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }",
      ".r-days button { display: flex; flex-direction: column; align-items: flex-start; font-size: 19px; font-weight: 600; padding: 12px 16px; }",
      ".r-days button span { font-size: 14px; font-weight: 400; color: var(--quiet); }",
      ".r-status { display: flex; border: 1px solid var(--line); border-radius: 12px; overflow: hidden; }",
      ".r-status button { border: none; border-radius: 0; font-size: 16px; padding: 8px 14px; min-height: 44px; }",
      ".r-status button.on { background: var(--accent-soft); color: var(--accent); font-weight: 600; }",
      ".r-badge-ok { color: #2E7D32; background: #E3F1E4; margin-left: 6px; }",
      ".r-head-btns { display: flex; gap: 8px; }",
      ".r-head .r-cooked { color: var(--accent); border-color: var(--accent); }",
      ".r-head .r-cooked.on { color: #2E7D32; border-color: #A5D6A7; background: #E3F1E4; }",
      ".r-uncook { color: var(--quiet); min-width: 48px; }",
      ".r-done-mark { margin-top: 14px; font-size: 20px; }",
      ".r-toolbar { display: flex; align-items: center; gap: 16px; padding: 14px 24px 0; }",
      ".r-random { font-size: 20px; padding: 12px 22px; }",
      ".r-count { color: var(--quiet); font-size: 16px; }",
      ".r-chips { display: flex; gap: 8px; padding: 14px 24px 4px; overflow-x: auto; }",
      ".r-chip { flex: 0 0 auto; border-radius: 24px; font-size: 17px; padding: 8px 16px; min-height: 44px; }",
      ".r-chip span { color: var(--quiet); font-size: 14px; margin-left: 4px; }",
      ".r-chip.on { background: var(--accent); border-color: var(--accent); color: #fff; }",
      ".r-chip.on span { color: rgba(255,255,255,.8); }",
      ".r-grid { padding: 12px 24px 24px; display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 12px; }",
      ".r-card { display: flex; align-items: center; gap: 14px; text-align: left; padding: 12px 16px; border-radius: 16px; }",
      ".r-card-icon { font-size: 36px; }",
      ".r-card-body { flex: 1; min-width: 0; }",
      ".r-card-title { font-size: 20px; font-weight: 600; }",
      ".r-overlay { display: none; position: fixed; left: 0; right: 0; top: 0; bottom: 0; background: rgba(43,36,32,.45); z-index: 10; align-items: center; justify-content: center; }",
      ".r-overlay.open { display: flex; }",
      ".r-suggest { background: var(--card); border-radius: 24px; padding: 32px 40px; text-align: center; width: 520px; max-width: 90%; box-shadow: 0 10px 40px rgba(0,0,0,.2); }",
      ".r-s-label { color: var(--quiet); font-size: 18px; }",
      ".r-s-icon { font-size: 80px; line-height: 1.2; margin-top: 8px; }",
      ".r-s-title { font-size: 30px; font-weight: 700; margin-top: 4px; }",
      ".r-s-meta { color: var(--quiet); font-size: 17px; margin-top: 6px; }",
      ".r-s-actions { display: flex; gap: 12px; justify-content: center; margin-top: 24px; }",
      ".r-card-meta { font-size: 16px; color: var(--quiet); }",
      ".r-badge { font-size: 14px; color: var(--accent); background: var(--accent-soft); padding: 4px 10px; border-radius: 10px; }",

      ".r-head { display: flex; align-items: center; justify-content: space-between; padding: 12px 24px 8px; }",
      ".r-meta { color: var(--quiet); font-size: 16px; }",
      ".r-head button { font-size: 16px; color: var(--quiet); }",
      ".r-progress { height: 6px; background: var(--line); margin: 0 24px; border-radius: 3px; overflow: hidden; }",
      ".r-progress > div { height: 100%; width: 0; background: var(--accent); transition: width .3s; }",
      ".r-main { display: flex; gap: 20px; padding: 16px 24px 24px; }",
      ".r-col { background: var(--card); border: 1px solid var(--line); border-radius: 16px; padding: 8px 0; overflow-y: auto; }",
      ".r-ing { flex: 0 0 36%; } .r-steps { flex: 1; }",
      // Querformat: Spalten scrollen einzeln. Hochformat: untereinander.
      "@media (orientation: landscape) { .r-main { height: calc(100% - 60px); } }",
      "@media (orientation: portrait) { .r-main { flex-direction: column; } }",
      ".r-col h2 { font-size: 15px; letter-spacing: .06em; text-transform: uppercase; color: var(--quiet); margin: 10px 20px 6px; }",
      ".r-item { display: flex; gap: 14px; align-items: flex-start; padding: 12px 20px; border-top: 1px solid var(--line); cursor: pointer; }",
      ".r-box { flex: 0 0 30px; height: 30px; border-radius: 8px; border: 2px solid var(--quiet); display: flex; align-items: center; justify-content: center; margin-top: 1px; color: #fff; font-size: 20px; font-weight: 700; }",
      ".r-item.checked .r-box { background: var(--done); border-color: var(--done); }",
      ".r-item.checked .r-text { color: var(--done); text-decoration: line-through; }",
      ".r-amount { font-weight: 600; white-space: nowrap; }",
      ".r-group { padding: 14px 20px 4px; font-weight: 600; color: var(--accent); font-size: 17px; }",
      ".r-step.current { background: var(--accent-soft); }",
      ".r-step.current .r-box { border-color: var(--accent); }",
      ".r-num { color: var(--quiet); font-size: 15px; }",
      ".r-step.current .r-num { color: var(--accent); font-weight: 600; }",
      ".r-step .r-text { font-size: 22px; }",
      ".r-timer { display: block; margin-top: 10px; font-size: 18px; border-color: var(--accent); color: var(--accent); text-decoration: none; }",
      ".r-timer.running { background: var(--accent); color: #fff; }",
      ".r-timer.ringing { animation: blink-light .6s infinite alternate; }",
      ".r-done { display: none; text-align: center; padding: 24px; font-size: 24px; font-weight: 600; color: var(--accent); }",
      ".r-all-done .r-done { display: block; }"
    ].join("\n")
  });
})();
