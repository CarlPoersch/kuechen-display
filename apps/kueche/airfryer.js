// ============================================================
// Küche → Bereich "Airfryer-Spickzettel"
// Zeit und Temperatur für Alltägliches auf einen Blick.
// Richtwerte: Airfryer heizen unterschiedlich stark. Beim ersten Mal
// gegen Ende reinschauen. Korb nie zu voll machen.
// ============================================================
(function () {
  var K = window.Kueche, esc = K.esc;
  // [Gruppe, Lebensmittel, °C, Minuten, Tipp]
  var ROWS = [
    ["TK & Fertig", "TK-Pommes", 200, "15–18", "Alle 5 Min. schütteln"],
    ["TK & Fertig", "TK-Kroketten", 200, "10–12", "Nach der Hälfte wenden"],
    ["TK & Fertig", "Chicken Nuggets (TK)", 200, "10–12", "In einer Lage"],
    ["TK & Fertig", "Fischstäbchen (TK)", 200, "8–10", "Nach der Hälfte wenden"],
    ["TK & Fertig", "Pizza (TK, klein)", 180, "8–10", "Auf Backpapier"],
    ["TK & Fertig", "Gyoza / Dumplings (TK)", 190, "10–12", "Vorher mit Öl benetzen"],
    ["TK & Fertig", "Frühlingsrollen (TK)", 190, "10–12", "Nach der Hälfte wenden"],
    ["TK & Fertig", "Croissants / Aufbackbrötchen", 170, "6–10", "Nicht stapeln"],
    ["TK & Fertig", "Brötchen aufbacken (Vortag)", 180, "3–4", "Kurz mit Wasser besprühen"],
    ["Fleisch & Fisch", "Hähnchenbrust", 180, "15–18", "Kerntemperatur 74 °C"],
    ["Fleisch & Fisch", "Hähnchenschenkel", 190, "22–25", "Hautseite zuletzt oben"],
    ["Fleisch & Fisch", "Chicken Wings", 180, "20 + 5 bei 200 °C", "Mit Backpulver knuspriger"],
    ["Fleisch & Fisch", "Bratwurst", 190, "10–12", "Nach der Hälfte wenden"],
    ["Fleisch & Fisch", "Frikadellen", 180, "12–14", "Nach der Hälfte wenden"],
    ["Fleisch & Fisch", "Schnitzel, paniert", 190, "10–12", "Mit etwas Öl einsprühen"],
    ["Fleisch & Fisch", "Lachsfilet", 190, "8–10", "Innen noch leicht glasig"],
    ["Fleisch & Fisch", "Speck", 180, "6–8", "Backpapier gegen Fettspritzer"],
    ["Gemüse & Beilagen", "Kartoffelspalten (frisch)", 190, "18–22", "Vorher einweichen, gut trocknen"],
    ["Gemüse & Beilagen", "Pommes (frisch)", "180 → 200", "20 + 5", "Siehe Rezept „Knusprige Pommes“"],
    ["Gemüse & Beilagen", "Süßkartoffel-Pommes", 190, "15–18", "Mit Stärke bestäuben"],
    ["Gemüse & Beilagen", "Ganze Kartoffel", 200, "35–45", "Einstechen, mit Öl und Salz"],
    ["Gemüse & Beilagen", "Brokkoli", 190, "7–9", "Mit Öl, Salz; Spitzen werden knusprig"],
    ["Gemüse & Beilagen", "Rosenkohl, halbiert", 180, "12–15", "Schnittfläche nach unten"],
    ["Gemüse & Beilagen", "Paprika, Zucchini, Zwiebel", 200, "10–12", "Einmal schütteln"],
    ["Gemüse & Beilagen", "Halloumi", 200, "6–8", "Dicke Scheiben"],
    ["Gemüse & Beilagen", "Tofu-Würfel", 200, "12–15", "Mit Stärke bestäuben"],
    ["Gemüse & Beilagen", "Kichererbsen (Snack)", 200, "12–15", "Gut trocknen, mit Gewürzen"],
    ["Snacks & Sonstiges", "Eier, wachsweich", 150, "9–10", "Danach in Eiswasser"],
    ["Snacks & Sonstiges", "Eier, hart", 150, "13–15", "Danach in Eiswasser"],
    ["Snacks & Sonstiges", "Nüsse rösten", 160, "4–6", "Leicht wird es schnell zu dunkel"],
    ["Snacks & Sonstiges", "Pizza aufwärmen", 180, "3–4", "Boden wird wieder knusprig"],
    ["Snacks & Sonstiges", "Pommes aufwärmen", 200, "3–4", "Besser als Mikrowelle"]
  ];

  K.register({
    id: "airfryer", name: "Airfryer", icon: "🔥",
    render: function (el) {
      el.innerHTML = '<div class="a-wrap"><input class="k-input a-search" placeholder="Suchen, z. B. Pommes" autocomplete="off">' +
        '<div class="k-muted a-note">Richtwerte – jedes Gerät heizt etwas anders. Korb nicht überfüllen, nach der Hälfte schütteln oder wenden.</div>' +
        '<div class="a-list"></div></div>';
      var input = el.querySelector(".a-search");
      function draw() {
        var q = input.value.trim().toLowerCase(), h = "", group = null;
        ROWS.filter(function (r) { return !q || r[1].toLowerCase().indexOf(q) >= 0; }).forEach(function (r) {
          if (r[0] !== group) { group = r[0]; h += '<div class="k-h2">' + esc(group) + "</div>"; }
          h += '<div class="a-row"><div class="a-name">' + esc(r[1]) + '<small>' + esc(r[4]) + "</small></div>" +
            '<div class="a-temp">' + esc(String(r[2])) + " °C</div><div class=\"a-time\">" + esc(r[3]) + " Min.</div></div>";
        });
        el.querySelector(".a-list").innerHTML = h || '<div class="k-muted">Nichts gefunden.</div>';
      }
      input.oninput = draw;
      draw();
    },
    css: [
      ".a-wrap { padding: 14px 24px; } .a-search { width: 100%; } .a-note { margin-top: 8px; }",
      ".a-row { display: flex; align-items: center; gap: 12px; background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 10px 16px; margin-bottom: 6px; }",
      ".a-name { flex: 1; display: flex; flex-direction: column; font-size: 19px; font-weight: 600; } .a-name small { font-size: 14px; font-weight: 400; color: var(--quiet); }",
      ".a-temp { font-size: 20px; font-weight: 700; color: var(--accent); min-width: 120px; text-align: right; }",
      ".a-time { font-size: 18px; min-width: 150px; text-align: right; font-variant-numeric: tabular-nums; }"
    ].join("\n")
  });
})();
