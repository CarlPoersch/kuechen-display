// ============================================================
// Timer-Dienst: gemeinsam für alle Unterapps.
// Warum zentral statt in jeder App: Ein Timer läuft weiter, auch wenn
// du die App verlässt oder auf den Startbildschirm gehst. Die Leiste
// unten zeigt ihn überall an.
// Warum Endzeitpunkte statt Herunterzählen: bleibt genau, auch wenn
// Safari kurz pausiert oder die Seite neu lädt.
// ============================================================
(function () {
  var store = Launcher.storage("core");
  var timers = store.get("timers", []); // [{ key, label, end, ringing }]
  var listeners = [];

  function save() { store.set("timers", timers); }
  function find(key) {
    for (var i = 0; i < timers.length; i++) if (timers[i].key === key) return timers[i];
    return null;
  }
  function notify() {
    listeners.forEach(function (fn) { try { fn(); } catch (e) {} });
    renderBar();
  }

  function fmt(sec) {
    var m = Math.floor(sec / 60), s = sec % 60;
    return m + ":" + (s < 10 ? "0" : "") + s;
  }

  var Timers = {
    // key: eindeutiger Name, z. B. "rezepte/biang-biang/2" – so findet die App ihren Timer wieder
    start: function (key, label, seconds) {
      Timers.cancel(key);
      timers.push({ key: key, label: label, end: Date.now() + seconds * 1000, ringing: false });
      save(); notify();
    },
    cancel: function (key) {
      timers = timers.filter(function (t) { return t.key !== key; });
      save(); notify();
    },
    get: function (key) { return find(key); },
    all: function () { return timers.slice(); },
    // Restzeit in Sekunden (0 = abgelaufen)
    left: function (t) { return Math.max(0, Math.ceil((t.end - Date.now()) / 1000)); },
    fmt: fmt,
    // Apps können sich über Änderungen informieren lassen; Rückgabe = Abmelden
    subscribe: function (fn) {
      listeners.push(fn);
      return function () { listeners = listeners.filter(function (l) { return l !== fn; }); };
    }
  };

  // Timer-Leiste unten am Bildschirm
  var barSig = null;
  function renderBar() {
    var bar = document.getElementById("timerbar");
    if (!bar) return;
    document.body.classList.toggle("has-timers", timers.length > 0);
    // Warum nur bei Änderung neu bauen: Würden die Knöpfe 4× pro Sekunde
    // ersetzt, ginge ein Tipp manchmal ins Leere. Sonst nur die Zeit aktualisieren.
    var sig = timers.map(function (t) { return t.key + (t.ringing ? "!" : ""); }).join("|");
    if (sig === barSig) {
      var bs = bar.querySelectorAll("b");
      timers.forEach(function (t, i) {
        if (bs[i] && !t.ringing) bs[i].textContent = fmt(Timers.left(t));
      });
      return;
    }
    barSig = sig;
    bar.innerHTML = "";
    timers.forEach(function (t) {
      var b = document.createElement("button");
      b.className = "chip" + (t.ringing ? " ringing" : "");
      b.innerHTML = Launcher.esc(t.label) + "<b>" + (t.ringing ? "⏰ Stopp" : fmt(Timers.left(t))) + "</b>";
      // Tippen: klingelnden Timer ausschalten, laufenden abbrechen
      b.onclick = function () { Timers.cancel(t.key); };
      bar.appendChild(b);
    });
  }

  // Taktgeber: prüft 4× pro Sekunde, ob ein Timer abgelaufen ist
  var lastBeep = 0;
  setInterval(function () {
    if (!timers.length) return;
    var changed = false, anyRinging = false;
    timers.forEach(function (t) {
      if (!t.ringing && Timers.left(t) === 0) { t.ringing = true; changed = true; }
      if (t.ringing) anyRinging = true;
    });
    if (changed) save();
    if (anyRinging && Date.now() - lastBeep > 1500) { Launcher.beep(); lastBeep = Date.now(); }
    notify(); // aktualisiert Restzeiten in Leiste und Apps
  }, 250);

  window.Launcher.timers = Timers;
  document.addEventListener("DOMContentLoaded", renderBar);
  if (document.readyState !== "loading") renderBar();
})();
