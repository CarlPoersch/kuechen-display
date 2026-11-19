// ============================================================
// Fahrplan-Logik (ohne Anzeige) – übernommen aus der Bus-Display-
// Firmware (transit.cpp / config.h), damit beide gleich rechnen.
// Liegt in einer eigenen Datei, damit Logik und Darstellung
// getrennt bleiben und sich einzeln testen lassen.
// ============================================================
(function (global) {
  // ---------- Einstellungen (entspricht config.h) ----------
  var CFG = {
    // Wohin die Abfragen gehen (wegen CORS immer über einen Vermittler):
    // Cloud: Supabase Edge Function "efa", lokal: server.py unter "/efa/"
    apiBase: (window.CONFIG && CONFIG.supabaseUrl) ? CONFIG.supabaseUrl + "/functions/v1/efa/" : "/efa/",
    hbfStopId: "80001083", // Regensburg Hbf
    // Liebermannweg 1, 93051 Regensburg. EFA erwartet Längengrad vor Breitengrad.
    philippDestination: "12.073809%3A49.010014%3AWGS84%5Bdd.ddddd%5D%3ALiebermannweg%201",
    // walkMinutes: Fußweg von zu Hause (Fort-Skelly-Straße 23) inkl. 1 min Puffer
    stops: [
      { id: "4014010", title: "Franz-Mayer-Straße", walkMinutes: 3 },
      { id: "4014003", title: "An der Iselrinne", walkMinutes: 8 },
      { id: "4014030", title: "TechCampus/OTH", walkMinutes: 11 }
    ],
    // Linien zum Hbf (Startwerte): Netz:Linie:Richtung -> Fahrzeit in min
    routeSeeds: [
      [2, "rvv:11005:H", 3], [2, "rvv:11006:R", 4], [2, "rvv:110C6:R", 4],
      [2, "gfn:12019:H", 3], [2, "gfn:12020:H", 3], [2, "gfn:12021:H", 2],
      [2, "gfn:12214:H", 2], [2, "gfn:12038:R", 2],
      [0, "rvv:11005:H", 5],
      [1, "rvv:11003:H", 6], [1, "gfn:12020:H", 11]
    ],
    learnIntervalMs: 6 * 3600 * 1000 // Linien alle 6 Stunden neu lernen
  };

  // ---------- Hilfen ----------
  function num(v) { return typeof v === "string" ? parseInt(v, 10) : (v | 0); }

  /** EFA-dateTime {year, month, day, hour, minute} -> Date (oder null) */
  function efaTime(dt) {
    if (!dt || dt.year == null) return null;
    return new Date(num(dt.year), num(dt.month) - 1, num(dt.day), num(dt.hour), num(dt.minute));
  }

  /** Zeitpunkt eines Verbindungs-Punkts: {date, time} in verschiedenen Formaten */
  function tripPointTime(v) {
    if (!v) return null;
    if (v.year != null) return efaTime(v);
    var date = v.date || "", clock = v.time || "", y, mo, d, h, mi, m;
    if ((m = /^(\d{4})-(\d{1,2})-(\d{1,2})/.exec(date))) { y = +m[1]; mo = +m[2]; d = +m[3]; }
    else if ((m = /^(\d{1,2})\.(\d{1,2})\.(\d{4})/.exec(date))) { d = +m[1]; mo = +m[2]; y = +m[3]; }
    else if ((m = /^(\d{4})(\d{2})(\d{2})$/.exec(date))) { y = +m[1]; mo = +m[2]; d = +m[3]; }
    else return null;
    if ((m = /^(\d{1,2}):(\d{2})/.exec(clock))) { h = +m[1]; mi = +m[2]; }
    else if ((m = /^(\d{2})(\d{2})$/.exec(clock))) { h = +m[1]; mi = +m[2]; }
    else return null;
    if (y < 2020 || mo < 1 || mo > 12 || h > 23 || mi > 59) return null;
    return new Date(y, mo - 1, d, h, mi);
  }

  function hhmmToMinutes(s) {
    if (!s || s.length < 5) return -1;
    return parseInt(s, 10) * 60 + parseInt(s.slice(3), 10);
  }

  function pad(n) { return (n < 10 ? "0" : "") + n; }

  /** Abschnitt mit echtem Fahrzeug? (Fußwege haben hohe MOT-Codes und keine Liniennummer) */
  function tripHasLine(leg) {
    var mode = leg && leg.mode || {};
    if (mode.motType != null && num(mode.motType) >= 97) return false;
    return /\d/.test(mode.number || "");
  }

  function getJson(url) {
    var opts = { cache: "no-store" };
    // In der Cloud prüft die Edge Function den Haushalts-Schlüssel,
    // damit Fremde den Fahrplan-Vermittler nicht nutzen können.
    if (window.CONFIG && CONFIG.supabaseUrl) {
      opts.headers = { "x-kueche-key": Launcher.store.householdKey() };
    }
    return fetch(url, opts).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    });
  }

  // ---------- Gelernte Routen ----------
  // routes["<stopIndex>|<key>"] = Fahrzeit in Minuten
  function seedRoutes() {
    var r = {};
    CFG.routeSeeds.forEach(function (s) { r[s[0] + "|" + s[1]] = s[2]; });
    return r;
  }

  /** Lernt per Verbindungsabfrage, welche Linien direkt zum Hbf fahren. */
  function learnRoutes(stopIndex, routes) {
    var url = CFG.apiBase + "XML_TRIP_REQUEST2?outputFormat=JSON&type_origin=stop&name_origin=" +
      CFG.stops[stopIndex].id + "&type_destination=stop&name_destination=" + CFG.hbfStopId +
      "&calcNumberOfTrips=10&maxChanges=0&useRealtime=0";
    return getJson(url).then(function (doc) {
      (doc.trips || []).forEach(function (trip) {
        var bus = null, busLegs = 0;
        (trip.legs || []).forEach(function (l) { if (l.mode && l.mode.diva) { bus = l; busLegs++; } });
        if (busLegs !== 1) return;
        var diva = bus.mode.diva;
        if (!diva.network || !diva.line) return;
        var key = diva.network + ":" + diva.line + ":" + (diva.dir || "");
        var dep = hhmmToMinutes(bus.points[0].dateTime && bus.points[0].dateTime.time);
        var arr = hhmmToMinutes(bus.points[1].dateTime && bus.points[1].dateTime.time);
        if (dep < 0 || arr < 0) return;
        var minutes = arr - dep;
        if (minutes < 0) minutes += 24 * 60; // über Mitternacht
        routes[stopIndex + "|" + key] = minutes;
      });
    });
  }

  // ---------- Abfahrtstafel (Ziel Hbf) ----------
  function loadDepartures(stopIndex, routes) {
    var url = CFG.apiBase + "XML_DM_REQUEST?outputFormat=JSON&mode=direct&type_dm=stop&name_dm=" +
      CFG.stops[stopIndex].id + "&useRealtime=1&limit=40";
    return getJson(url).then(function (doc) {
      var deps = [];
      (doc.departureList || []).forEach(function (d) {
        var sl = d.servingLine || {}, proj = sl.liErgRiProj || {};
        if (!proj.network || !proj.line) return; // nicht zuordenbar
        var key = proj.network + ":" + proj.line + ":" + (proj.direction || "");
        var travel = routes[stopIndex + "|" + key];
        if (travel == null) return; // fährt nicht zum Hbf
        var planned = efaTime(d.dateTime);
        var realtime = !!d.realDateTime;
        var actual = realtime ? efaTime(d.realDateTime) : planned;
        if (!actual) return;
        deps.push({
          line: sl.number || "?", dest: sl.direction || "",
          planned: planned, actual: actual, realtime: realtime,
          arrival: new Date(actual.getTime() + travel * 60000),
          walkStart: null, transfer: null
        });
      });
      deps.sort(function (a, b) { return a.actual - b.actual; });
      return deps;
    });
  }

  // ---------- Verbindungsabfrage (Ziel Philipp, höchstens ein Umstieg) ----------
  function loadTrips(stopIndex, trips) {
    var stop = CFG.stops[stopIndex];
    var earliest = new Date(Date.now() + stop.walkMinutes * 60000);
    var dt = "&itdDate=" + earliest.getFullYear() + pad(earliest.getMonth() + 1) + pad(earliest.getDate()) +
      "&itdTime=" + pad(earliest.getHours()) + pad(earliest.getMinutes());
    var url = CFG.apiBase + "XML_TRIP_REQUEST2?outputFormat=JSON&locationServerActive=1&stateless=1" +
      "&type_origin=stop&name_origin=" + stop.id +
      "&type_destination=coord&name_destination=" + CFG.philippDestination +
      "&itdTripDateTimeDepArr=dep&calcOneDirection=1&ptOptionsActive=1&maxChanges=1&useRealtime=1" +
      dt + "&calcNumberOfTrips=" + (trips || 8);

    return getJson(url).then(function (doc) {
      var out = [];
      (doc.trips || []).forEach(function (trip) {
        var legs = trip.legs || [], bus = null, conn = null, tooMany = false;
        legs.forEach(function (leg) {
          if (tooMany || !tripHasLine(leg)) return;
          if (!bus) bus = leg; else if (!conn) conn = leg; else tooMany = true;
        });
        if (!bus || tooMany) return;

        var boarding = bus.points[0];
        var arrivalPt = legs[legs.length - 1].points[1];
        var departure = tripPointTime(boarding.dateTime);
        var predicted = tripPointTime(boarding.realDateTime);
        var plannedDep = tripPointTime(boarding.dateTimeTarget);
        var actual = predicted || departure;
        var arrival = tripPointTime(arrivalPt.realDateTime) || tripPointTime(arrivalPt.dateTime);
        if (!actual || !arrival || arrival < actual || arrival - actual > 4 * 3600000) return;

        var transfer = null;
        if (conn) {
          var tin = tripPointTime(bus.points[1].realDateTime) || tripPointTime(bus.points[1].dateTime);
          var tout = tripPointTime(conn.points[0].realDateTime) || tripPointTime(conn.points[0].dateTime);
          if (!tin || !tout || tin < actual || tout < tin || tout > arrival) return;
          transfer = { line: conn.mode.number || "?", stop: conn.points[0].name || "", tin: tin, tout: tout };
        }

        // Verbindung beginnt mit Fußweg = Einstieg an einer ANDEREN Haltestelle -> weglassen
        if (!tripHasLine(legs[0])) return;
        if (actual < earliest - 30000) return; // nicht mehr erreichbar

        // Doppelte Verbindungen (z. B. anderer Fußweg am Ende) nur einmal
        var dup = out.some(function (o) {
          return +o.actual === +actual && +o.arrival === +arrival && o.line === (bus.mode.number || "?") &&
            (o.transfer ? o.transfer.line + +o.transfer.tout : "") === (transfer ? transfer.line + +transfer.tout : "");
        });
        if (dup) return;

        out.push({
          line: bus.mode.number || "?", dest: bus.points[1].name || "",
          planned: plannedDep || departure, actual: actual,
          realtime: !!(predicted || plannedDep),
          arrival: arrival, walkStart: null, transfer: transfer
        });
      });
      out.sort(function (a, b) { return a.actual - b.actual; });
      return out;
    }, function (err) {
      // Firmware-Verhalten: Große Antwort abgebrochen -> mit 4 Verbindungen erneut versuchen
      if (!trips) return loadTrips(stopIndex, 4);
      throw err;
    });
  }

  global.EFA = {
    CFG: CFG,
    seedRoutes: seedRoutes,
    learnRoutes: learnRoutes,
    loadDepartures: loadDepartures,
    loadTrips: loadTrips
  };
})(window);
