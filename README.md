# Küchen-Display

Startbildschirm mit Uhr und Kacheln. Jede Kachel ist eine Unterapp.

## Aufbau

```
index.html              Rahmen: Startbildschirm, App-Ansicht, Timer-Leiste
server.py               Webserver + Fahrplan-Weiterleitung + gemeinsamer Datenspeicher
daten/speicher.json     wird von server.py angelegt: Einkaufsliste, Vorrat, Wochenplan, Gekocht
core/
  base.css              gemeinsames Aussehen
  launcher.js           Kacheln, Navigation, Speicher pro Gerät, Ton
  timers.js             zentrale Timer (laufen app-übergreifend weiter)
  store.js              gemeinsamer Speicher, gleicht sich mit server.py ab (iPad <-> Handy)
apps/
  kueche/
    shared.js           gemeinsame Bausteine (Mengen umrechnen, Zutaten erkennen, Einkauf, Vorrat)
    kueche.js           Rahmen mit Navigation + Übersicht
    rezepte.js          Rezepte (Liste, Rezept, Portionsrechner, Gekocht)
    plan.js             Wochenplan
    einkauf.js          Einkaufsliste
    vorrat.js           Vorrat & Kühlschrank inkl. MHD und "Was kann ich kochen?"
    airfryer.js         Airfryer-Spickzettel
  rezepte/
    data/index.json     Liste aller Rezepte (Kurzinfo + Zutatennamen)
    data/<id>.json      ein Rezept pro Datei
    rezepte.js          alte Rezepte-App, wird nicht mehr geladen (kann gelöscht werden)
  fahrten/              Busabfahrten (wie das Bus-Display)
  timer/                Küchentimer
```

**Wie die Küche-Bereiche zusammenhängen:** Alle lesen und schreiben denselben Speicher.
Rezept → „Zutaten auf Einkaufsliste“ (überspringt, was im Vorrat ist) · Wochenplan →
„Zutaten der Woche“ · Einkauf abhaken → wandert in den Vorrat · Vorrat → „Was kann ich kochen?“.

**Handy:** Zu Hause im WLAN dieselbe Adresse öffnen (`http://<IP-des-Macs>:8000/#kueche/einkauf`),
dann siehst du dieselbe Einkaufsliste. Unterwegs: „Liste kopieren“ und z. B. in Notizen einfügen.

## Neue Unterapp hinzufügen

1. Ordner `apps/<name>/` anlegen, darin `<name>.js`:

```js
(function () {
  Launcher.register({
    id: "einkauf",          // steht in der Adresse: #einkauf
    name: "Einkauf",        // Text auf der Kachel
    icon: "🛒",
    color: "#2563eb",       // Kachelfarbe
    mount: function (el, ctx) {
      // el  = Bereich, in den die App zeichnet
      // ctx.sub        = Unterseite aus der Adresse (#einkauf/xyz → "xyz")
      // ctx.go("xyz")  = zu einer Unterseite wechseln
      // ctx.storage    = .get(key, fallback) / .set(key, wert), nur für diese App
      // ctx.setTitle() = Titel oben ändern
      // ctx.onCleanup(fn) = wird beim Verlassen der App ausgeführt
      el.innerHTML = "<p>Hallo aus der Einkaufs-App</p>";
    },
    css: ".meine-klasse { color: red; }"  // optional
  });
})();
```

2. In `index.html` unter den anderen Apps eine Zeile ergänzen:

```html
<script src="apps/einkauf/einkauf.js"></script>
```

Die Kachel erscheint automatisch auf dem Startbildschirm.

**Warum so:** Jede App ist eine eigene Datei und kennt nur `Launcher` und `ctx`.
Du kannst Apps hinzufügen oder entfernen, ohne die anderen anzufassen.

## Gemeinsame Dienste

- `Launcher.timers.start(key, label, sekunden)` startet einen Timer, der in der Leiste unten erscheint
- `Launcher.timers.get(key)`, `.cancel(key)`, `.subscribe(fn)` für Abfragen und Updates
- `Launcher.esc(text)` setzt Text sicher in HTML ein

## Neues Rezept

1. `apps/rezepte/data/<id>.json` nach dem Muster eines bestehenden Rezepts anlegen
   (Felder: id, title, icon, cuisine, servings, time, ingredients, steps)
2. In `apps/rezepte/data/index.json` einen Eintrag ergänzen, z. B.
   `{"id": "pad-thai", "title": "Pad Thai", "icon": "🍤", "cuisine": "Thailändisch", "servings": 2, "time": "ca. 30 Min."}`

Warum die Kurzinfo im Index: Die Liste lädt nur diese eine Datei statt jedes Rezept einzeln.
Ein Eintrag, der nur aus der ID besteht (`"pad-thai"`), funktioniert auch, lädt aber langsamer.
Neue Küchen erscheinen automatisch als Filter.

Schritte mit `"minutes": 10` bekommen automatisch einen Timer-Knopf.

## Betrieb

**Cloud (Standard):** Die Seite liegt auf GitHub Pages, die Daten in Supabase
(Projekt `kuechen-display`). Einstellungen in `core/config.js`.

- Daten: Tabelle `kueche_store`, Zugriff nur über die Funktion `kueche_sync`
  mit Haushalts-Schlüssel (`supabase/migrations/001_kueche_store.sql`).
- Fahrplan: Edge Function `efa` (`supabase/functions/efa/index.ts`), reicht die
  Abfragen an die Bayern-Fahrplanauskunft weiter (wegen CORS nötig).
- Der Haushalts-Schlüssel steht NICHT im Code. Er wird auf jedem Gerät einmal
  eingegeben. In der Datenbank liegt nur sein Hash.

**Lokal (zum Ausprobieren):** In `core/config.js` `supabaseUrl` leer lassen und

```
python3 server.py
```

starten. Dann kommen Daten und Fahrplan über `server.py`.

## Rezepte erzeugen

Die Rezepte stehen kompakt in `tools/rezepte/data_*.py`. Neu erzeugen mit:

```
cd tools/rezepte && python3 gen.py ../../apps/rezepte/data
```


## Hubert „Heute“ (seit 19.11.2026)
- Startseite = `apps/heute/heute.js` (+ `heute.css`): Uhr, Wetter (Open-Meteo), nächster Bus (EFA), Sport, News, Küche.
- Gemeinsame Datenquelle: `apps/heute/feeds.js` (`Hubert.Feeds`), merkt sich den letzten Stand im Browser.
- Bereiche: `apps/sport/sport.js`, `apps/news/news.js`.
- Supabase-Funktion `supabase/functions/feeds`: holt ESPN (Sport), Tagesschau und heise (News), dampft ein, prüft den Haushalts-Schlüssel.
- Design: `docs/specs/2026-11-19-hubert-heute-design.md`.

## iOS-App „Hubert“ (`ios/Hubert`)
Schlanke Hülle (WKWebView) um die Web-App, weil im iOS-15-Homescreen-Modus die Tastatur nicht aufgeht.
- `KuecheApp.swift`: App-Start, Display bleibt an.
- `WebView.swift`: lädt die GitHub-Pages-Seite, Offline-Seite, Ziehen zum Neuladen.
- `CalendarBridge.swift`: liest die Termine aus dem Gerätekalender → `HubertNative.setCalendar(...)`.
- `NightMode.swift`: 23–6 Uhr schwarz + Helligkeit 0, Antippen zeigt Hubert 30 s.
Bauen: `ios/Hubert/Hubert.xcodeproj` in Xcode öffnen, iPad wählen, ▶︎.
