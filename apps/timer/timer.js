// ============================================================
// Unterapp "Küchentimer" – zugleich das kleinste Beispiel dafür,
// wie eine Unterapp aufgebaut ist.
// Nutzt den zentralen Timer-Dienst, deshalb laufen die Timer weiter,
// wenn du zurück zum Start oder in die Rezepte gehst.
// ============================================================
(function () {
  var PRESETS = [1, 3, 5, 10, 15, 20, 30, 60]; // Minuten

  Launcher.register({
    id: "timer",
    name: "Timer",
    icon: "⏱",
    color: "#0f766e",

    mount: function (el, ctx) {
      // Zuletzt eingestellte Minuten merken
      var custom = ctx.storage.get("custom", 8);

      el.innerHTML =
        '<div class="t-wrap">' +
        '<h2 class="t-h">Schnellstart</h2><div class="t-presets"></div>' +
        '<h2 class="t-h">Eigene Zeit</h2>' +
        '<div class="t-custom"><button class="t-minus">−</button><div class="t-val"></div>' +
        '<button class="t-plus">+</button><button class="primary t-go">Starten</button></div>' +
        '<h2 class="t-h">Laufende Timer</h2><div class="t-active"></div></div>';

      var n = 0; // zählt Timer hoch, damit jeder einen eigenen Schlüssel bekommt
      function startTimer(min) {
        n++;
        Launcher.timers.start("timer/" + Date.now() + "-" + n, min + " Min.", min * 60);
      }

      PRESETS.forEach(function (m) {
        var b = document.createElement("button");
        b.className = "t-preset";
        b.textContent = m < 60 ? m + " Min." : "1 Std.";
        b.onclick = function () { startTimer(m); };
        el.querySelector(".t-presets").appendChild(b);
      });

      function showCustom() { el.querySelector(".t-val").textContent = custom + " Min."; ctx.storage.set("custom", custom); }
      el.querySelector(".t-minus").onclick = function () { custom = Math.max(1, custom - 1); showCustom(); };
      el.querySelector(".t-plus").onclick = function () { custom = Math.min(180, custom + 1); showCustom(); };
      el.querySelector(".t-go").onclick = function () { startTimer(custom); };
      showCustom();

      // Liste der laufenden Timer (alle, auch die aus Rezepten)
      var box = el.querySelector(".t-active");
      var sig = null;
      function update() {
        var all = Launcher.timers.all();
        var s = all.map(function (t) { return t.key + (t.ringing ? "!" : ""); }).join("|");
        if (s !== sig) { // nur bei Änderung neu aufbauen (sonst gehen Tipps verloren)
          sig = s;
          box.innerHTML = all.length ? "" : '<div class="t-none">Kein Timer aktiv</div>';
          all.forEach(function (t) {
            var row = document.createElement("div");
            row.className = "t-row" + (t.ringing ? " ringing" : "");
            row.innerHTML = '<div class="t-label">' + Launcher.esc(t.label) + '</div><div class="t-left"></div>';
            var x = document.createElement("button");
            x.textContent = t.ringing ? "Stopp" : "Abbrechen";
            x.onclick = function () { Launcher.timers.cancel(t.key); };
            row.appendChild(x);
            box.appendChild(row);
          });
        }
        var lefts = box.querySelectorAll(".t-left");
        all.forEach(function (t, i) {
          if (lefts[i]) lefts[i].textContent = t.ringing ? "⏰" : Launcher.timers.fmt(Launcher.timers.left(t));
        });
      }
      ctx.onCleanup(Launcher.timers.subscribe(update));
      update();
    },

    css: [
      ".t-wrap { padding: 16px 32px 32px; }",
      ".t-h { font-size: 15px; letter-spacing: .06em; text-transform: uppercase; color: var(--quiet); margin: 24px 0 12px; }",
      ".t-presets { display: flex; flex-wrap: wrap; gap: 12px; }",
      ".t-preset { min-width: 120px; font-size: 22px; padding: 16px; }",
      ".t-custom { display: flex; align-items: center; gap: 12px; }",
      ".t-custom .t-minus, .t-custom .t-plus { width: 64px; font-size: 28px; }",
      ".t-val { min-width: 120px; text-align: center; font-size: 28px; font-weight: 600; }",
      ".t-row { display: flex; align-items: center; gap: 16px; background: var(--card); border: 1px solid var(--line); border-radius: 14px; padding: 10px 16px; margin-bottom: 10px; }",
      ".t-row.ringing { animation: blink-light .6s infinite alternate; }",
      ".t-label { flex: 1; }",
      ".t-left { font-size: 28px; font-weight: 600; font-variant-numeric: tabular-nums; }",
      ".t-none { color: var(--quiet); }"
    ].join("\n")
  });
})();
