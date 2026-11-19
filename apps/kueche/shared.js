// ============================================================
// Küche – gemeinsame Bausteine für alle Bereiche.
//
// Hier liegt alles, was mehrere Bereiche brauchen. Warum zentral:
// Rezepte, Wochenplan, Einkauf und Vorrat arbeiten mit denselben
// Daten. So ist z. B. "Was ist im Vorrat?" überall gleich beantwortet.
//
// Daten im gemeinsamen Speicher (Launcher.store, mit Server synchron):
//   shop:<id>     Einkaufsliste   {name, amount, recipe, done, created}
//   pantry:<id>   Vorrat          {name, place, mhd}
//   plan:<datum>  Wochenplan      [{id, portions}]
//   cooked:<id>   Gekocht         {count, last}
//   setting:<x>   Einstellungen
// Nur auf diesem Gerät (Launcher.storage("rezepte")):
//   Abhak-Stand im Rezept, Portionen, Filter
// ============================================================
(function () {
  var BASE = "apps/rezepte/data/";
  var cache = {};
  var S = function () { return Launcher.store; };
  var esc = function (s) { return Launcher.esc(s); };

  // ---------- Rezepte laden ----------
  function load(file) {
    if (cache[file]) return Promise.resolve(cache[file]);
    return fetch(BASE + file, { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (d) { cache[file] = d; return d; });
  }
  function loadIndex() {
    return load("index.json").then(function (items) {
      return Promise.all(items.map(function (it) { return typeof it === "string" ? load(it + ".json") : it; }));
    });
  }

  // ---------- Hilfen ----------
  function uid() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 7); }
  function pad(n) { return (n < 10 ? "0" : "") + n; }
  function isoDate(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
  function parseIso(s) { var p = s.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]); }
  function fmtDate(ts) { var d = new Date(ts); return d.getDate() + "." + (d.getMonth() + 1) + "." + d.getFullYear(); }
  var DAYS = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"];
  var DAYS_LONG = ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"];
  function daysUntil(iso) {
    var today = parseIso(isoDate(new Date()));
    return Math.round((parseIso(iso) - today) / 86400000);
  }

  // ---------- Mengen umrechnen (Portionsrechner) ----------
  var FRAC = { "½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1 / 3, "⅔": 2 / 3 };
  function parseNum(s) { return parseFloat(String(s).replace(",", ".")); }

  /** Zerlegt "1½ EL" -> {n: 1.5, rest: " EL"}; "1–2 Chilis" -> {n:1, n2:2, ...}; sonst null */
  function parseAmount(a) {
    var m = /^(\d+(?:[.,]\d+)?)?(?:\s*([½¼¾⅓⅔]))?(?:\s*[–-]\s*(\d+(?:[.,]\d+)?))?(.*)$/.exec(String(a || "").trim());
    if (!m || (!m[1] && !m[2])) return null;
    var n = (m[1] ? parseNum(m[1]) : 0) + (m[2] ? FRAC[m[2]] : 0);
    return { n: n, n2: m[3] ? parseNum(m[3]) : null, rest: m[4] };
  }

  /** Zahl hübsch formatieren: große Gramm-/ml-Werte runden, kleine als Bruch */
  function fmtNum(n, rest) {
    var unit = String(rest || "").trim().split(" ")[0];
    if ((unit === "g" || unit === "ml") && n >= 50) {
      return String(Math.round(n / (n >= 200 ? 10 : 5)) * (n >= 200 ? 10 : 5));
    }
    if (n >= 10) return String(Math.round(n));
    var q = Math.round(n * 4) / 4, whole = Math.floor(q), f = q - whole;
    var fs = f === 0.25 ? "¼" : f === 0.5 ? "½" : f === 0.75 ? "¾" : "";
    if (q === 0) return "¼";
    return (whole ? String(whole) : "") + fs;
  }

  function scaleAmount(amount, factor) {
    if (factor === 1) return amount;
    var p = parseAmount(amount);
    if (!p) return amount;
    var s = fmtNum(p.n * factor, p.rest);
    if (p.n2 != null) s += "–" + fmtNum(p.n2 * factor, p.rest);
    return s + p.rest;
  }

  // ---------- Zutaten erkennen ----------
  // Grundzutaten, die man (fast) immer hat: kommen nie auf die Einkaufsliste
  var BASICS = ["wasser", "salz", "pfeffer"];

  /** "Hähnchenbrust, gewürfelt" -> "hähnchenbrust"; "neutrales Öl" -> "öl" */
  function keyWord(name) {
    var s = String(name || "").toLowerCase()
      .replace(/\(.*?\)/g, " ")
      .split(",")[0]
      .replace(/[^a-zäöüß\s-]/g, " ")
      .trim();
    var words = s.split(/\s+/).filter(Boolean);
    return words.length ? words[words.length - 1] : s;
  }

  /** Passt eine Zutat zu einem Vorrat-Namen? Deutsche Komposita: das Hauptwort steht hinten
   *  ("Jasminreis" passt zu "Reis", "Reisessig" aber nicht). */
  function sameThing(a, b) {
    var x = keyWord(a), y = keyWord(b);
    if (!x || !y) return false;
    if (x === y) return true;
    // Einzahl/Mehrzahl: "Ei"/"Eier", "Tomate"/"Tomaten"
    var stem = function (w) { return w.replace(/(en|er|n|e|s)$/, ""); };
    if (stem(x) === stem(y) && stem(x).length >= 2) return true;
    if (y.length >= 3 && x.slice(-y.length) === y) return true;
    if (x.length >= 3 && y.slice(-x.length) === x) return true;
    if (y.length >= 5 && x.indexOf(y) === 0) return true; // "hähnchenbrust" ~ "hähnchen"
    if (x.length >= 5 && y.indexOf(x) === 0) return true;
    return false;
  }

  function isBasic(name) { return BASICS.indexOf(keyWord(name)) >= 0; }

  // ---------- Vorrat ----------
  function pantryItems() {
    // Kopie statt Original, damit "key" nicht im gespeicherten Eintrag landet
    return S().keys("pantry:").map(function (k) {
      var v = Object.assign({}, S().get(k)); v.key = k; return v;
    });
  }
  function inPantry(name) {
    if (isBasic(name)) return true;
    return pantryItems().some(function (p) { return sameThing(name, p.name); });
  }
  function addPantry(name, place, mhd) {
    var exists = pantryItems().filter(function (p) { return sameThing(name, p.name) && keyWord(p.name) === keyWord(name); })[0];
    if (exists) { // gleiches Lebensmittel: nur MHD aktualisieren, nicht doppelt anlegen
      if (mhd) { exists.mhd = mhd; var k = exists.key; delete exists.key; S().set(k, exists); }
      return;
    }
    S().set("pantry:" + uid(), { name: name, place: place || "Vorrat", mhd: mhd || "" });
  }

  // ---------- Einkaufsliste ----------
  function shopItems() {
    return S().keys("shop:").map(function (k) { var v = Object.assign({}, S().get(k)); v.key = k; return v; })
      .sort(function (a, b) { return a.created - b.created; });
  }

  /** Mengen addieren, wenn die Einheit gleich ist ("200 g" + "100 g" = "300 g"), sonst anhängen */
  function addAmounts(a, b) {
    if (!a) return b; if (!b) return a;
    var pa = parseAmount(a), pb = parseAmount(b);
    if (pa && pb && pa.n2 == null && pb.n2 == null && pa.rest.trim() === pb.rest.trim()) {
      return fmtNum(pa.n + pb.n, pa.rest) + pa.rest;
    }
    return a + " + " + b;
  }

  /**
   * Zutaten auf die Einkaufsliste setzen.
   * items: [{name, amount}], recipeTitle: Herkunft (wird angezeigt)
   * Rückgabe: {added, merged, skipped} – skipped = schon im Vorrat
   */
  function addToShopping(items, recipeTitle) {
    var open = shopItems().filter(function (i) { return !i.done; });
    var res = { added: 0, merged: 0, skipped: [] };
    items.forEach(function (it) {
      if (!it.name) return;
      if (inPantry(it.name)) { res.skipped.push(it.name); return; }
      var same = open.filter(function (o) { return keyWord(o.name) === keyWord(it.name); })[0];
      if (same) {
        same.amount = addAmounts(same.amount, it.amount);
        if (recipeTitle && (same.recipes || []).indexOf(recipeTitle) < 0) same.recipes = (same.recipes || []).concat(recipeTitle);
        var k = same.key; var copy = JSON.parse(JSON.stringify(same)); delete copy.key;
        S().set(k, copy);
        res.merged++;
      } else {
        var entry = { name: it.name, amount: it.amount || "", recipes: recipeTitle ? [recipeTitle] : [], done: false, created: Date.now() };
        var key = "shop:" + uid();
        S().set(key, entry);
        entry.key = key; open.push(entry);
        res.added++;
      }
    });
    return res;
  }

  // ---------- Wochenplan ----------
  function planFor(iso) { return S().get("plan:" + iso, []); }
  function addToPlan(iso, id, portions) {
    var list = planFor(iso).slice();
    list.push({ id: id, portions: portions });
    S().set("plan:" + iso, list);
  }

  // ---------- Gekocht ----------
  function cooked(id) { return S().get("cooked:" + id, null); }
  function markCooked(id) {
    var c = cooked(id) || { count: 0, last: 0 };
    c.count++; c.last = Date.now();
    S().set("cooked:" + id, c);
  }
  function unmarkCooked(id) { S().remove("cooked:" + id); }

  // Einmalige Übernahme der "Gekocht"-Liste aus der alten Rezepte-App (lag nur lokal)
  function migrate() {
    var old = Launcher.storage("rezepte").get("gekocht", null);
    if (old && !Launcher.storage("rezepte").get("migriert", false)) {
      Object.keys(old).forEach(function (id) { if (!cooked(id)) S().set("cooked:" + id, old[id]); });
      Launcher.storage("rezepte").set("migriert", true);
    }
  }

  // ---------- Bausteine für die Oberfläche ----------
  /** Kleines Overlay (Dialog). content = HTML, gibt das Box-Element zurück. */
  function dialog(host, html) {
    var ov = document.createElement("div");
    ov.className = "k-overlay";
    ov.innerHTML = '<div class="k-dialog">' + html + "</div>";
    ov.onclick = function (e) { if (e.target === ov) close(); };
    function close() { if (ov.parentNode) ov.parentNode.removeChild(ov); }
    host.appendChild(ov);
    var box = ov.firstChild;
    box.close = close;
    return box;
  }

  /** Kurze Meldung unten am Bildschirm */
  function toast(text) {
    // Nur eine Meldung gleichzeitig, sonst überlagern sie sich
    var old = document.querySelectorAll(".k-toast");
    for (var i = 0; i < old.length; i++) old[i].parentNode.removeChild(old[i]);
    var t = document.createElement("div");
    t.className = "k-toast";
    t.textContent = text;
    document.body.appendChild(t);
    setTimeout(function () { t.classList.add("show"); }, 10);
    setTimeout(function () { t.classList.remove("show"); setTimeout(function () { if (t.parentNode) t.parentNode.removeChild(t); }, 300); }, 2600);
  }

  /** Text in die Zwischenablage. Warum mit Umweg: navigator.clipboard gibt es nur
   *  über https, im Heimnetz läuft die App aber über http. */
  function copyText(text) {
    var ta = document.createElement("textarea");
    ta.value = text; ta.setAttribute("readonly", "");
    ta.style.position = "fixed"; ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select(); ta.setSelectionRange(0, text.length);
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(ta);
    return ok;
  }

  window.Kueche = {
    sections: [],
    // Ein Bereich meldet sich an: {id, name, icon, render(el, ctx, arg), css, badge()}
    register: function (sec) { this.sections.push(sec); },
    loadIndex: loadIndex, loadRecipe: function (id) { return load(id + ".json"); },
    uid: uid, isoDate: isoDate, parseIso: parseIso, fmtDate: fmtDate, daysUntil: daysUntil,
    DAYS: DAYS, DAYS_LONG: DAYS_LONG,
    parseAmount: parseAmount, scaleAmount: scaleAmount,
    keyWord: keyWord, sameThing: sameThing, isBasic: isBasic,
    pantryItems: pantryItems, inPantry: inPantry, addPantry: addPantry,
    shopItems: shopItems, addToShopping: addToShopping,
    planFor: planFor, addToPlan: addToPlan,
    cooked: cooked, markCooked: markCooked, unmarkCooked: unmarkCooked, migrate: migrate,
    dialog: dialog, toast: toast, copyText: copyText, esc: esc,
    local: function () { return Launcher.storage("rezepte"); }
  };
})();
