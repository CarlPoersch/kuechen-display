# Sport: Spielseite wie bei Flashscore – Design

Stand: 28.11.2026 · Status: freigegeben (Carl, 28.11.)

## 1. Absicht und Warum
Carl möchte im Sport-Bucket pro Fußballspiel auf einen Blick alles sehen, was Flashscore zeigt: Aufstellung, Tabelle, Statistik, Verlauf. Hubert soll dafür keine Sport-App auf dem Handy mehr nötig machen – passend zu Huberts Idee „weniger am Handy, trotzdem informiert“. Maßstab sind Carls drei Momente: morgens kurz schauen, nebenbei „was ist gerade los?“, und am Wand-iPad ein Spiel nebenher verfolgen.

Ausgewählt aus dem Brainstorming (28.11.): Spielseite mit Reitern (2), Ereignis-Zeitleiste (3), Statistik-Balken (6), Tabelle mit Hervorhebung (7), Form-Reihe (9), Aufstellung als Spielfeld (4) mit Bank (5). Tabelle zusätzlich in der Sport-App (Carl: Variante B).

## 2. Ist-Zustand
- `Buckets/SportBucket.swift` → `MatchDetailView`: nur für Fußball (`sport == "fb"`) mit Reitern **Ticker · Statistik · Aufstellung**. Ticker = einfache Liste, Statistik = Zahlen links/rechts, Aufstellung = Namensliste + Bank als Fließtext. Dazu Stadion, Schiedsrichter, Halbzeitstand.
- Daten: Edge Function `feeds` → `match(lg, id)` holt ESPN `soccer/<lg>/summary?event=<id>` (20 s Cache) und formt `MatchDetail` (Swift: `Core/Feeds.swift`).
- `SportDetail` (die Sport-App): Liste Live · Meine Favoriten · Demnächst (nach Tagen) · Ergebnisse, oben Sportart-Kapseln.
- Liga-Katalog und Spiele: Edge Function `sport` (Abfragen `catalog`, `search`, `teams`, `feed`).
- Tabellen und Form gibt es noch nirgends.

## 3. Ziele
1. **Spielseite** für Fußball mit Reitern **Ticker · Aufstellung · Statistik · Tabelle**. Reiter ohne Daten werden nicht gezeigt.
2. **Spielkopf** zeigt zusätzlich die **Form** beider Teams (letzte 5 Spiele im selben Wettbewerb, S/U/N) und den Tabellenplatz – immer aus dem **Wettbewerb des Spiels**. Hat der Wettbewerb eine Tabelle (Liga, Ligaphase der Champions/Europa/Conference League, Gruppen bei WM, EM, Nations League, Qualifikation), sind Form, Platz und Reiter „Tabelle“ dabei. Hat er keine (DFB-Pokal, K.-o.-Runden), fällt der Zusatz weg – es wird **nicht** auf die heimische Liga ausgewichen (Carl, 28.11.).
3. **Ticker als zweiseitige Zeitleiste:** Minute in der Mitte, Heim-Ereignisse links, Gast-Ereignisse rechts (Tor, Elfmeter, Eigentor, Gelb, Gelb-Rot/Rot, Wechsel). Neueste oben.
4. **Aufstellung als Spielfeld:** grüner Rasen, beide Teams auf einem Feld (Heim unten, Gast oben), Spieler als Kreis mit Rückennummer und Nachname. Am Spieler kleine Zeichen für Tor (⚽︎, bei mehreren mit Zahl), Karte und Auswechslung mit Minute. Darunter (iPad: daneben) **Bank** je Team; eingewechselte Spieler mit Minute. Formation steht über jeder Hälfte.
5. **Statistik-Balken:** je Zeile Wert links, Bezeichnung, Wert rechts; darunter zwei Balken, die zur Mitte hin wachsen. Die höhere Seite in Hubert-Orange, die andere grau.
6. **Tabelle** im Reiter: ganze Tabelle der Liga (bei Gruppen: die Gruppe mit den beiden Teams), beide Teams des Spiels hervorgehoben, Zonen (Champions League, Europa League, Conference League, Relegation, Abstieg …) als farbiger Strich am Platz und Legende darunter.
7. **Sport-App:** oben Umschalter **Spiele · Tabellen**. „Tabellen“ zeigt für jede gefolgte Fußball-Liga, die eine Tabelle hat, die Tabelle mit Form; Liga-Wahl über Kapseln wie bei den Sportarten. Lieblingsteams sind hervorgehoben.
8. Alles für **iPhone und iPad** ausgerichtet (Regel vom 24.11.).

## 4. Nicht-Ziele (diesmal nicht)
- Andere Sportarten (NBA, NFL, Eishockey, Tennis, F1) – ihre Detailseite bleibt wie sie ist.
- Live-Tabelle, Direktvergleich, Team-Seite (Tipp aufs Wappen), Torschützenliste, Vorschau-Karte, Widget „Tabelle Mini“, TV-Hinweis, Spieltag-Modus, Tor-Licht, Kicktipp – vorgemerkt für später.
- Tabellen für reine Pokale (DFB-Pokal) – dort gibt es keine Tabelle; der Reiter fehlt dann einfach.
- Push-Mitteilungen (Grundsatz „nur anzeigen“).
- Wappen/Spielerfotos als Bilder (ESPN liefert Wappen-URLs; kann später kommen, siehe Abschnitt 9).

## 5. Anti-Ziele (wäre ein Fehlschlag, auch wenn es läuft)
- Eine **falsche Tabelle** (falsche Reihenfolge, fehlende Punktabzüge). Deshalb kommt die Tabelle von ESPN und wird nicht selbst berechnet.
- **Leere Reiter oder leere Flächen** („Keine Daten“ als Standard). Was fehlt, wird nicht angeboten.
- Ein Spielfeld, auf dem Spieler **falsch stehen oder sich überlappen**. Dann lieber die Liste.
- Abgeschnittene Namen und Zahlen auf dem iPhone, Ruckeln beim Wischen.

## 6. Einschränkungen
- Mindestversion **iOS 15**: kein Swift Charts, kein `NavigationStack`, kein `@Observable`; Balken und Spielfeld selbst zeichnen.
- **ESPN ist inoffiziell** und liefert je Liga unterschiedlich viel. Jede Angabe ist optional.
- Claude erreicht ESPN aus seiner Umgebung nicht. Welche Felder es wirklich gibt, wird im ersten Umsetzungsschritt über eine Diagnose-Ausgabe der Edge Function geprüft (Carl ruft sie einmal auf oder Claude über die Supabase-Logs).
- Supabase Free Plan: Abfragen sparsam, deshalb Server-Cache.
- Apple-Look nach Skill `hubert-apple-look`; Rot nur für Live/Eilmeldungen.

## 7. Ansätze (Datenquelle für Tabelle und Form)
1. **Neue Abfrage `sport/table` in der Funktion `sport`** – Tabelle aus ESPNs Tabellen-Schnittstelle (inkl. Zonen), Form vom Server aus allen Saisonspielen der Liga berechnet. Eine Quelle für Spielseite und Sport-App. *Nachteil:* zwei ESPN-Abfragen.
2. Tabelle aus der Spielabfrage, Sport-App getrennt – zwei Quellen, die sich widersprechen können, Form fehlt in der App. Verworfen.
3. Tabelle selbst aus den Spielen berechnen – ermöglicht später die Live-Tabelle, aber Gleichstand-Regeln je Liga und Punktabzüge machen falsche Tabellen wahrscheinlich (Anti-Ziel). Verworfen.

**Gewählt: 1** (Carl, 28.11.).

## 8. Von Carl entschieden
- Umfang: Ideen 2, 3, 4, 5, 6, 7, 9 aus dem Brainstorming.
- Tabelle in der Spielseite **und** in der Sport-App (Variante B), Widget später.
- Datenquelle: Ansatz 1.
- Spiele ohne Tabelle im eigenen Wettbewerb: Form/Platz/Tabelle fallen weg; gibt es eine Tabelle (fast alle Wettbewerbe), wird sie gezeigt.
- Design freigegeben inkl. Claudes Vorschlägen in Abschnitt 9.

## 9. Claudes Vorschläge (korrigierbar)
**Daten / Server**
- **`sport/table?l=soccer/ger.1`** (Funktion `sport`): liefert Gruppen (meist eine) mit Zeilen (Team-ID, Name deutsch wie im Feed, Platz, Spiele, S/U/N, Tore, Gegentore, Tordifferenz, Punkte, Zone), eine Zonen-Legende (Farbe + deutscher Text) und die Form je Team-ID (bis 5 Einträge, neuestes zuerst). Ligen ohne Tabelle → leere Antwort, kein Fehler.
- Cache: 10 min; läuft in der Liga gerade ein Spiel, 1 min.
- **Form** = letzte 5 Spiele *im Wettbewerb der Tabelle* (wie Flashscore standardmäßig), aus dem Saison-Spielplan des Wettbewerbs in einer Abfrage. Zonen-Texte werden serverseitig übersetzt (z. B. „Champions League“, „Relegation“, „Abstieg“).
- **Plan B Form:** Liefert ESPN den Saison-Spielplan nicht in einer Abfrage, holt der Server ihn in Monatsstücken über einen Datumsbereich; beendete Monate werden 6 h zwischengespeichert. Klappt auch das nicht, gibt es für diese Liga keine Form (keine leeren Punkte, keine Form-Spalte).
- **Keine Zonen von ESPN:** Tabelle ohne Zonenstriche und ohne Legende. Bewusst **keine** feste Zonenliste im Server – Europapokal-Plätze verschieben sich je Saison, eine feste Liste wäre eine Quelle für falsche Tabellen.
- **„Gefolgte Liga“** in der Sport-App = alle Fußball-Ligen aus `SportBucket.leagues(follows)`, also auch die Ligen der Team-Favoriten.
- **`feeds/match`** wird erweitert: Team-IDs beider Seiten (für Hervorhebung und Tabelle), je Spieler Position (Kürzel), Ein-/Auswechsel-Minute und eine Spieler-ID, damit Ereignisse sicher dem Spieler zugeordnet werden; Ereignis-Art Gelb-Rot. Trainer, falls ESPN ihn liefert. Bestehende Felder bleiben, damit ältere Builds weiterlaufen.

**Spielfeld**
- Spieler werden nach **Position** platziert, nicht nach Listenreihenfolge: Das Kürzel (z. B. `G`, `RB`, `CD-L`, `DM`, `LM`, `AM-R`, `F`) ergibt Tiefe (Torwart → Abwehr → Mittelfeld → Angriff) und Seite (links/mitte/rechts). Die Formation (z. B. 4-2-3-1) legt fest, wie viele Spieler in welcher Reihe stehen. Passt die Zählung nicht zur Formation oder fehlen Positionen, zeigt Hubert automatisch die **Liste** (wie heute, aufgeräumt).
- iPhone: Feld über die volle Breite, Bank darunter. iPad (breite Ansicht): Feld links, Bank rechts.

**Darstellung**
- Reiter-Reihenfolge: Ticker · Aufstellung · Statistik · Tabelle. Start-Reiter: vor Anpfiff Aufstellung (falls da), sonst Tabelle; während und nach dem Spiel Ticker.
- Form-Punkte: S grün, U grau, N rot – **Ausnahme** von „Rot nur für Live“, weil die drei Farben bei Formkurven gelernt sind. Alternative: N dunkelgrau mit Buchstabe.
- Tabelle iPhone: Platz · Team · Sp. · TD · Pkt.; iPad zusätzlich S · U · N · Tore · Form.
- Aktualisierung in der App: Tabelle alle 10 min, bei Live-Spielen der Liga jede Minute; Spielseite wie bisher (30 s live).

**Für später vormerken:** Wappen als Bilder, Live-Tabelle (Saisonspiele liegen dann schon auf dem Server), Direktvergleich, Team-Seite, Widget „Tabelle Mini“.

## 10. Dem Entwickler überlassen
- Genaue Namen der Felder und Swift-Typen, Aufteilung in Dateien (Vorschlag: `Buckets/SportMatch.swift` für die Spielseite, `Buckets/SportTable.swift` für Tabellen).
- Feinmaße, Abstände und Animationen im Rahmen von `hubert-apple-look`.
- Wie die Übersetzung der Positionskürzel intern aussieht, solange die Fallback-Regel gilt.

## 11. Erfolg
- Bei einem Bundesliga-Spiel am Samstag zeigt Hubert auf iPhone und iPad: Spielfeld mit beiden Aufstellungen, Zeitleiste, Statistik-Balken, Tabelle mit beiden Teams markiert – ohne Safari oder andere App.
- In der Sport-App ist die Bundesliga-Tabelle mit Form auch an einem spielfreien Tag da.
- Bei Ligen mit wenig Daten erscheinen keine leeren Reiter.
