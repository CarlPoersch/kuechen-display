# Hubert als native Smart-App (SwiftUI)

Stand: 20.11.2026 · Status: Entwurf, wartet auf Freigabe

## Absicht und Warum
Hubert wird von Carls persönlicher Web-App zu einer **Smart-App für alle**, die weniger am Handy sein und trotzdem informiert sein wollen. Jede Person stellt sich Hubert aus **Buckets** selbst zusammen.

Carls Momente (Maßstab für alle Entscheidungen):
- **Morgens** 5 Minuten aufs iPad → gut informiert in den Tag.
- **Abends / bei der Arbeit** ein kurzer Blick: Was ist gerade los?
- **In der Küche** aktiv benutzen: Rezepte, Vorrat, Einkaufsliste.

Native statt Web, weil Hubert **auf iPhone und iPad jeweils passend** aussehen und sich anfühlen soll (Carls Begründung).

## Ziele
- Native **SwiftUI-App** für iPhone und iPad, Layout passt sich Gerät und Ausrichtung an.
- **Mit Apple anmelden**; Konten in Supabase.
- **Haushalte**: per Einladungscode teilen sich Mitglieder Küche-Daten und Haushalts-Tools; Persönliches bleibt pro Person.
- **Onboarding** beim ersten Start: Anmelden → Haushalt anlegen/beitreten → Interessen antippen → vorgeschlagene Buckets an-/abwählen → kurze Fragen pro Bucket (Stadt, Verein, Haltestelle …).
- **Bucket-System**: jederzeit hinzufügen, entfernen, sortieren, einstellen.
- Zwei Arten: **Glance** (anschauen; Tipp → Detail) und **Tool** (benutzen).
- Startseite: oben das **Briefing** (Glance-Buckets als festes Raster), darunter die **Tools** als App-Symbole.
- Apple-Look nach Skill `hubert-apple-look` / iOS-HIG, mit nativen Komponenten.
- Verteilung über **TestFlight**.

## Nicht-Ziele
- Android, Web-Version weiterentwickeln (bleibt nur als Übergang, bis die native App sie ersetzt).
- App-Store-Veröffentlichung in den ersten Etappen.
- Börse/Aktien, Push-Benachrichtigungen bei Sport (Carl: „nur anzeigen“).

## Anti-Ziele (Fehlschlag, auch wenn es läuft)
- Onboarding dauert länger als ~2 Minuten oder fragt Dinge, die man nicht versteht.
- Startseite wird zur Scroll-Wüste statt „ein Blick genügt“.
- Das iPad mini 4 ruckelt.
- Daten gehen beim Umstieg verloren (Rezepte, Vorrat, Gekocht-Liste).

## Einschränkungen
- **Mindestversion iOS/iPadOS 15** (Küchen-iPad mini 4). Damit: kein `NavigationStack`, kein Swift Charts, kein `@Observable` → `NavigationView`, `ObservableObject`, eigene Balken.
- **Claude kann nicht kompilieren.** Carl baut in Xcode. Deshalb kleine, einzeln baubare Schritte; Fehler kommen per Screenshot zurück.
- Supabase Free Plan; bestehendes Projekt `kuechen-display` wird weiterverwendet.
- Datenquellen: ESPN (inoffiziell), Tagesschau, heise, Open-Meteo, DWD/Bright Sky, EFA (nur Bayern). Neue Quellen je Bucket.
- TestFlight-Builds laufen nach 90 Tagen ab; externe Tester brauchen eine kurze Apple-Prüfung.

## Ansätze (erwogen)
- **A) Hybrid** (Web-App + native Hülle): schnell, alles wiederverwendbar, sofortige Updates – fühlt sich aber weniger nativ an.
- **B) Komplett native SwiftUI-App** – **gewählt**: maximal Apple-like, passt sich iPhone/iPad richtig an, Widgets möglich, offline-fähig. Preis: Neuaufbau (auch Küche), jede Änderung braucht einen Build.
- **C) Nur Web-App**: verworfen (iOS-15-Tastaturfehler, kein Health, kein Apple-Login).

## Architektur (Vorschlag, Claude entscheidet)
- **App:** SwiftUI, `ObservableObject`-Stores, Swift Concurrency. Paket `supabase-swift` (Auth, Datenbank, Edge Functions).
- **Bucket-Baustein** (ein Protokoll für alle):
  - `id`, `name`, `symbol`, `art` (glance/tool), `interessen` (für Vorschläge im Onboarding)
  - Einstellungen (Formular-Beschreibung → das Onboarding und die Einstellungen bauen sich daraus)
  - Glance-Ansicht in Größen **klein / mittel / groß**, Detailansicht, Lade-Logik mit Zwischenspeicher
  - Registry: neue Buckets = neue Datei + Eintrag.
- **Layout:** Briefing-Raster mit Spaltenanzahl je Breite (iPhone 1–2, iPad hoch 2, iPad quer 3); Bucket-Größe bestimmt die Spannweite. Sortieren im Bearbeiten-Modus (Liste mit Ziehgriffen; iOS-15-tauglich).
- **Daten (Supabase, mit Row Level Security):**
  - `profiles` (Nutzer), `households`, `household_members`, `invites` (Code)
  - `user_buckets` (Nutzer, Bucket-ID, Position, Größe, Einstellungen als JSON)
  - Haushalts-Daten: Einkauf, Vorrat, Wochenplan, Gekocht, Kasse, Notizen, Putz-/Haushalts-Tools
  - Persönliche Daten: Gewohnheiten, Medikamente, Ziele, Stimmung, Stundenplan
  - Lokaler Zwischenspeicher auf dem Gerät für Offline und schnellen Start.
- **Server:** bestehende Edge Function `feeds` wird erweitert (Login per Supabase-Token statt Haushalts-Schlüssel). Neue Quellen als weitere Abfragen dort.
- **Geräte-Daten** (Kalender, Health, Fotos) bleiben auf dem Gerät.
- **Nachtmodus** und „Display bleibt an“ wie heute, pro Gerät einstellbar.

## Bucket-Katalog
Glance = anschauen, Tool = benutzen. Etappe = wann gebaut.

| Bucket | Art | Quelle / Hinweis | Etappe |
|---|---|---|---|
| Wetter (+ Regenwarnung) | Glance | Open-Meteo + DWD-Messung | 2 |
| Termine | Glance | Gerätekalender | 2 |
| News (Themen wählbar) | Glance | Tagesschau, heise | 2 |
| Sport (Vereine, Ligen, Spieler) | Glance | ESPN | 2 |
| ÖPNV | Glance | EFA, zunächst nur Bayern | 2 |
| Countdowns | Glance | eigene Einträge | 2 |
| Küche (Rezepte, Plan, Einkauf, Vorrat, Airfryer) | Tool | Supabase, Haushalt | 2 |
| Timer | Tool | Gerät | 2 |
| Tagesbriefing (ein Satz) | Glance | aus anderen Buckets | 3 |
| Geburtstage | Glance | Kontakte | 3 |
| Zitat/Wort des Tages | Glance | eigene Liste | 3 |
| Notizen & Erinnerungen (Pinnwand) | Tool | Haushalt | 3 |
| Gewohnheiten | Tool | persönlich | 3 |
| WG-Putzplan | Tool | Haushalt | 3 |
| Müllabfuhr | Glance | je Stadt (ICS-Link) | 3 |
| #3 Sonnenauf-/-untergang, Tageslänge | Glance | berechnet | 3 |
| #4 Pollenflug & UV | Glance | DWD | 3 |
| #7 Lokalnachrichten | Glance | RSS je Stadt | 3 |
| #8 Tech-Releases | Glance | RSS | 3 |
| #13 Reise (Countdown, Wetter Ziel, Packliste) | Glance+Tool | eigene Einträge + Open-Meteo | 3 |
| #16 Tankpreise | Glance | Tankerkönig (freier Schlüssel) | 4 |
| #18 Pakete | Glance | Sendungsnummer selbst eintragen | 4 |
| #21 Haushaltskasse | Tool | Haushalt | 3 |
| #23 Stromverbrauch | Tool | Zählerstand eintragen | 4 |
| #26 Schritte & Aktivität | Glance | Apple Health | 4 |
| #27 Schlaf | Glance | Apple Health | 4 |
| #28 Medikamente | Tool | persönlich | 3 |
| #30 Stundenplan | Glance | eigene Einträge oder ICS | 3 |
| #31 Prüfungs-Countdown + Lernplan | Tool | persönlich | 3 |
| #32 Mensa | Glance | OpenMensa | 3 |
| #33 Fokus-Timer | Tool | Gerät | 3 |
| #34 Wochenziele | Tool | persönlich | 3 |
| #35 Events in der Nähe | Glance | je Stadt, wackelig | 5 |
| #38 Streaming-Neuheiten | Glance | inoffiziell, wackelig | 5 |
| #39 Kicktipp | Glance | Login + Auslesen, wackelig | 5 |
| #40 Buch/Serie Fortschritt | Tool | persönlich | 4 |
| #41 Foto des Tages | Glance | Fotomediathek / NASA | 4 |
| #43 Tagesfrage/Quiz | Glance | eigene Fragen, Punkte im Haushalt | 4 |
| #44 „Was koche ich heute?“ | Glance | Vorrat + Rezepte + Wetter | 3 |
| #46 Smart Home | Tool | je Gerät (HBN nur Tuya-Cloud) | 5 |
| #47 Gästemodus (WLAN-QR) | Tool | eigene Eingabe | 3 |
| #48 Ambient-Nacht (Uhr, Mond, Foto) | – | ersetzt den schwarzen Nachtmodus wahlweise | 4 |

## Etappen
1. **Fundament:** Xcode-Projekt neu aufsetzen, Apple-Login, Profile/Haushalte/Einladungen, Bucket-Protokoll + Registry, Startseite-Raster, Einstellungen, Onboarding (mit 1–2 Beispiel-Buckets).
2. **Umzug:** die heutigen Buckets nativ (Wetter, Termine, News, Sport inkl. Details, ÖPNV, Countdowns, Küche komplett, Timer). Daten aus `kueche_store` in den neuen Haushalt übernehmen. Danach ersetzt die App die Web-Version auf dem Küchen-iPad.
3. **Neue Buckets, Welle 1** (siehe Tabelle).
4. **Welle 2** (Health, Fotos, Pakete, Tankpreise …).
5. **Wackelige Quellen** (Events, Streaming, Kicktipp, Smart Home).

## Vom Nutzer entschieden
- Für alle, die weniger am Handy sein wollen; Carls drei Momente oben.
- Verteilung per TestFlight; Web-Hülle → richtige App.
- Konten mit **Mit Apple anmelden**, geteilt pro Haushalt, iPad und iPhone synchron.
- Bucket-Auswahl wie Tabelle (Basisliste + Nummern 3, 4, 7, 8, 13, 16, 18, 21, 23, 26, 27, 28, 30–35, 38–41, 43, 44, 46–48).
- **Native SwiftUI-App (B)**, angepasst an iPhone und iPad.

## Dem Entwickler überlassen
- Ordner- und Dateistruktur, Namensgebung, genaue Tabellen-Spalten.
- Konkrete Rastermaße, Animationen (sparsam).
- Cache-Zeiten pro Quelle.

## Küche – Funktionsauswahl (21.11.2026)

Carl hat aus dem Küchen-Brainstorm gewählt. Erst die einfach umsetzbaren, der Rest folgt, wenn die übrigen Buckets stehen.

**Runde 1 (jetzt):**
- Grundlage: Rezepte (bestehende Rezept-JSONs), Wochenplan, Einkaufsliste, Vorrat – geteilt im Haushalt; Daten aus `kueche_store` übernehmen (20 Vorrat, 4 Einkauf)
- 1 Kochmodus (große Schrift, Schritt für Schritt, Bildschirm bleibt an)
- 2 Timer im Rezept (Zeitangabe im Schritt antippen)
- 3 Portionen umrechnen
- 4 Airfryer-Umrechner – einfache Regel (Backofen → Airfryer: −20 °C, −20 % Zeit), anzeigen statt umschreiben
- 7 Bewertung und Notizen je Rezept
- 8 Kochverlauf („zuletzt gekocht“, Knopf „Gekocht“ im Kochmodus)
- 15 Einkaufsliste aus dem Wochenplan (ohne, was im Vorrat ist)
- 16 Einkaufsliste geteilt im Haushalt (Abgleich beim Öffnen und alle 15 s; Echtzeit später)
- 26 Bucket „Einkauf“ (offene Artikel, abhakbar)
- 28 Bucket „Rezept des Tages“

**Später (vorgemerkt):**
- 5 Rezept aus Foto
- 6 Rezept per Link teilen (Teilen-Erweiterung, eigenes Ziel in Xcode)
- 17 Siri / Kurzbefehl („Milch auf die Liste“)
- 21 Barcode scannen, auch Einkaufs-/Kassenzettel abscannen → Vorrat
- 29 Sprachsteuerung beim Kochen
- 30 KI-Rezept aus dem Vorrat
- 31 Nährwerte
- 32 Koch-Statistik (baut auf dem Kochverlauf auf)
- 33 Familien-Kochbuch (Rezepte zwischen Haushalten teilen)
