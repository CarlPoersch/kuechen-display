# Blättern in Buckets – Design (kleine Änderung)

**Absicht:** Mehr Inhalt in einer Karte sehen, ohne die Details zu öffnen – ohne dass das Scrollen der Startseite leidet und ohne das feste Rechteck-Layout aufzugeben.

**Ziele:** Waagerecht blättern in Karten mit Listen; sichtbar, dass es weitergeht. **Nicht-Ziele:** senkrechtes Scrollen in Karten; Karten, die ihre Größe ändern. **Anti-Ziel:** Die Startseite lässt sich nicht mehr zuverlässig scrollen.

**Ansätze:** A) senkrecht in der Karte scrollen – verworfen (Konflikt mit der Startseite). B) Karte ausklappen – verworfen (Layout ändert die Größe). **C) waagerecht blättern – gewählt (Carl).**

**Verhalten (von Carl):** Gibt es weitere Seiten, ragt die nächste Seite am rechten Rand ein Stück in die Karte.

**Umsetzung (meine Entscheidungen):**
- Ein gemeinsamer Baustein `GlancePager` für alle Buckets: Einträge werden in Seiten geteilt, so viele Zeilen pro Seite wie in die Karte passen.
- Nächste Seite ragt ca. 26 pt rechts herein, abgeblendet; darunter kleine Punkte (●○○) für die Seite.
- Technik: echte UIKit-Scrollfläche mit Seiten-Einrasten. Warum: iOS trennt dann waagerecht (Karte) und senkrecht (Startseite) selbst sauber – dasselbe Verhalten wie im App Store.
- Fest stehen bleiben: Eilmeldung (News), Von/Nach-Auswahl und Spaltenköpfe (ÖPNV), Eingabefeld (Einkauf).
- Gilt für: News, Sport, Termine, ÖPNV, Einkauf, Countdown. Nicht für Wetter und Rezept des Tages (keine Listen).
- „Alle ›“ bleibt für die vollständige Ansicht.
