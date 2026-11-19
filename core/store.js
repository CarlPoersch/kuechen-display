// ============================================================
// Gemeinsamer Datenspeicher für alle Unterapps.
//
// - Liest und schreibt sofort lokal (localStorage), damit die App
//   auch ohne Verbindung funktioniert.
// - Gleicht sich im Hintergrund ab, entweder mit
//     Supabase (Cloud, siehe core/config.js) oder
//     server.py (lokal im Heimnetz, /api/store).
//   Warum: So sehen iPad und Handy dieselbe Einkaufsliste.
// - Jeder Eintrag hat einen Zeitstempel. Bei Konflikten gewinnt der
//   neuere ("last write wins"). Gelöschtes bleibt als {d:1} markiert,
//   damit andere Geräte die Löschung mitbekommen.
//
// Nutzung:
//   Launcher.store.set("shop:abc", {name: "Milch"})
//   Launcher.store.get("shop:abc")
//   Launcher.store.keys("shop:")       -> alle Schlüssel mit Präfix
//   Launcher.store.remove("shop:abc")
//   Launcher.store.subscribe(fn)       -> fn() bei jeder Änderung
// ============================================================
(function () {
  var LS_DATA = "core:store", LS_PENDING = "core:store-pending", LS_SINCE = "core:store-since", LS_KEY = "core:haushalt";
  var SYNC_MS = 5000; // alle 5 s abgleichen; es werden nur Änderungen übertragen
  var CFG = window.CONFIG || {};
  var cloud = !!CFG.supabaseUrl;

  function load(k, fb) {
    try { var v = localStorage.getItem(k); return v ? JSON.parse(v) : fb; } catch (e) { return fb; }
  }
  function save(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }
  function persist() { save(LS_DATA, data); save(LS_PENDING, pending); }

  var data = load(LS_DATA, {});        // alle Einträge {key: {v, t} oder {d:1, t}}
  var pending = load(LS_PENDING, {});  // lokal geändert, noch nicht abgeglichen
  var since = load(LS_SINCE, null);    // Server-Zeitpunkt des letzten Abgleichs (nur Cloud)
  var listeners = [];
  var online = null;                   // null = unbekannt, true/false nach Abgleich
  var keyWrong = false;
  var timer = null, syncing = false;

  function notify() {
    listeners.forEach(function (fn) { try { fn(); } catch (e) { console.warn(e); } });
  }

  function write(key, entry) {
    data[key] = entry;
    pending[key] = entry;
    persist();
    notify();
    scheduleSync(400);
  }

  function scheduleSync(ms) {
    clearTimeout(timer);
    timer = setTimeout(sync, ms);
  }

  // ---------- Haushalts-Schlüssel (nur Cloud) ----------
  // Warum: Die Seite ist öffentlich erreichbar. Nur wer den Schlüssel kennt,
  // kann die Daten lesen oder ändern. Er wird pro Gerät einmal eingegeben.
  function householdKey() { return load(LS_KEY, ""); }

  // ---------- Übertragung ----------
  /** Schickt Änderungen und holt neue. Antwort: {data: {...}, now: <Server-Zeitpunkt>} */
  function remote(changes) {
    if (cloud) {
      var headers = { "Content-Type": "application/json", apikey: CFG.supabaseKey };
      // Alte "anon"-Keys sind JWTs und gehören zusätzlich in Authorization,
      // neue "sb_publishable_..."-Keys nur in apikey.
      if (CFG.supabaseKey.indexOf("sb_") !== 0) headers.Authorization = "Bearer " + CFG.supabaseKey;
      return fetch(CFG.supabaseUrl + "/rest/v1/rpc/kueche_sync", {
        method: "POST", headers: headers, cache: "no-store",
        body: JSON.stringify({ p_key: householdKey(), p_changes: changes, p_since: since })
      }).then(function (r) {
        if (r.status === 401 || r.status === 403) { keyWrong = true; throw new Error("Schlüssel"); }
        if (!r.ok) throw new Error("HTTP " + r.status);
        keyWrong = false;
        return r.json();
      });
    }
    return fetch("/api/store", {
      method: "POST", headers: { "Content-Type": "application/json" }, cache: "no-store",
      body: JSON.stringify({ changes: changes })
    }).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    });
  }

  function sync() {
    if (cloud && !householdKey()) { showKeyDialog(); return; }
    if (syncing) { scheduleSync(1000); return; }
    syncing = true;
    var sent = pending;
    remote(sent).then(function (res) {
      // Nur die gesendeten Änderungen aus der Warteschlange nehmen.
      // Was während der Anfrage neu geändert wurde, bleibt für den nächsten Abgleich.
      Object.keys(sent).forEach(function (k) {
        if (pending[k] && pending[k].t === sent[k].t) delete pending[k];
      });
      // Neue Daten einmischen: neuerer Zeitstempel gewinnt
      var incoming = res.data || {}, changed = false;
      Object.keys(incoming).forEach(function (k) {
        var e = incoming[k];
        var cur = data[k];
        if (!cur || e.t > cur.t) { data[k] = e; changed = true; }
        // Gleicher Zeitstempel = derselbe Eintrag (der Server liefert die Felder nur in
        // anderer Reihenfolge). Kein Neuzeichnen, sonst würde die App alle 5 s flackern.
      });
      Object.keys(pending).forEach(function (k) { data[k] = pending[k]; });
      if (res.now) { since = res.now; save(LS_SINCE, since); }
      var wasOnline = online;
      online = true;
      persist();
      if (changed || wasOnline !== true) notify();
    }).catch(function () {
      var wasOnline = online;
      online = false;
      if (wasOnline !== false) notify();
      if (keyWrong) showKeyDialog(true);
    }).then(function () {
      syncing = false;
      if (!keyWrong) scheduleSync(SYNC_MS);
    });
  }

  // ---------- Eingabe des Haushalts-Schlüssels ----------
  var dialogOpen = false;
  function showKeyDialog(wrong) {
    if (dialogOpen) return;
    dialogOpen = true;
    var ov = document.createElement("div");
    ov.style.cssText = "position:fixed;left:0;right:0;top:0;bottom:0;background:rgba(43,36,32,.6);z-index:50;display:flex;align-items:center;justify-content:center";
    ov.innerHTML = '<form style="background:#fffdf9;border-radius:24px;padding:28px 32px;width:520px;max-width:92%">' +
      '<div style="font-size:26px;font-weight:700;margin-bottom:8px">🔑 Haushalts-Schlüssel</div>' +
      '<div style="color:#8a7d72;margin-bottom:16px">' + (wrong ? "Der Schlüssel stimmt nicht. Bitte nochmal eingeben." :
        "Einmal pro Gerät eingeben. Damit siehst du Einkaufsliste, Vorrat und Wochenplan.") + "</div>" +
      '<input autocomplete="off" autocapitalize="none" spellcheck="false" style="width:100%;font:inherit;font-size:20px;padding:12px 14px;border:1px solid #e6ddd2;border-radius:12px;-webkit-user-select:text;user-select:text" placeholder="kueche-....">' +
      '<div style="display:flex;gap:10px;margin-top:16px;justify-content:flex-end">' +
      '<button type="button" class="later">Später</button><button class="primary">Speichern</button></div></form>';
    document.body.appendChild(ov);
    var form = ov.firstChild, input = form.querySelector("input");
    function close() { dialogOpen = false; if (ov.parentNode) ov.parentNode.removeChild(ov); }
    form.querySelector(".later").onclick = close;
    form.onsubmit = function (ev) {
      ev.preventDefault();
      var v = input.value.trim();
      if (!v) return;
      save(LS_KEY, v);
      keyWrong = false;
      since = null; save(LS_SINCE, null); // mit neuem Schlüssel einmal alles holen
      close();
      scheduleSync(10);
    };
    setTimeout(function () { input.focus(); }, 50);
  }

  Launcher.store = {
    get: function (key, fallback) {
      var e = data[key];
      return e && !e.d ? e.v : fallback;
    },
    set: function (key, value) { write(key, { v: value, t: Date.now() }); },
    remove: function (key) { if (data[key] && !data[key].d) write(key, { d: 1, t: Date.now() }); },
    keys: function (prefix) {
      return Object.keys(data).filter(function (k) { return k.indexOf(prefix) === 0 && !data[k].d; });
    },
    subscribe: function (fn) {
      listeners.push(fn);
      return function () { listeners = listeners.filter(function (l) { return l !== fn; }); };
    },
    online: function () { return online; },
    householdKey: householdKey,
    askKey: function () { showKeyDialog(false); },
    sync: sync
  };

  // Beim Zurückkehren zur App (z. B. Handy entsperrt) sofort abgleichen
  document.addEventListener("visibilitychange", function () {
    if (!document.hidden) scheduleSync(100);
  });
  scheduleSync(50);
})();
