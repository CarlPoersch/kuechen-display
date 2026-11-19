# Hubert „Heute“: Startseite mit Live-Sport, News und Wetter

Stand: 19.11.2026 · Status: freigegeben, umgesetzt

## Absicht und Warum
Hubert wird von einer Kachel-Sammlung zur persönlichen Zentrale. Carl will **hinschauen und sofort Bescheid wissen**: Wie steht's bei Bayern, spielt ein Deutscher gerade Tennis, gibt es eine Eilmeldung, wie wird das Wetter, wann fährt der Bus. Läuft am Küchen-iPad (Wand, iPadOS 15) und auf dem iPhone, beide in der nativen Hülle „Hubert“.

## Ziele
- Neue Startseite **„Heute“** mit Widgets (Variante A), darunter Einstiege in die Bereiche.
- **Sport-Liveticker** (nur anzeigen, keine Töne, keine Push-Mitteilungen):
  - Fußball: alle Bayern-Spiele, Champions League komplett, weitere große Vereinswettbewerbe (Europa League, Conference League, DFB-Pokal), Spiele der deutschen Nationalmannschaft.
  - Tennis Herren: Turniere ab ATP 250 aufwärts (inkl. Grand Slams, Masters, ATP Finals). Gezeigt werden alle Matches mit deutscher Beteiligung **plus** alle Halbfinals und Finals, egal wer spielt.
  - Tennis Damen: Turniere ab WTA 250 aufwärts, **nur** Matches mit deutschen Spielerinnen (keine fremden Halbfinals/Finals).
- **News** nach Weg 1: Top-Meldungen seriöser Quellen, je eine Rubrik **Deutschland**, **Welt**, **KI**. Eilmeldungen oben und hervorgehoben.
- **Wetter Regensburg** und **nächster Bus** auf der Startseite (aus der geplanten Tagesinfo).
- Bestehende Bereiche (Küche, Fahrten, Timer) bleiben unverändert, nur eine Ebene tiefer.
- Funktioniert auf iPad (quer, Wand) und iPhone (hoch, Widgets untereinander).

## Nicht-Ziele
- Börse/Aktien (ausdrücklich gestrichen).
- Töne, Aufleuchten oder Push bei Toren/Satzgewinnen.
- KI-Bewertung der News-Brisanz (evtl. später).
- Smart Home.

## Anti-Ziele (Fehlschlag, auch wenn es technisch läuft)
- Startseite ist überladen oder man muss erst etwas antippen, um das Wichtigste zu sehen.
- Das iPad mini 4 wird träge (zu viele gleichzeitige Abrufe/Animationen).
- Leere oder kaputte Widgets, wenn eine Quelle ausfällt, statt eines ruhigen Hinweises.
- Boulevard- oder Klickköder-Meldungen in den News.

## Einschränkungen
- Safari 15 / iPadOS 15, iPad mini 4 mit wenig RAM → Vanilla-JS wie bisher (ES5-nah), sparsame Aktualisierung.
- Bestehende Architektur: `Launcher.register`, Hash-Routing, `Launcher.store` für Synchrones, `Launcher.storage(ns)` für Lokales.
- Hosting: GitHub Pages (statisch) + Supabase (Free Plan). Quellen ohne CORS laufen über eine Supabase Edge Function (Muster wie `efa`).
- Kostenlos, keine bezahlten APIs.

## Datenquellen (meine Wahl)
| Bereich | Quelle | Hinweis |
|---|---|---|
| Fußball, Tennis | ESPN-Scoreboard-JSON (`site.api.espn.com/apis/site/v2/sports/...`) | inoffiziell, kann sich ändern; Tennis liefert Nation der Spieler → Filter auf GER |
| Fußball-Ersatz | OpenLigaDB | falls ESPN ausfällt (Bundesliga/DFB-Pokal) |
| News DE/Welt | Tagesschau-API (`/api2u/news/?ressort=inland|ausland`, `/api2u/homepage/` mit Feld `breakingNews`) | offizielle, freie API |
| News KI | heise-RSS (Themenfeed KI) | RSS → JSON in der Edge Function |
| Wetter | Open-Meteo | kein Schlüssel, CORS erlaubt |
| Bus | bestehende `efa`-Funktion | wie Fahrten-App |

## Ansätze (erwogen)
1. **„Heute“-Startseite mit Widgets** – gewählt. Ein Blick genügt, passt zu „nur anzeigen“.
2. Kachel-Launcher mit neuen Apps – verworfen: jede Info braucht einen Tipp.
3. Tab-Leiste unten – im Kern wie 1; als optionale iPhone-Navigation denkbar.

Datenweg (meine Entscheidung): **eine neue Edge Function `feeds`** als Proxy mit fester Allowlist (ESPN, Tagesschau, heise), Schlüsselprüfung wie bei `efa`, Server-Cache (Live-Sport 20 s, News 2 min, Rest 10 min) und Normalisierung in ein schlankes JSON. Warum: CORS umgehen, iPad entlasten (kleine Antworten), Quellen später austauschbar ohne App-Änderung.

## Verhalten
**Startseite „Heute“ (Reihenfolge):**
1. Kopf: Uhrzeit, Datum, Wetter jetzt (Symbol, °C), Tageshöchst/-tiefst, nächster Bus (Linie, Minuten).
2. Live-Sport: zuerst laufende Spiele/Matches, dann heutige anstehende, dann gestrige Ergebnisse. Max. ~4 Einträge. Ist nichts relevant: ein Satz („Heute keine Spiele“) statt leerem Kasten.
3. News: Eilmeldung (falls vorhanden) farbig oben; darunter je Rubrik die 2–3 neuesten Top-Meldungen (Schlagzeile, Uhrzeit). Tipp öffnet den Artikel (in der Hülle → Safari).
4. Küche heute: geplantes Gericht, Anzahl offener Einkäufe, bald ablaufender Vorrat.
5. Einstiege: Küche, Sport, News, Fahrten, Timer.

**Bereich Sport:** Fußball- und Tennis-Ansicht mit allen relevanten Spielen von gestern bis +7 Tage, Live-Spiele mit Minute/Spielstand bzw. Satzständen.
**Bereich News:** drei Rubriken als Tabs, je ~15 Meldungen mit Teaser.

**Aktualisierung:** Nur solange Hubert sichtbar ist (`visibilitychange`). Sport alle 30 s, solange etwas live ist, sonst alle 10 min; News alle 5 min; Wetter alle 15 min; Bus wie bisher 60 s.

**Fehlerfall:** Widget zeigt den letzten bekannten Stand mit Zeitstempel („Stand 14:20“), nie einen Fehlertext.

**Layout:** iPad quer: zwei Spalten (Sport | News) wie Skizze. iPhone: eine Spalte, gleiche Reihenfolge.

## Vom Nutzer entschieden
- Börse raus; Sport: Bayern, CL komplett, große Vereinsturniere, Nationalmannschaft.
- Tennis: ATP ab 250 mit deutschen Spielern + alle Halbfinals/Finals; WTA ab 250 nur deutsche Spielerinnen.
- Sport nur anzeigen, keine Benachrichtigung.
- News Weg 1 (Top-/Eilmeldungen seriöser Quellen, Rubriken).
- Aufbau Variante A.

## Meine Entscheidungen (korrigierbar)
- Quellen wie in der Tabelle; Edge Function `feeds`.
- Rubriken Deutschland / Welt / KI; KI aus heise.
- Wetter- und Bus-Widget aus der Tagesinfo auf die Startseite übernommen; Countdowns (z. B. Wien-Trip) vorerst nicht dabei.
- Web-App heißt ab jetzt „Hubert“ (Titel, Startseite), Farben vorerst wie bisher.
- Europa League / Conference League: nur Spiele mit deutschen Vereinen (sonst ~36 Spiele je Spieltag). Champions League und DFB-Pokal komplett.
- Tennis: nur Einzel, kein Doppel.
- Startseite: Küche-Zeile und kompakte Kacheln unten nebeneinander, damit am iPad quer alles ohne Scrollen passt.

## Dem Entwickler überlassen
- Genaue ESPN-Liga-Kürzel und Normalisierungsformat.
- CSS-Details, Icons, Animationen (sparsam).
- Cache-Zeiten im Rahmen oben.
