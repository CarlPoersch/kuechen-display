# Uhr: Wecker, Timer, Stoppuhr – Design

Stand: 24.11.2026 · Status: **freigegeben (Carl, 24.11.)**

## Absicht und Warum
Der bisherige Timer-Bucket wird zur **„Uhr“** mit Wecker, Timer und Stoppuhr. Kern ist Carls Wunsch, dass **beim Wecker die Lampen angehen** (einstellbar). So wird das Wand-iPad morgens zum Lichtwecker.
Grundsatz: Alles muss auf **iPhone und iPad** sauber aussehen und gut bedienbar sein (Carl, 24.11.).

## Ziele (von Carl ausgewählt, Brainstorm 24.11.)
1. **Wiederholende Wecker:** Wochentage wählbar.
2. **Einmal-Wecker:** keine Tage gewählt → klingelt einmal, schaltet sich danach ab.
3. **Schlummern:** großer Knopf, Dauer pro Wecker (5/9/10/15 min).
4. **Für wen:** „Nur ich“ (nur meine Geräte) oder „Haushalt“ (alle Geräte des Haushalts).
8. **Lampen pro Wecker** wählbar (aus dem Smart-Home-Bucket).
9. **Licht vorher:** aus / 5 / 10 / 15 min vor dem Klingeln. Option „nacheinander“: Die gewählten Lampen gehen gleichmäßig verteilt über die Vorlaufzeit an, weil Steckdosen nicht dimmen.
11. **Wecker beenden** → Licht bleibt an. **Schlummern** → Licht wieder aus, beim nächsten Klingeln wieder an.
12. **„Gute Nacht“:**
    - Zeigt den nächsten Wecker zum Bestätigen oder Ändern (morgen überspringen ist möglich).
    - Dann gehen alle Lampen aus und das iPad wechselt in die Nachtuhr.
13. **Timer mit Aktion:** optional „Am Ende: Lampen aus“ oder „Lampen an“ mit Lampenauswahl, z. B. als Einschlaf-Timer.
14. **Timer-Vorlagen:** ein Tipp startet. Mitgeliefert sind Eier, Pizza, Wäsche und Tee. Eigene Vorlagen lassen sich anlegen, löschen und sortieren.
15. **Mehrere Timer übersichtlich:** nach Restzeit sortiert. iPhone: zweizeilige Karte (wie jetzt). iPad: Kacheln mit Ring.
17. **Stoppuhr** mit Runden. Sie merkt sich die Startzeit und läuft deshalb weiter, wenn die App zu ist (pro Gerät).
19. **Nachtuhr am Wand-iPad:**
    - Startet automatisch ab einer einstellbaren Uhrzeit oder nach „Gute Nacht“.
    - Bildschirm sehr dunkel, große gedimmte Ziffern, darunter der nächste Wecker.
    - Wird mit dem Lampen-Vorlauf bzw. dem Klingeln wieder hell. Ein Tipp beendet sie.
20. **Weckton wählbar** (mehrere Töne, Vorschau beim Auswählen), dazu **„Langsam lauter“** über 30 s.

## Wo es klingelt (Carl, 24.11.: Variante B)
- **Wand-iPad bzw. jedes Gerät, auf dem Hubert offen ist:** volles Klingeln in Hubert mit gewähltem Ton, langsam lauter, großer Wecker-Bildschirm (Beenden/Schlummern).
- **iPhone mit geschlossener Hubert-App:** iOS-Mitteilung zur Weckzeit mit Ton (max. 30 s, nicht langsam lauter). Auf die Mitteilung tippen öffnet den Wecker-Bildschirm.
- **Licht schaltet nur ein Gerät zu Hause, auf dem Hubert offen ist** (normalerweise das Wand-iPad). Damit nicht zwei Geräte doppelt schalten, übernimmt das zuerst angemeldete Gerät mit offenem Hubert.
- Ist am Morgen kein solches Gerät aktiv, bleibt das Licht aus. Das zeigt der Wecker im Bearbeiten-Fenster als Hinweis.
- Später (nicht jetzt): echter iPhone-Wecker über AlarmKit ab iOS 26.

## Zwei Ansichten: mit und ohne Lampen (Carl, 24.11.)
Alles rund ums Licht ist nur sichtbar, wenn der Smart-Home-Bucket eingerichtet ist **und** mindestens eine Lampe verbunden ist. Betroffen sind:
- der Abschnitt „Licht“ im Wecker,
- „Am Ende: Lampen …“ beim Timer,
- Lampen-Texte bei „Gute Nacht“,
- der Hinweis „kein Lichtgerät aktiv“.

Ohne Lampen ist die Uhr ein ganz normaler Wecker/Timer, und „Gute Nacht“ bestätigt nur den Wecker und startet die Nachtuhr. Gespeicherte Lampen-Einstellungen bleiben erhalten und werden ignoriert, solange keine Lampen da sind.

## Lieferung in drei Schritten
1. Wecker mit Klingeln (in Hubert) und Mitteilungen (iPhone), Abgleich Beenden/Schlummern.
2. Licht beim Wecker, Timer mit Aktion, Gute Nacht, Lichtgerät.
3. Nachtuhr, Timer-Vorlagen, Stoppuhr, Töne.

## Nicht-Ziele
- Kein Dimmen, keine Lichtfarben (Steckdosen können nur an/aus).
- Kein Wecker aus Stundenplan oder Terminen, keine Feiertage (in dieser Runde nicht ausgewählt).
- Kein Morgen-Briefing beim Ausschalten, kein Spotify-Wecker.
- Kein AlarmKit in dieser Runde.

## Anti-Ziele (Fehlschlag, auch wenn es technisch läuft)
- Ein Wecker klingelt nicht, obwohl Hubert offen ist, oder klingelt doppelt.
- Licht geht an, obwohl der Wecker für heute ausgeschaltet bzw. übersprungen wurde.
- Lampen werden von zwei Geräten gleichzeitig geschaltet (Flackern).
- Die Nachtuhr ist zu hell oder lässt sich nicht mit einem Tipp beenden.
- Die Ansicht ist auf iPhone oder iPad abgeschnitten oder gequetscht.

## Einschränkungen
- iOS 15 (iPad mini 4), Swift-5-Modus (siehe Projektwissen).
- iOS-Mitteilungen: höchstens 64 geplante pro App, Ton höchstens 30 s, eigene Töne als Datei im App-Bündel (`.caf`/`.wav`).
- Das Wand-iPad bleibt an (`isIdleTimerDisabled`), Hubert ist dort im Vordergrund.
- Die bestehenden Timer (Live-Abgleich im Haushalt, Küchen-Timer aus Rezepten, Inseln unten) müssen unverändert weiter funktionieren.

## Ansätze
1. **Bestehenden Timer-Bucket zur „Uhr“ ausbauen** (gleiche Bucket-ID, neuer Name) – **Empfehlung/gewählt.** Bestehende Karten bleiben auf der Startseite, Küchen-Timer laufen weiter.
2. Eigener Wecker-Bucket neben dem Timer. Zwei Stellen für Zeitdinge und doppelte Einstellungen. Verworfen.
3. Wecker nur als Teil des Smart-Home-Buckets. Passt nicht, weil Wecker auch ohne Lampen gebraucht wird. Verworfen.

## Vorschläge von Claude (korrigierbar)
- **Speicherung:** neue Supabase-Tabelle `alarms` mit RLS über den Haushalt. Felder:
  - Uhrzeit, Tage, Name, an/aus, Besitzer (für „Nur ich“) bzw. Haushalt;
  - Schlummerdauer, Ton, Lampen-IDs, Vorlauf, „nacheinander“, „heute übersprungen bis“.
  Eigene Vorlagen in `kitchen_meta`-Art pro Haushalt.
- **Wer schaltet das Licht:** Jedes Gerät mit offenem Hubert meldet sich alle 15 s im bestehenden Live-Abgleich („Lichtgerät“). Geschaltet wird nur vom Gerät mit dem ältesten aktiven Eintrag. So gewinnt das Wand-iPad, das dauerhaft läuft.
- **Widgets der Uhr:**
  - „Nächster Wecker“: Zeit, Tage, Schalter, Knopf „Gute Nacht“.
  - „Timer“: wie bisher, oben Vorlagen-Knöpfe.
- **Kopfkarte:** kleines Glocken-Symbol mit der nächsten Weckzeit (nur wenn ein Wecker in den nächsten 24 h ansteht).
- **Wecker-Bildschirm:** schwarz, große Uhrzeit, zwei große Knöpfe „Schlummern“ (grau) und „Beenden“ (orange). Auf dem iPad jeweils mindestens 88 pt hoch.
- **Nachtuhr:**
  - Helligkeit über `UIScreen.main.brightness` auf das Minimum, Ziffern in Grau/Rot mit niedriger Deckkraft; beim Verlassen wird die alte Helligkeit wiederhergestellt.
  - Startzeit einstellbar in den Uhr-Einstellungen (Standard: 23:00, nur auf diesem Gerät).
- **Töne:** 4–5 eigene kurze Töne im App-Bündel (selbst erzeugt, keine fremden Aufnahmen).
- **Stoppuhr:** pro Gerät, ohne Abgleich.
- **Beenden/Schlummern gilt überall:** Jeder Weckvorgang hat einen abgeglichenen Zustand (klingelt / schlummert bis … / beendet) im Live-Abgleich. Beenden auf einem Gerät stoppt das Klingeln auf allen und löscht dort die geplanten Mitteilungen dieses Vorgangs. Schlummern plant auf allen Geräten neu.
- **„Nur ich“** steuert nur, wo es klingelt (Geräte, die mit dem Konto des Besitzers angemeldet sind). Alle Wecker des Haushalts sind für den Haushalt lesbar (RLS wie bisher). Das Lichtgerät schaltet auch für „Nur ich“-Wecker anderer Haushaltsmitglieder, klingelt dabei aber nicht.
- **Rolle „Wanddisplay“:** Einstellung pro Gerät („Dieses Gerät ist ein Wanddisplay“, Standard: an auf dem iPad, aus auf dem iPhone).
  - Nur Wanddisplays zeigen die Nachtuhr.
  - Lichtgerät kann jedes Gerät mit offenem Hubert werden, das eine Lampe im WLAN erreicht. Wanddisplays haben Vorrang.
- **„Gute Nacht“ von einem beliebigen Gerät:** schaltet alle Lampen des Haushalts aus (über das Lichtgerät oder direkt, falls erreichbar) und schickt über den Live-Abgleich den Befehl „Nachtuhr“ an die Wanddisplays.

## Dem Entwickler überlassen
- Aufteilung der Dateien (z. B. `Core/Alarms.swift`, `Buckets/ClockBucket.swift`, Umbau von `Core/Timers.swift`).
- Genaue Planung der Mitteilungen (Fenster der nächsten Tage, max. 64).
- Wie „langsam lauter“ umgesetzt wird (Lautstärke des Players hochfahren).

## Nachtrag 24.11.: System-Wecker über AlarmKit (ab iOS/iPadOS 26)
Carl nutzt jetzt ein iPad Pro (6. Gen.) mit iPadOS 26.5; auch andere Nutzer haben neuere Versionen.
- Ab iOS 26 legt Hubert jede Weckzeit (nächste 4 Tage, max. 30) zusätzlich als **AlarmKit-Wecker** an. Er klingelt auch gesperrt, im Stumm-Modus und bei Fokus. Mitteilungen entfallen dann.
- **Hubert offen:** Hubert klingelt selbst (Ton, langsam lauter, Licht). System-Wecker der nächsten Minute werden zurückgenommen, laufende stummgeschaltet.
- **Beenden/Schlummern am Sperrbildschirm:** über App-Intents in Hubert, gelten auf allen Geräten. Schlummern nutzt bewusst keinen AlarmKit-Countdown (der bräuchte eine Widget-Erweiterung), sondern plant selbst neu.
- **Grenzen:**
  - Wegwischen meldet AlarmKit der App nicht.
  - Beendet ein anderes Gerät, verschwindet der System-Wecker hier erst, wenn Hubert wieder läuft.
  - Der Ton ist der System-Weckton (eigene Töne später).
- iOS < 26: unverändert Mitteilungen.
