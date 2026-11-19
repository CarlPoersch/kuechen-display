// ============================================================
// Launcher: das kleine "Betriebssystem" der Küchen-App.
// Aufgaben:
//   1. Unterapps registrieren und als Kacheln anzeigen
//   2. Navigation über die Adresse (#rezepte/biang-biang)
//   3. Gemeinsame Hilfen für alle Apps (Speicher, Aufräumen, Ton)
// Warum ein eigener Kern: Jede Unterapp kümmert sich nur um ihren
// Inhalt. Rahmen, Zurück-Knopf und Speicher gibt es einmal zentral.
// ============================================================
(function () {
  var apps = [];
  var current = null; // { app, cleanups: [] }
  var styled = {};    // welche App-CSS schon eingefügt wurde
  var homeHooks = []; // { show, hide } – z. B. die Widgets der "Heute"-Seite
  var homeVisible = false;

  // ---------- Speicher pro App ----------
  // Warum Namensraum (z. B. "rezepte:..."): Apps überschreiben sich nicht gegenseitig.
  // Warum try/catch: In manchen Fällen (z. B. privater Modus) wirft Safari hier Fehler.
  function storage(ns) {
    return {
      get: function (key, fallback) {
        try {
          var v = localStorage.getItem(ns + ":" + key);
          return v === null ? fallback : JSON.parse(v);
        } catch (e) { return fallback; }
      },
      set: function (key, value) {
        try { localStorage.setItem(ns + ":" + key, JSON.stringify(value)); } catch (e) {}
      },
      remove: function (key) {
        try { localStorage.removeItem(ns + ":" + key); } catch (e) {}
      }
    };
  }

  // ---------- Ton ----------
  // Warum so umständlich: Safari erlaubt Ton erst nach einem Tipp des Nutzers.
  // Deshalb wird der Audio-Kanal beim ersten Tipp irgendwo auf dem Bildschirm geöffnet.
  var audio = null;
  function unlockAudio() {
    if (!audio) {
      try { audio = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) {}
    }
    if (audio && audio.state === "suspended") audio.resume();
  }
  document.addEventListener("touchend", unlockAudio);
  document.addEventListener("click", unlockAudio);

  function beep() {
    if (!audio) return;
    try {
      var o = audio.createOscillator(), g = audio.createGain();
      o.frequency.value = 880; o.connect(g); g.connect(audio.destination);
      g.gain.setValueAtTime(0.4, audio.currentTime);
      g.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + 0.5);
      o.start(); o.stop(audio.currentTime + 0.5);
    } catch (e) {}
  }

  // Text sicher in HTML einsetzen (verhindert, dass < oder & das Layout zerschießen)
  function esc(s) {
    return String(s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }

  function $(id) { return document.getElementById(id); }

  // ---------- Navigation ----------
  // Die Adresse nach dem # bestimmt, was zu sehen ist:
  //   (leer)               → Startbildschirm
  //   #rezepte             → Unterapp "rezepte", Startseite der App
  //   #rezepte/biang-biang → Unterapp "rezepte", Unterseite "biang-biang"
  // Warum über die Adresse: Der Zurück-Weg funktioniert immer, und nach
  // einem Neuladen bist du an derselben Stelle.
  function parseHash() {
    var h = decodeURIComponent(location.hash.replace(/^#/, ""));
    var i = h.indexOf("/");
    return i < 0 ? { id: h, sub: "" } : { id: h.slice(0, i), sub: h.slice(i + 1) };
  }

  function findApp(id) {
    for (var i = 0; i < apps.length; i++) if (apps[i].id === id) return apps[i];
    return null;
  }

  function teardown() {
    if (!current) return;
    current.cleanups.forEach(function (fn) { try { fn(); } catch (e) {} });
    current = null;
    $("appcontent").innerHTML = "";
  }

  function route() {
    var r = parseHash();
    var app = findApp(r.id);
    teardown();

    if (!app) { // Startbildschirm
      $("appview").classList.remove("active");
      $("home").classList.add("active");
      setHomeVisible(true);
      return;
    }
    setHomeVisible(false);

    // App-eigenes CSS einmalig einfügen
    if (app.css && !styled[app.id]) {
      var st = document.createElement("style");
      st.textContent = app.css;
      document.head.appendChild(st);
      styled[app.id] = true;
    }

    $("home").classList.remove("active");
    $("appview").classList.add("active");
    $("apptitle").textContent = app.name;
    // Zurück-Knopf: von einer Unterseite zur App-Startseite, sonst zum Start
    $("back").textContent = r.sub ? "‹ " + app.name : "‹ Start";
    $("back").onclick = function () { navigate(r.sub ? app.id : ""); };

    current = { app: app, cleanups: [] };
    var ctx = {
      sub: r.sub,
      // Innerhalb der App navigieren: ctx.go("biang-biang") → #rezepte/biang-biang
      go: function (sub) { navigate(app.id + (sub ? "/" + sub : "")); },
      storage: storage(app.id),
      setTitle: function (t) { $("apptitle").textContent = t; },
      // Zurück-Knopf anpassen, z. B. vom Rezept zurück zur Rezeptliste statt zur App-Startseite
      setBack: function (label, sub) {
        $("back").textContent = "‹ " + label;
        $("back").onclick = function () { navigate(app.id + (sub ? "/" + sub : "")); };
      },
      // Warum: Was die App beim Verlassen stoppen muss (Intervalle, Abos), meldet sie hier an.
      onCleanup: function (fn) { if (current) current.cleanups.push(fn); }
    };
    app.mount($("appcontent"), ctx);
    $("appcontent").scrollTop = 0;
  }

  // Warum: Die Widgets sollen nur Daten laden, solange der Startbildschirm zu sehen ist.
  function setHomeVisible(v) {
    v = v && !document.hidden;
    if (v === homeVisible) return;
    homeVisible = v;
    homeHooks.forEach(function (h) { try { (v ? h.show : h.hide)(); } catch (e) { console.error(e); } });
  }
  document.addEventListener("visibilitychange", function () {
    setHomeVisible(!parseHash().id || !findApp(parseHash().id));
  });

  function navigate(path) {
    location.hash = path ? "#" + path : "#";
  }

  // ---------- Startbildschirm ----------
  function renderTiles() {
    var box = $("tiles");
    box.innerHTML = "";
    apps.forEach(function (app) {
      var b = document.createElement("button");
      b.className = "tile";
      b.style.background = app.color || "#8a7d72";
      b.innerHTML = '<span class="icon">' + esc(app.icon || "•") + "</span>" + esc(app.name);
      b.onclick = function () { navigate(app.id); };
      box.appendChild(b);
    });
  }

  var DAYS = ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"];
  var MONTHS = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"];
  function tickClock() {
    var d = new Date();
    var hh = d.getHours(), mm = d.getMinutes();
    $("time").textContent = hh + ":" + (mm < 10 ? "0" : "") + mm;
    $("date").textContent = DAYS[d.getDay()] + ", " + d.getDate() + ". " + MONTHS[d.getMonth()];
  }

  // ---------- Öffentliche Schnittstelle ----------
  window.Launcher = {
    // Jede Unterapp meldet sich hiermit an (siehe README.md)
    register: function (app) { apps.push(app); },
    // Startbildschirm-Bausteine: show() beim Erscheinen, hide() beim Verlassen
    onHome: function (hook) { homeHooks.push(hook); if (homeVisible) hook.show(); },
    navigate: navigate,
    storage: storage,
    beep: beep,
    esc: esc,
    start: function () {
      renderTiles();
      tickClock();
      setInterval(tickClock, 1000);
      window.addEventListener("hashchange", route);
      route();
    }
  };
})();
