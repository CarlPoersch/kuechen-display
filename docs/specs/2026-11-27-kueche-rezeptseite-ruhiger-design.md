# Küche: ruhigere Rezeptseite, Filter und Würfel – Design

Stand 27.11.2026 · freigegeben: offen

## Absicht und Warum
Die Rezeptseite wirkt auf dem iPhone unruhig: Bis zum ersten Rezept kommen sechs Blöcke (Rezept des Tages,
Vorrat/Airfryer-Kacheln, zwei blaue Chip-Zeilen, Zufallskarte), dazu drei schwebende Knöpfe über dem Inhalt.
Ziel: Unter der Suche stehen sofort Rezepte. Alles Einschränkende lebt im Filter, Entdecken im Würfel.

## Ziele
- Rezepte direkt unter der Suche sichtbar (iPhone ab dem ersten Bildschirm).
- Jede Funktion an genau einem Ort, nichts doppelt (Filter-Inhalte nicht zusätzlich als Zeilen auf der Seite).
- Würfel wie bei den Filmen: Voreinstellungen, dann würfeln, Ergebnis mit allen Infos, nochmal würfeln.
- Gilt für alle Geräte (iPhone, iPad, Wand-iPad), auf dem iPad mit mehr Platz.

## Nicht-Ziele
- Woche, Einkauf, Vorrat-Tab und Rezeptansicht bleiben, wie sie sind.
- Keine neuen Daten oder Tabellen.

## Anti-Ziele
- Ein Filter, der so voll ist, dass man nichts findet (Carl prüft das nach dem Bau).
- Abgeschnittene Texte („Ohne Fleis…“, „An…“) auf kleinen iPhones.

## Entscheidungen von Carl
1. Rezept des Tages bleibt, ist standardmäßig an und lässt sich in den Küchen-Einstellungen ausschalten.
   Beim ersten Öffnen der Küche fragt ein kurzes Blatt, ob man es haben möchte („Ja“ vorgewählt).
2. Kategorie (Hauptgericht, Suppe …) und Land wandern in den Filter – beide Chip-Zeilen fallen weg.
3. Vorrat und Airfryer wandern ebenfalls in den Filter – die beiden Kacheln fallen weg.
4. Kalorien stehen direkt an jedem Rezept in der Liste.
5. Filter: „Sammlung · Zeigen“ wird verständlich benannt („Angezeigte Rezepte“).
6. Würfel wie bei den Filmen (Voreinstellungen → würfeln → Rezept mit Zutaten, Aufwand, kcal … → nochmal).
7. Favoriten: Herz-Knopf oben rechts in der Leiste (nicht neben der Suche – sonst wird das Suchfeld zu schmal).

## Aufbau Rezeptseite (iPhone)
```
‹ Küche                         [♡  🎲  ⋯]     ← Kapsel oben rechts; ⋯ = Statistik, Küchen-Einstellungen
[ Rezepte | Woche | Einkauf | Vorrat ]
[ 🔍 Rezept oder Zutat suchen      ] [⚙︎ 2]    ← Filter mit Zahl aktiver Filter
☀︎ Rezept des Tages · Bananenbrot · 70 Min. ›   ← schmale Zeile, abschaltbar
(Hauptgericht ✕) (≤ 30 Min. ✕) Alle löschen   ← nur sichtbar, wenn Filter aktiv
128 Rezepte
🍜 Gebratene Nudeln mit Ei               ♥ ›   ← Liste; ♥ nur bei Favoriten
   Chinesisch · 20 Min. · 560 kcal
…                                          (+)  ← einzige schwebende Taste: neues Rezept
```
- iPhone (kompakte Breite): Liste statt zweispaltiger Kacheln, Emoji klein in einem Quadrat.
- iPad / Wand-iPad (normale Breite): Kachelraster bleibt, bekommt aber die gleiche ruhige Kopfzeile
  (keine Chip-Zeilen, keine Vorrat/Airfryer-Kacheln, keine Zufallskarte, nur das Plus schwebt). kcal auch auf den Kacheln.
- Herz oben: Tipp = nur Favoriten (Herz gefüllt + Chip „Favoriten ✕“). Leer → „Tippe in einem Rezept aufs Herz …“.
- Favorit setzen: Wischen nach links in der Liste, Gedrückthalten (Kontextmenü), Herz in der Rezeptansicht, Herz im Würfel.

## Filter-Blatt
| Abschnitt | Inhalt |
|---|---|
| Angezeigte Rezepte | Auswahl: Alle · Eigene · Favoriten · Lange nicht gekocht |
| Gericht | Chips: Alle, Hauptgericht, Suppe, Salat, Beilage, Snack, Frühstück, Dessert, Backen, Getränk (mehrfach wählbar) |
| Land | Zeile „Alle Länder ›“ → eigene Liste mit Flagge und Anzahl |
| Ernährung | Auswahlzeile (statt Segment) + Glutenfrei |
| Zeit und Aufwand | zwei Auswahlzeilen |
| Zubereitung und Vorrat | „Nur Airfryer · 38“, „Mit meinem Vorrat · 68“ (+ „fehlt höchstens“ wie bisher) |
| Zutaten | bleibt wie gebaut (Vorschläge beim Tippen) |
Unten fest: „128 Rezepte anzeigen“. Oben: Zurücksetzen / Fertig.

## Würfel (eigenes Blatt, wie Film-Würfel)
1. Voreinstellungen (werden gemerkt): Gericht (Chips), Ernährung, höchstens Zeit, Aufwand, Kalorien bis,
   Land, Schalter „Mit meinem Vorrat“, „Nur Airfryer“, „Nur aus Favoriten“, „Nichts der letzten 14 Tage“.
   Darunter live: „42 Rezepte passen“. Knopf „Würfeln“.
2. Ergebnis: Emoji, Titel, Land · Ernährung, Herz. Vier Kacheln: Zeit · Aufwand, kcal, Eiweiß/KH/Fett,
   „x von y Zutaten im Vorrat“. Zutatenliste (fehlende markiert), „Alle Zutaten und Schritte ›“.
   Unten fest: [Einstellungen] [Nochmal würfeln], darunter [Kochen] [In die Woche].
   Nie zweimal dasselbe hintereinander.

## Erstes Öffnen
Kleines Blatt: „Rezept des Tages oben anzeigen?“ – „Ja, gerne“ (Standard) / „Nein“. Merkt sich die Wahl
(UserDefaults); änderbar unter ⋯ → Küchen-Einstellungen.

## Ansätze
- A) Nur Aufräumen (Kacheln/Chips weg, sonst gleich) – schnell, aber Filter und Würfel bleiben unübersichtlich.
- B) **Gewählt:** Seite + Filter + Würfel neu ordnen wie oben – ein Umbau, danach jede Funktion an einem Ort.
- C) Eigener „Entdecken“-Tab – mehr Navigation, widerspricht „ruhiger“.

## Dem Entwickler überlassen
Konkrete Abstände, Animationen, wie die Länder-Liste sortiert ist (nach Anzahl), Wortlaut kleiner Hinweise.
